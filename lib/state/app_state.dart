import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/engine.dart';
import '../engine/models.dart';
import '../l10n.dart';

enum Phase { booting, setup, downloading, loading, ready }

class Transcript {
  Transcript({
    required this.id,
    required this.title,
    required this.source,
    required this.created,
    required this.lang,
    required this.duration,
    required this.segments,
    this.audioPath,
  });
  final String id;
  String title;
  final String source; // live | file
  final DateTime created;
  final String lang;
  final double duration;
  final List<Segment> segments;
  final String? audioPath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'source': source,
        'created': created.toIso8601String(),
        'lang': lang,
        'duration': duration,
        'audio': audioPath,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory Transcript.fromJson(Map<String, dynamic> j) => Transcript(
        id: j['id'] as String,
        title: j['title'] as String,
        source: j['source'] as String,
        created: DateTime.parse(j['created'] as String),
        lang: j['lang'] as String,
        duration: (j['duration'] as num).toDouble(),
        audioPath: j['audio'] as String?,
        segments: (j['segments'] as List).map((e) => Segment.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}

class AppState extends ChangeNotifier {
  late Store store;
  final Engine engine = Engine();
  final LiveCapture capture = LiveCapture();
  SharedPreferences? _prefs;

  // --- genel ---
  Phase phase = Phase.booting;
  int tab = 0;
  String uiLang = 'tr';
  String speechLang = 'tr';
  String modelId = 'small';
  String? error;
  L get l => L(uiLang);
  WhisperModel get model => WhisperModel.byId(modelId);

  // --- indirme ---
  double dlProgress = 0;
  String dlLabel = '';
  String? ffmpegPath;
  bool ffmpegBusy = false;
  double ffmpegProgress = 0;
  final Set<String> installed = {};

  // --- canlı ---
  bool recording = false;
  bool finalizing = false;
  bool speaking = false;
  double level = 0;
  final List<double> levels = List.filled(56, 0.0, growable: true);
  final List<Segment> liveSegs = [];
  final Stopwatch _watch = Stopwatch();
  Timer? _tick;
  String? _livePath;
  DateTime? _liveStarted;
  Duration get elapsed => _watch.elapsed;

  // --- dosya ---
  String? filePath;
  bool fileBusy = false;
  double fileProgress = 0; // -1: belirsiz
  final List<Segment> fileSegs = [];
  FileJob? _job;
  String? fileError;

  // --- geçmiş ---
  final List<Transcript> history = [];
  Transcript? opened;

  StreamSubscription? _segSub, _spkSub, _errSub;
  bool _routeLive = true;

  // ------------------------------------------------------------------ boot

  Future<void> boot() async {
    store = await Store.open();
    _prefs = await SharedPreferences.getInstance();
    uiLang = _prefs!.getString('ui') ?? (Platform.localeName.startsWith('tr') ? 'tr' : 'en');
    speechLang = _prefs!.getString('speech') ?? uiLang;
    modelId = _prefs!.getString('model') ?? 'small';
    _refreshInstalled();
    ffmpegPath = await store.findFfmpeg();
    await _loadHistory();
    _segSub = engine.segments.listen(_onSegment);
    _spkSub = engine.speaking.listen((v) {
      speaking = v;
      notifyListeners();
    });
    _errSub = engine.errors.listen((e) => debugPrint('ENGINE: $e'));

    // Kurulu en iyi modeli bul
    if (!installed.contains(modelId) && installed.isNotEmpty) {
      modelId = ['small', 'base', 'tiny'].firstWhere(installed.contains);
    }
    if (installed.contains(modelId)) {
      await _loadEngine();
    } else {
      phase = Phase.setup;
      notifyListeners();
    }
  }

  void _refreshInstalled() {
    installed
      ..clear()
      ..addAll(WhisperModel.all.where(store.hasModel).map((m) => m.id));
  }

  Future<void> _loadEngine() async {
    phase = Phase.loading;
    notifyListeners();
    try {
      await engine.load(store, model, speechLang);
      phase = Phase.ready;
    } catch (e) {
      error = '$e';
      phase = Phase.setup;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------- ayarlar

  void setUiLang(String v) {
    uiLang = v;
    _prefs?.setString('ui', v);
    notifyListeners();
  }

  Future<void> setSpeechLang(String v) async {
    if (v == speechLang || recording || fileBusy) return;
    speechLang = v;
    _prefs?.setString('speech', v);
    notifyListeners();
    if (phase == Phase.ready) {
      await engine.setLanguage(v);
    }
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  Future<void> downloadModel(WhisperModel m, {bool activate = true}) async {
    error = null;
    phase = Phase.downloading;
    dlProgress = 0;
    dlLabel = m.id;
    notifyListeners();
    try {
      await store.downloadModel(m, (pr) {
        dlProgress = pr;
        notifyListeners();
      });
      _refreshInstalled();
      if (activate) {
        modelId = m.id;
        _prefs?.setString('model', m.id);
      }
      await _loadEngine();
    } catch (e) {
      error = '$e';
      phase = installed.isEmpty ? Phase.setup : Phase.ready;
      notifyListeners();
    }
  }

  Future<void> useModel(WhisperModel m) async {
    if (recording || fileBusy || m.id == modelId) return;
    modelId = m.id;
    _prefs?.setString('model', m.id);
    await _loadEngine();
  }

  Future<void> downloadFfmpeg() async {
    ffmpegBusy = true;
    ffmpegProgress = 0;
    error = null;
    notifyListeners();
    try {
      await store.downloadFfmpeg((pr) {
        ffmpegProgress = pr;
        notifyListeners();
      });
      ffmpegPath = await store.findFfmpeg();
    } catch (e) {
      error = '$e';
    }
    ffmpegBusy = false;
    notifyListeners();
  }

  // ----------------------------------------------------------- segment akışı

  void _onSegment(Segment s) {
    (_routeLive ? liveSegs : fileSegs).add(s);
    notifyListeners();
  }

  // ----------------------------------------------------------------- canlı

  Future<void> startRecording() async {
    if (recording || finalizing || phase != Phase.ready || fileBusy) return;
    error = null;
    if (!await capture.hasPermission()) {
      error = l.t('mic_denied');
      notifyListeners();
      return;
    }
    _routeLive = true;
    liveSegs.clear();
    opened = null;
    engine.beginSession();
    _liveStarted = DateTime.now();
    _livePath = p.join(store.recordingsDir.path, 'kayit_${_stamp(_liveStarted!)}.wav');
    try {
      await capture.start(
        onChunk: (c) => engine.feed(c),
        onLevel: (v) {
          level = level * 0.55 + v * 0.45;
          levels
            ..removeAt(0)
            ..add(level);
          notifyListeners();
        },
      );
    } catch (e) {
      error = '$e';
      notifyListeners();
      return;
    }
    recording = true;
    _watch
      ..reset()
      ..start();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => notifyListeners());
    notifyListeners();
  }

  Future<void> stopRecording() async {
    if (!recording) return;
    recording = false;
    finalizing = true;
    _tick?.cancel();
    _watch.stop();
    level = 0;
    for (var i = 0; i < levels.length; i++) {
      levels[i] = 0;
    }
    notifyListeners();
    await capture.stop(_livePath);
    await engine.flush();
    finalizing = false;
    speaking = false;
    if (liveSegs.isNotEmpty) {
      final t = Transcript(
        id: _stamp(_liveStarted!),
        title: '${l.t('untitled_live')} · ${_pretty(_liveStarted!)}',
        source: 'live',
        created: _liveStarted!,
        lang: speechLang,
        duration: _watch.elapsed.inMilliseconds / 1000,
        segments: List.of(liveSegs),
        audioPath: _livePath,
      );
      await _save(t);
    }
    notifyListeners();
  }

  void clearLive() {
    if (recording) return;
    liveSegs.clear();
    notifyListeners();
  }

  // ----------------------------------------------------------------- dosya

  Future<void> transcribeFile(String path) async {
    if (fileBusy || recording || phase != Phase.ready) return;
    fileError = null;
    if (ffmpegPath == null) {
      fileError = l.t('ffmpeg_need');
      notifyListeners();
      return;
    }
    filePath = path;
    fileSegs.clear();
    opened = null;
    fileBusy = true;
    fileProgress = 0;
    _routeLive = false;
    notifyListeners();
    final job = FileJob(engine, ffmpegPath!);
    _job = job;
    final started = DateTime.now();
    try {
      final dur = await job.probeDuration(path);
      final ok = await job.run(path, onProgress: (pr) {
        fileProgress = pr;
        notifyListeners();
      });
      if (ok && fileSegs.isNotEmpty) {
        await _save(Transcript(
          id: _stamp(started),
          title: p.basename(path),
          source: 'file',
          created: started,
          lang: speechLang,
          duration: dur ?? fileSegs.last.end,
          segments: List.of(fileSegs),
        ));
      }
    } catch (e) {
      fileError = '$e';
    }
    fileBusy = false;
    _routeLive = true;
    _job = null;
    notifyListeners();
  }

  void cancelFile() {
    _job?.cancel();
  }

  void resetFile() {
    if (fileBusy) return;
    filePath = null;
    fileSegs.clear();
    fileError = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- geçmiş

  Future<void> _loadHistory() async {
    history.clear();
    final files = store.transcriptsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json'));
    for (final f in files) {
      try {
        history.add(Transcript.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>));
      } catch (_) {}
    }
    history.sort((a, b) => b.created.compareTo(a.created));
  }

  Future<void> _save(Transcript t) async {
    await File(p.join(store.transcriptsDir.path, '${t.id}.json'))
        .writeAsString(jsonEncode(t.toJson()));
    history.insert(0, t);
  }

  Future<void> deleteTranscript(Transcript t) async {
    try {
      await File(p.join(store.transcriptsDir.path, '${t.id}.json')).delete();
    } catch (_) {}
    history.remove(t);
    if (opened == t) opened = null;
    notifyListeners();
  }

  void open(Transcript? t) {
    opened = t;
    notifyListeners();
  }

  // ------------------------------------------------------------ yardımcılar

  String _stamp(DateTime d) =>
      '${d.year}${_2(d.month)}${_2(d.day)}_${_2(d.hour)}${_2(d.minute)}${_2(d.second)}';
  String _2(int n) => n.toString().padLeft(2, '0');

  String _pretty(DateTime d) => '${_2(d.day)}.${_2(d.month)}.${d.year} ${_2(d.hour)}:${_2(d.minute)}';
  String pretty(DateTime d) => _pretty(d);

  @override
  void dispose() {
    _segSub?.cancel();
    _spkSub?.cancel();
    _errSub?.cancel();
    _tick?.cancel();
    capture.dispose();
    engine.dispose();
    super.dispose();
  }
}
