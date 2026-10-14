import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:voice_scribe/engine/engine.dart';
import 'package:voice_scribe/engine/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('file transcription', (t) async {
    await t.runAsync(() async {
      final store = await Store.open();
      var ff = await store.findFfmpeg();
      if (ff == null) {
        await store.downloadFfmpeg((_) {});
        ff = await store.findFfmpeg();
      }
      expect(ff, isNotNull);
      final eng = Engine();
      await eng.load(store, WhisperModel.small, 'en');
      final out = <Segment>[];
      eng.segments.listen(out.add);
      final job = FileJob(eng, ff!);
      final sw = Stopwatch()..start();
      final ok = await job.run(r'C:\Users\user\AppData\Local\Temp\sestest\en.wav', onProgress: (_) {});
      await Future.delayed(const Duration(milliseconds: 300));
      // ignore: avoid_print
      print('RESULT ok=$ok ${sw.elapsed} -> ${out.map((s) => '[${s.start.toStringAsFixed(1)}-${s.end.toStringAsFixed(1)}] ${s.text}').join(' | ')}');
      expect(out, isNotEmpty);
      await eng.dispose();
    });
  }, timeout: const Timeout(Duration(minutes: 8)));
}
