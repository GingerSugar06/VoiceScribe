/// Basit TR/EN çeviri tablosu.
class L {
  L(this.code);
  final String code; // 'tr' | 'en'
  bool get tr => code == 'tr';

  String t(String k) => (_m[k]?[tr ? 0 : 1]) ?? k;

  static const _m = <String, List<String>>{
    'app': ['Voice Scribe', 'VoiceScribe'],
    'tagline': ['Konuş. Yazıya dönsün.', 'Speak. Get text.'],
    'nav_record': ['Canlı Kayıt', 'Live Record'],
    'nav_file': ['Dosyadan', 'From File'],
    'nav_history': ['Geçmiş', 'History'],
    'nav_settings': ['Ayarlar', 'Settings'],
    'lang_tr': ['Türkçe', 'Turkish'],
    'lang_en': ['İngilizce', 'English'],
    'lang_auto': ['Otomatik', 'Auto'],
    'speech_lang': ['Konuşma dili', 'Speech language'],
    'ui_lang': ['Arayüz dili', 'Interface language'],
    'tap_to_record': ['Kaydı başlatmak için dokun', 'Tap to start recording'],
    'listening': ['Dinleniyor…', 'Listening…'],
    'speaking': ['Konuşma algılandı', 'Speech detected'],
    'recording': ['Kaydediliyor', 'Recording'],
    'stop': ['Durdur', 'Stop'],
    'transcript': ['Transkript', 'Transcript'],
    'empty_live': [
      'Konuştukça metin burada belirecek.',
      'Your words will appear here as you speak.'
    ],
    'empty_file': [
      'Transkript burada görünecek.',
      'The transcript will appear here.'
    ],
    'drop_here': ['Ses veya video dosyasını buraya bırak', 'Drop an audio or video file here'],
    'or_browse': ['ya da dosya seç', 'or browse files'],
    'choose_file': ['Dosya seç', 'Choose file'],
    'formats': ['MP3 · WAV · M4A · FLAC · OGG · MP4 · MKV · MOV · WEBM …', 'MP3 · WAV · M4A · FLAC · OGG · MP4 · MKV · MOV · WEBM …'],
    'transcribing': ['Yazıya dökülüyor…', 'Transcribing…'],
    'cancel': ['İptal', 'Cancel'],
    'done': ['Tamamlandı', 'Done'],
    'copy': ['Kopyala', 'Copy'],
    'copied': ['Panoya kopyalandı', 'Copied to clipboard'],
    'save_txt': ['TXT kaydet', 'Save TXT'],
    'save_srt': ['SRT kaydet', 'Save SRT'],
    'saved': ['Kaydedildi', 'Saved'],
    'clear': ['Temizle', 'Clear'],
    'timestamps': ['Zaman damgaları', 'Timestamps'],
    'words': ['kelime', 'words'],
    'history_empty': ['Henüz kayıt yok.', 'Nothing here yet.'],
    'delete': ['Sil', 'Delete'],
    'open': ['Aç', 'Open'],
    'open_folder': ['Klasörü aç', 'Open folder'],
    'live': ['Canlı', 'Live'],
    'file': ['Dosya', 'File'],
    // kurulum
    'setup_title': ['Bir kerelik hazırlık', 'One-time setup'],
    'setup_sub': [
      'Tüm işlem cihazında çalışır. Ses verin hiçbir yere gönderilmez. Önce bir yapay zekâ modeli indirelim.',
      'Everything runs on your device. Your audio is never uploaded. Let\'s download a speech model first.'
    ],
    'model_tiny': ['Hızlı', 'Fast'],
    'model_base': ['Dengeli', 'Balanced'],
    'model_small': ['Doğru', 'Accurate'],
    'model_tiny_d': ['En hafif, kaba doğruluk', 'Lightest, rough accuracy'],
    'model_base_d': ['Hızlı ve idare eder', 'Quick and decent'],
    'model_small_d': ['Türkçe için önerilir', 'Recommended for Turkish'],
    'download_start': ['İndir ve başla', 'Download & start'],
    'downloading': ['İndiriliyor…', 'Downloading…'],
    'loading_model': ['Model yükleniyor…', 'Loading model…'],
    'retry': ['Tekrar dene', 'Retry'],
    'installed': ['Yüklü', 'Installed'],
    'not_installed': ['Yüklü değil', 'Not installed'],
    'use': ['Kullan', 'Use'],
    'active': ['Aktif', 'Active'],
    'ffmpeg_title': ['Dosya çözücü (ffmpeg)', 'File decoder (ffmpeg)'],
    'ffmpeg_d': [
      'Video ve ses dosyalarını okumak için gerekir.',
      'Needed to read video and audio files.'
    ],
    'ffmpeg_get': ['İndir', 'Download'],
    'ffmpeg_need': [
      'Dosya yazıya dökmek için önce ffmpeg indirilmeli (Ayarlar).',
      'Download ffmpeg first to transcribe files (Settings).'
    ],
    'mic_denied': ['Mikrofon izni verilmedi.', 'Microphone permission denied.'],
    'models': ['Modeller', 'Models'],
    'storage': ['Depolama', 'Storage'],
    'recordings_folder': ['Kayıtlar klasörü', 'Recordings folder'],
    'transcripts_folder': ['Transkriptler klasörü', 'Transcripts folder'],
    'privacy': ['%100 çevrimdışı · Gizlilik odaklı', '100% offline · Privacy first'],
    'mic_device': ['Mikrofon', 'Microphone'],
    'default_device': ['Varsayılan', 'Default'],
    'error': ['Hata', 'Error'],
    'elapsed': ['Süre', 'Duration'],
    'untitled_live': ['Canlı kayıt', 'Live recording'],
  };
}
