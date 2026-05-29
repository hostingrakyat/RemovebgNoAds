import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Saves images to the device gallery via a native MediaStore MethodChannel
/// (implemented in MainActivity.kt). No third-party plugin required.
class Gallery {
  static const MethodChannel _channel =
      MethodChannel('removebgnoads/gallery');

  static Future<void> save(
    Uint8List bytes, {
    required String name,
    required bool isPng,
  }) async {
    await _channel.invokeMethod<bool>('saveImage', {
      'bytes': bytes,
      'name': name,
      'isPng': isPng,
    });
  }
}
