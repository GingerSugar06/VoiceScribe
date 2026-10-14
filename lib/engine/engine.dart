import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:record/record.dart';

import 'asr_worker.dart';
import 'models.dart';

class Segment {
  Segment(this.start, this.end, this.text);
  final double start;
  final double end;
  final String text;

  Map<String, dynamic> toJson() => {'s': start, 'e': end, 't': text};
  factory Segment.fromJson(Map<String, dynamic> j) =>
      Segment((j['s'] as num).toDouble(), (j['e'] as num).toDouble(), j['t'] as String);
}

/// Whisper işçi isolate'ını yöneten ve canlı / dosya kaynaklarını besleyen katman.
class Engine {
  Isolate? _iso;
  SendPort? _tx;
  ReceivePort? _rx;
  Completer<void>? _ready;
  Completer<void>? _flushed;
  final Map<int, Completer<void>> _acks = {};
  int _ackId = 0;

  final _segments = StreamController<Segment>.broadcast();
  final _speaking = StreamController<bool>.broadcast();
  final _errors = StreamController<String>.broadcast();
  Stream<Segment> get segments => _segments.stream;
  Stream<bool> get speaking => _speaking.stream;
  Stream<String> get errors => _errors.stream;

  bool get isLoaded => _tx != null;

  Future<void> load(Store store, WhisperModel model, String lang) async {
    await dispose();
    _rx = ReceivePort();
    final boot = Completer<SendPort>();
    _rx!.listen((msg) {
      if (msg is SendPort) {
        boot.complete(msg);
        return;
      }
      final m = msg as Map;
      switch (m['type']) {
        case 'ready':
          _ready?.complete();
        case 'segment':
          _segments.add(Segment((m['start'] as num).toDouble(), (m['end'] as num).toDouble(), m['text'] as String));
        case 'speaking':
          _speaking.add(m['v'] as bool);
        case 'ack':
          _acks.remove(m['id'])?.complete();
        case 'flushed':
          _flushed?.complete();
        case 'error':
          _errors.add(m['msg'] as String);
          if (_ready != null && !_ready!.isCompleted) _ready!.completeError(m['msg'] as String);
      }
    });
    _iso = await Isolate.spawn(asrWorkerMain, _rx!.sendPort);
    _tx = await boot.future;
    _ready = Completer<void>();
    _tx!.send({
      'cmd': 'init',
      'encoder': store.modelPath(model, model.encoder),
      'decoder': store.modelPath(model, model.decoder),
      'tokens': store.modelPath(model, model.tokens),
      'vad': store.vadPath,
      'lang': _code(lang),
      'threads': math.max(2, Platform.numberOfProcessors ~/ 2),
    });
    await _ready!.future;
  }

  /// UI dil kodu -> Whisper dil kodu ('auto' = otomatik algılama)
  String _code(String lang) => lang == 'auto' ? '' : lang;

  Future<void> setLanguage(String lang) async {
    if (_tx == null) return;
    _ready = Completer<void>();
    _tx!.send({'cmd': 'lang', 'lang': _code(lang)});
    await _ready!.future;
  }

  void beginSession() => _tx?.send({'cmd': 'start'});

  Future<void> feed(Float32List samples, {bool waitAck = false}) {
    final id = _ackId++;
    final c = Completer<void>();
    _acks[id] = c;
    _tx!.send({'cmd': 'audio', 'id': id, 'data': TransferableTypedData.fromList([samples])});
    return waitAck ? c.future : Future.value();
  }

  Future<void> flush() async {
    _flushed = Completer<void>();
    _tx?.send({'cmd': 'flush'});
    await _flushed!.future;
  }

  Future<void> dispose() async {
    _tx?.send({'cmd': 'dispose'});
    _iso?.kill(priority: Isolate.beforeNextEvent);
    _rx?.close();
    _iso = null;
    _tx = null;
    _rx = null;
  }
}

// ---------------------------------------------------------------------------
// Canlı mikrofon
// ---------------------------------------------------------------------------

class LiveCapture {
  final AudioRecorder _rec = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final BytesBuilder _pcm = BytesBuilder(copy: false);
  int get samplesCaptured => _pcm.length ~/ 2;

  Future<bool> hasPermission() => _rec.hasPermission();

  Future<List<InputDevice>> devices() async {
    try {
      return await _rec.listInputDevices();
    } catch (_) {
      return [];
    }
  }

