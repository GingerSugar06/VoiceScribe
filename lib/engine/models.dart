import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tek bir indirilecek dosya.
class RemoteFile {
  const RemoteFile(this.url, this.name, this.size);
  final String url;
  final String name;
  final int size; // yaklaşık bayt (ilerleme çubuğu için)
}

/// Whisper model boyutu seçeneği.
class WhisperModel {
  const WhisperModel(this.id, this.prefix, this.hfRepo, this.encSize, this.decSize);
  final String id; // tiny | base | small
  final String prefix;
  final String hfRepo;
  final int encSize;
  final int decSize;

  String get encoder => '$prefix-encoder.int8.onnx';
  String get decoder => '$prefix-decoder.int8.onnx';
  String get tokens => '$prefix-tokens.txt';

  List<RemoteFile> get files {
    final b = 'https://huggingface.co/csukuangfj/$hfRepo/resolve/main';
    return [
      RemoteFile('$b/$encoder', encoder, encSize),
      RemoteFile('$b/$decoder', decoder, decSize),
      RemoteFile('$b/$tokens', tokens, 820000),
    ];
  }

  int get totalBytes => files.fold(0, (a, f) => a + f.size);

  static const tiny = WhisperModel('tiny', 'tiny', 'sherpa-onnx-whisper-tiny', 12937772, 89855401);
  static const base = WhisperModel('base', 'base', 'sherpa-onnx-whisper-base', 29120534, 130672026);
  static const small = WhisperModel('small', 'small', 'sherpa-onnx-whisper-small', 112442483, 262226114);
  static const all = [tiny, base, small];

  static WhisperModel byId(String id) => all.firstWhere((m) => m.id == id, orElse: () => small);
}

const _vadFile = RemoteFile(
  'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx',
  'silero_vad.onnx',
  643854,
);

/// Dosya yolları + indirme işleri.
class Store {
  Store._(this.support, this.docs);
  final Directory support;
  final Directory docs;

  static Future<Store> open() async {
    final s = await getApplicationSupportDirectory();
    final d = await getApplicationDocumentsDirectory();
    final store = Store._(Directory(p.join(s.path, 'VoiceScribe')), Directory(p.join(d.path, 'VoiceScribe')));
    for (final dir in [store.modelsDir, store.recordingsDir, store.transcriptsDir, store.binDir]) {
      await dir.create(recursive: true);
    }
    return store;
  }

  Directory get modelsDir => Directory(p.join(support.path, 'models'));
  Directory get binDir => Directory(p.join(support.path, 'bin'));
  Directory get recordingsDir => Directory(p.join(docs.path, 'Kayitlar'));
  Directory get transcriptsDir => Directory(p.join(docs.path, 'Transkriptler'));

  String modelPath(WhisperModel m, String file) => p.join(modelsDir.path, m.id, file);
  String get vadPath => p.join(modelsDir.path, _vadFile.name);

  bool hasModel(WhisperModel m) =>
      m.files.every((f) => File(modelPath(m, f.name)).existsSync()) && File(vadPath).existsSync();

  // ---------------- ffmpeg ----------------

  String get _ffName => Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';

  Future<String?> findFfmpeg() async {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final candidates = <String>[
      p.join(exeDir, _ffName),
      p.join(binDir.path, _ffName),
      if (Platform.isMacOS) ...[
        p.join(exeDir, '..', 'Resources', _ffName),
        '/opt/homebrew/bin/ffmpeg',
        '/usr/local/bin/ffmpeg',
      ],
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return p.normalize(c);
    }
    try {
      final r = await Process.run(Platform.isWindows ? 'where' : 'which', ['ffmpeg']);
      if (r.exitCode == 0) {
        final line = (r.stdout as String).split(RegExp(r'\r?\n')).first.trim();
        if (line.isNotEmpty && File(line).existsSync()) return line;
      }
    } catch (_) {}
    return null;
  }

  // ---------------- indirme ----------------

  /// [onProgress] 0..1
  Future<void> downloadModel(WhisperModel m, void Function(double) onProgress) async {
    final jobs = <(RemoteFile, String)>[
      (_vadFile, vadPath),
      for (final f in m.files) (f, modelPath(m, f.name)),
    ];
    await Directory(p.join(modelsDir.path, m.id)).create(recursive: true);
    final total = jobs.fold<int>(0, (a, j) => a + j.$1.size);
    var done = 0;
    for (final (f, dest) in jobs) {
      if (File(dest).existsSync()) {
        done += f.size;
        onProgress((done / total).clamp(0, 1));
        continue;
      }
      var got = 0;
      await _download(f.url, dest, (n) {
        got = n;
        onProgress(((done + got) / total).clamp(0, 0.999));
      });
      done += f.size;
    }
    onProgress(1);
  }

  Future<void> downloadFfmpeg(void Function(double) onProgress) async {
    final tmp = File(p.join(binDir.path, 'ffmpeg_download.zip'));
    final url = Platform.isWindows
        ? 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
        : 'https://evermeet.cx/ffmpeg/getrelease/zip';
    await _download(url, tmp.path, (n) {
      final total = Platform.isWindows ? 114768076 : 26198325;
      onProgress((n / total * 0.9).clamp(0, 0.9));
    });
    final input = InputFileStream(tmp.path);
    final archive = ZipDecoder().decodeStream(input);
    final entry = archive.files.firstWhere(
      (f) => f.isFile && p.basename(f.name).toLowerCase() == _ffName,
      orElse: () => throw Exception('ffmpeg arşivde bulunamadı'),
    );
    final out = File(p.join(binDir.path, _ffName));
    final os = OutputFileStream(out.path);
    entry.writeContent(os);
    await os.close();
    await input.close();
    if (!Platform.isWindows) await Process.run('chmod', ['+x', out.path]);
    try {
      await tmp.delete();
    } catch (_) {}
    onProgress(1);
  }

  Future<void> _download(String url, String dest, void Function(int) onBytes) async {
    final client = http.Client();
    final part = File('$dest.part');
    try {
      final req = http.Request('GET', Uri.parse(url));
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw Exception('İndirme hatası (${res.statusCode})');
      final sink = part.openWrite();
      var n = 0;
      var lastTick = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        n += chunk.length;
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastTick > 80) {
          lastTick = now;
          onBytes(n);
        }
      }
      await sink.flush();
      await sink.close();
      onBytes(n);
      if (File(dest).existsSync()) await File(dest).delete();
      await part.rename(dest);
    } catch (e) {
      try {
        if (part.existsSync()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close();
    }
  }
}
