import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Ana isolate -> işçi isolate komutları (Map biçiminde).
/// cmd: init | lang | start | audio | flush | dispose
/// İşçi -> ana: ready, segment, speaking, ack, flushed, error
void asrWorkerMain(SendPort toMain) {
  final rx = ReceivePort();
  toMain.send(rx.sendPort);
  _Worker(toMain).run(rx);
}

class _Worker {
  _Worker(this.out);
  final SendPort out;

  sherpa.OfflineRecognizer? _rec;
  sherpa.VoiceActivityDetector? _vad;
  Map<String, dynamic>? _cfg;
  String _lang = '';
  bool _speaking = false;
  int _offset = 0; // örnek cinsinden, oturum başlangıcı

  static const sr = 16000;

  Future<void> run(ReceivePort rx) async {
    sherpa.initBindings();
    await for (final raw in rx) {
      final m = raw as Map;
      try {
        switch (m['cmd']) {
          case 'init':
            _cfg = Map<String, dynamic>.from(m);
            _lang = m['lang'] as String;
            _build();
            out.send({'type': 'ready'});
          case 'lang':
            _lang = m['lang'] as String;
            _rec?.free();
            _rec = null;
            _build(vad: false);
            out.send({'type': 'ready'});
          case 'start':
            _vad?.reset();
            _speaking = false;
            _offset = 0;
          case 'audio':
            final data = (m['data'] as TransferableTypedData).materialize().asFloat32List();
            _feed(data);
            out.send({'type': 'ack', 'id': m['id']});
          case 'flush':
            _vad?.flush();
            _drain();
            _setSpeaking(false);
            out.send({'type': 'flushed'});
          case 'dispose':
            _rec?.free();
            _vad?.free();
            rx.close();
            Isolate.exit();
        }
      } catch (e, st) {
        out.send({'type': 'error', 'msg': '$e\n$st'});
        if (m['cmd'] == 'audio') out.send({'type': 'ack', 'id': m['id']});
      }
    }
  }

  void _build({bool vad = true}) {
    final c = _cfg!;
    final threads = math.max(2, math.min(6, (c['threads'] as int)));
    _rec = sherpa.OfflineRecognizer(sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        whisper: sherpa.OfflineWhisperModelConfig(
          encoder: c['encoder'] as String,
          decoder: c['decoder'] as String,
          language: _lang,
          task: 'transcribe',
          tailPaddings: 1000,
        ),
        tokens: c['tokens'] as String,
        numThreads: threads,
        debug: false,
        provider: 'cpu',
      ),
    ));
    if (vad && _vad == null) {
      _vad = sherpa.VoiceActivityDetector(
        config: sherpa.VadModelConfig(
          sileroVad: sherpa.SileroVadModelConfig(
            model: c['vad'] as String,
            threshold: 0.5,
            minSilenceDuration: 0.6,
            minSpeechDuration: 0.3,
            maxSpeechDuration: 25,
          ),
          sampleRate: sr,
          numThreads: 1,
          debug: false,
        ),
        bufferSizeInSeconds: 60,
      );
    }
  }

  void _feed(Float32List data) {
    final vad = _vad!;
    // VAD'a pencere boyutunun katları halinde ver.
    const win = 512;
    var i = 0;
    while (i < data.length) {
      final end = math.min(i + win * 8, data.length);
      vad.acceptWaveform(Float32List.sublistView(data, i, end));
      i = end;
      _drain();
    }
    _setSpeaking(vad.isDetected());
    _offset += data.length;
  }

  void _setSpeaking(bool v) {
    if (v != _speaking) {
      _speaking = v;
      out.send({'type': 'speaking', 'v': v});
    }
  }

  void _drain() {
    final vad = _vad!;
    while (!vad.isEmpty()) {
      final seg = vad.front();
      vad.pop();
      final text = _decode(seg.samples);
      if (text.isNotEmpty) {
        out.send({
          'type': 'segment',
          'start': seg.start / sr,
          'end': (seg.start + seg.samples.length) / sr,
          'text': text,
        });
      }
    }
  }

  String _decode(Float32List samples) {
    final rec = _rec!;
    final s = rec.createStream();
    try {
      s.acceptWaveform(samples: samples, sampleRate: sr);
      rec.decode(s);
      final t = rec.getResult(s).text.trim();
      return _clean(t);
    } finally {
      s.free();
    }
  }

  /// Whisper'ın sessizlikte ürettiği tipik "hayalet" çıktıları ele.
  String _clean(String t) {
    if (t.length < 2) return '';
    final low = t.toLowerCase();
    const ghosts = [
      'altyazı m.k.',
      'abone olmayı unutmayın',
      'izlediğiniz için teşekkürler',
      'thanks for watching',
      'thank you for watching',
      'subtitles by',
    ];
    for (final g in ghosts) {
      if (low == g || low == '$g.') return '';
    }
    if (RegExp(r'^[\s\.\,\!\?\-\[\]\(\)♪]+$').hasMatch(t)) return '';
    return t;
  }
}