  Future<void> start({
    required void Function(Float32List chunk) onChunk,
    required void Function(double level) onLevel,
    InputDevice? device,
  }) async {
    _pcm.clear();
    final stream = await _rec.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
      device: device,
      echoCancel: false,
      noiseSuppress: false,
      autoGain: false,
    ));
    var carry = 0; // yarım örnek baytı için
    _sub = stream.listen((bytes) {
      _pcm.add(bytes);
      final n = bytes.length ~/ 2;
      if (n == 0) return;
      final bd = ByteData.sublistView(bytes);
      final f = Float32List(n);
      double sum = 0;
      for (var i = 0; i < n; i++) {
        final v = bd.getInt16(i * 2, Endian.little) / 32768.0;
        f[i] = v;
        sum += v * v;
      }
      carry = bytes.length - n * 2;
      final rms = math.sqrt(sum / n);
      onLevel((rms * 6).clamp(0.0, 1.0));
      onChunk(f);
    });
  }

  /// Kaydı durdurur; ham PCM'i WAV olarak [path] konumuna yazar.
  Future<void> stop(String? savePath) async {
    await _sub?.cancel();
    _sub = null;
    await _rec.stop();
    if (savePath != null && _pcm.length > 0) {
      await _writeWav(savePath, _pcm.takeBytes());
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _rec.dispose();
  }

  Future<void> _writeWav(String path, Uint8List pcm) async {
    final h = ByteData(44);
    void s(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        h.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    s(0, 'RIFF');
    h.setUint32(4, 36 + pcm.length, Endian.little);
    s(8, 'WAVE');
    s(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little);
    h.setUint16(22, 1, Endian.little);
    h.setUint32(24, 16000, Endian.little);
    h.setUint32(28, 32000, Endian.little);
    h.setUint16(32, 2, Endian.little);
    h.setUint16(34, 16, Endian.little);
    s(36, 'data');
    h.setUint32(40, pcm.length, Endian.little);
    final f = File(path).openWrite();
    f.add(h.buffer.asUint8List());
    f.add(pcm);
    await f.close();
  }
}

// ---------------------------------------------------------------------------
// Dosya / video
// ---------------------------------------------------------------------------

class FileJob {
  FileJob(this.engine, this.ffmpeg);
  final Engine engine;
  final String ffmpeg;
  Process? _proc;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    _proc?.kill();
  }

  /// Toplam süre (saniye); bulunamazsa null.
  Future<double?> probeDuration(String path) async {
    try {
      final r = await Process.run(ffmpeg, ['-hide_banner', '-i', path]);
      final m = RegExp(r'Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)').firstMatch(r.stderr as String);
      if (m == null) return null;
      return int.parse(m[1]!) * 3600 + int.parse(m[2]!) * 60 + double.parse(m[3]!);
    } catch (_) {
      return null;
    }
  }

  /// Dosyayı çözüp motoru besler. [onProgress] 0..1 (süre bilinmiyorsa -1).
  /// İptal edilirse false döner.
  Future<bool> run(String path, {required void Function(double) onProgress}) async {
    final duration = await probeDuration(path);
    engine.beginSession();
    final proc = await Process.start(ffmpeg, [
      '-v', 'error', '-nostdin', '-i', path, '-vn', '-sn', '-dn',
      '-ac', '1', '-ar', '16000', '-f', 'f32le', 'pipe:1', //
    ]);
    _proc = proc;
    final errBuf = StringBuffer();
    proc.stderr.transform(const SystemEncoding().decoder).listen(errBuf.write);

    const batch = 16000 * 4 * 6; // ~6 sn
    final buf = BytesBuilder(copy: false);
    var fed = 0; // örnek
    var lastP = -1.0;

    Future<void> push(Uint8List bytes) async {
      final aligned = Uint8List.fromList(bytes); // hizalı kopya
      final f = aligned.buffer.asFloat32List(0, aligned.length ~/ 4);
      await engine.feed(f, waitAck: true);
      fed += f.length;
      if (duration != null && duration > 0) {
        final pr = (fed / 16000 / duration).clamp(0.0, 1.0);
        if (pr - lastP > 0.002) {
          lastP = pr;
          onProgress(pr);
        }
      } else {
        onProgress(-1);
      }
    }

    await for (final chunk in proc.stdout) {
      if (_cancelled) break;
      buf.add(chunk);
      if (buf.length >= batch) {
        final all = buf.takeBytes();
        final usable = all.length - (all.length % 4);
        await push(Uint8List.sublistView(all, 0, usable));
        if (usable < all.length) buf.add(Uint8List.sublistView(all, usable));
      }
    }
    if (_cancelled) return false;
    final rest = buf.takeBytes();
    final usable = rest.length - (rest.length % 4);
    if (usable > 0) await push(Uint8List.sublistView(rest, 0, usable));
    final code = await proc.exitCode;
    if (fed == 0) {
      throw Exception(code != 0 ? errBuf.toString().trim() : 'Ses akışı bulunamadı');
    }
    await engine.flush();
    onProgress(1);
    return true;
  }
}

String basenameNoExt(String path) => p.basenameWithoutExtension(path);
