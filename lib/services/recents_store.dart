import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores exported results in the app documents directory and lists them.
class RecentsStore {
  static Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recent'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Save [bytes] as a new result; returns the saved file path.
  static Future<String> save(Uint8List bytes, {required bool isPng}) async {
    final dir = await _dir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = isPng ? 'png' : 'jpg';
    final file = File(p.join(dir.path, 'rbg_$ts.$ext'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Most-recent-first list of saved result paths.
  static Future<List<String>> list() async {
    final dir = await _dir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.png') || f.path.endsWith('.jpg'))
        .toList();
    files.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return files.map((f) => f.path).toList();
  }

  static Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
