import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLang { en, id }

/// Global, lightweight localization controller.
/// Rebuild the app by listening to [appLang]; read text via [tr].
final ValueNotifier<AppLang> appLang = ValueNotifier<AppLang>(AppLang.en);

const String _prefKey = 'app_lang';

Future<void> loadSavedLang() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefKey);
  if (saved == 'id') appLang.value = AppLang.id;
  if (saved == 'en') appLang.value = AppLang.en;
}

Future<void> setLang(AppLang lang) async {
  appLang.value = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey, lang == AppLang.id ? 'id' : 'en');
}

/// Translate [key] for the current language. Falls back to the key itself.
String tr(String key) {
  final map = _strings[appLang.value] ?? _strings[AppLang.en]!;
  return map[key] ?? _strings[AppLang.en]![key] ?? key;
}

const Map<AppLang, Map<String, String>> _strings = {
  AppLang.en: {
    'app_name': 'Removebg No Ads',
    'tagline': 'Background remover · Free · No Ads · Offline · HD',
    'choose_language': 'Choose language',
    'english': 'English',
    'indonesian': 'Bahasa Indonesia',
    'continue': 'Continue',
    'badge': '365 Days App Challenge · Day 5',
    'pick_image': 'Pick Image',
    'take_photo': 'Take Photo',
    'recent_results': 'Recent results',
    'no_recents': 'Your removed-background images will appear here.',
    'created_by': 'Created by: Ir. Riovan Styx Roring',
    'removing_bg': 'Removing background…',
    'preparing_model': 'Preparing model (one-time, needs internet)…',
    'model_error':
        'Could not prepare the segmentation model. It downloads once and needs internet the first time. Please connect and retry.',
    'retry': 'Retry',
    'no_subject':
        'No subject detected. Try another photo with a clearer foreground subject.',
    'background': 'Background',
    'transparent': 'Transparent',
    'color': 'Color',
    'image': 'Image',
    'brush': 'Brush',
    'erase': 'Erase',
    'restore': 'Restore',
    'brush_size': 'Brush size',
    'compare': 'Compare',
    'before': 'Before',
    'after': 'After',
    'save': 'Save',
    'share': 'Share',
    'saved_to_gallery': 'Saved to gallery',
    'save_failed': 'Save failed',
    'pick_bg_image': 'Pick background image',
    'pick_a_color': 'Pick a color',
    'select': 'Select',
    'cancel': 'Cancel',
    'permission_needed':
        'Permission is required to continue. Enable it in settings.',
    'open_settings': 'Open settings',
    'reset_brush': 'Reset brush edits',
    'done': 'Done',
  },
  AppLang.id: {
    'app_name': 'Removebg No Ads',
    'tagline': 'Penghapus latar · Gratis · Tanpa Iklan · Offline · HD',
    'choose_language': 'Pilih bahasa',
    'english': 'English',
    'indonesian': 'Bahasa Indonesia',
    'continue': 'Lanjut',
    'badge': '365 Days App Challenge · Hari 5',
    'pick_image': 'Pilih Gambar',
    'take_photo': 'Ambil Foto',
    'recent_results': 'Hasil terbaru',
    'no_recents': 'Gambar tanpa latar Anda akan muncul di sini.',
    'created_by': 'Dibuat oleh: Ir. Riovan Styx Roring',
    'removing_bg': 'Menghapus latar…',
    'preparing_model': 'Menyiapkan model (sekali, perlu internet)…',
    'model_error':
        'Tidak dapat menyiapkan model segmentasi. Model diunduh sekali dan perlu internet pertama kali. Sambungkan internet lalu coba lagi.',
    'retry': 'Coba lagi',
    'no_subject':
        'Tidak ada subjek terdeteksi. Coba foto lain dengan subjek depan yang lebih jelas.',
    'background': 'Latar',
    'transparent': 'Transparan',
    'color': 'Warna',
    'image': 'Gambar',
    'brush': 'Kuas',
    'erase': 'Hapus',
    'restore': 'Pulihkan',
    'brush_size': 'Ukuran kuas',
    'compare': 'Bandingkan',
    'before': 'Sebelum',
    'after': 'Sesudah',
    'save': 'Simpan',
    'share': 'Bagikan',
    'saved_to_gallery': 'Tersimpan ke galeri',
    'save_failed': 'Gagal menyimpan',
    'pick_bg_image': 'Pilih gambar latar',
    'pick_a_color': 'Pilih warna',
    'select': 'Pilih',
    'cancel': 'Batal',
    'permission_needed':
        'Izin diperlukan untuk melanjutkan. Aktifkan di pengaturan.',
    'open_settings': 'Buka pengaturan',
    'reset_brush': 'Atur ulang kuas',
    'done': 'Selesai',
  },
};
