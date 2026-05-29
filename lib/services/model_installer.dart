import 'package:flutter/services.dart';

/// Drives the native Play Services ModuleInstallClient (see MainActivity.kt) to
/// explicitly download the ML Kit subject-segmentation model — far more reliable
/// than ML Kit's implicit first-use download, which can stall on some devices.
class ModelInstaller {
  static const MethodChannel _ch = MethodChannel('removebgnoads/model');

  static Future<bool> isAvailable() async {
    try {
      return await _ch.invokeMethod<bool>('isModelAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Kicks off the explicit module install (returns immediately).
  static Future<void> requestInstall() async {
    try {
      await _ch.invokeMethod('requestInstall');
    } catch (_) {}
  }

  /// Download progress 0..100, or -1 if unknown.
  static Future<int> progress() async {
    try {
      return await _ch.invokeMethod<int>('installProgress') ?? -1;
    } catch (_) {
      return -1;
    }
  }

  static Future<bool> failed() async {
    try {
      return await _ch.invokeMethod<bool>('installFailed') ?? false;
    } catch (_) {
      return false;
    }
  }
}
