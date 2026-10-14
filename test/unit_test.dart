import 'package:flutter_test/flutter_test.dart';
import 'package:voice_scribe/engine/models.dart';
import 'package:voice_scribe/l10n.dart';

void main() {
  test('çeviri: bilinen anahtar iki dilde farklı, bilinmeyen anahtar kendisini döndürür', () {
    expect(L('tr').t('nav_record'), 'Canlı Kayıt');
    expect(L('en').t('nav_record'), 'Live Record');
    expect(L('en').t('yok_boyle_anahtar'), 'yok_boyle_anahtar');
  });

  test('her model seçeneği üç dosya ister', () {
    for (final id in ['tiny', 'base', 'small']) {
      final m = WhisperModel.byId(id);
      expect(m.files.length, 3, reason: id);
      expect(m.encoder, endsWith('.onnx'));
    }
  });
}
