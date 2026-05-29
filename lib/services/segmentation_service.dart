import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

/// Result of running segmentation: a foreground confidence mask (0..1) plus the
/// grid dimensions it maps to.
class MaskData {
  MaskData({required this.mask, required this.width, required this.height});

  /// Confidence per cell, row-major, length == width * height.
  final Float32List mask;
  final int width;
  final int height;
}

const int _kSize = 320; // U^2-Net input/output side
const String _kModelAsset = 'assets/models/silueta.onnx';
const String _kInputName = 'input.1';

// ImageNet normalization used by U^2-Net (rembg).
const List<double> _kMean = [0.485, 0.456, 0.406];
const List<double> _kStd = [0.229, 0.224, 0.225];

/// Decode + orient + resize to 320x320, then build a normalized NCHW float32
/// tensor. Runs in a background isolate via [compute].
Float32List? _preprocess(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  final resized = img.copyResize(oriented, width: _kSize, height: _kSize);
  final rgb = resized.getBytes(order: img.ChannelOrder.rgb);

  final area = _kSize * _kSize;
  final out = Float32List(3 * area);
  for (var i = 0; i < area; i++) {
    final r = rgb[i * 3] / 255.0;
    final g = rgb[i * 3 + 1] / 255.0;
    final b = rgb[i * 3 + 2] / 255.0;
    out[i] = (r - _kMean[0]) / _kStd[0]; // R plane
    out[area + i] = (g - _kMean[1]) / _kStd[1]; // G plane
    out[2 * area + i] = (b - _kMean[2]) / _kStd[2]; // B plane
  }
  return out;
}

/// Wraps the bundled U^2-Net (silueta) model running on ONNX Runtime. Fully
/// on-device and offline — no Google Play Services, no downloads. The ORT
/// session is created once (lazily) and reused across editor sessions.
class SegmentationService {
  SegmentationService._();

  /// Shared instance — the loaded model (~42 MB) is kept alive for reuse.
  static final SegmentationService instance = SegmentationService._();

  OrtSession? _session;
  bool _envInitialized = false;

  Future<void> _ensureSession() async {
    if (_session != null) return;
    if (!_envInitialized) {
      OrtEnv.instance.init();
      _envInitialized = true;
    }
    final raw = await rootBundle.load(_kModelAsset);
    final bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    _session = OrtSession.fromBuffer(bytes, OrtSessionOptions());
  }

  /// Runs segmentation on the image file. Returns a 320x320 confidence mask
  /// (0..1) which the composer upsamples and turns into alpha. Returns null
  /// when no salient subject is found.
  Future<MaskData?> segment(
    String imagePath, {
    required int imageWidth,
    required int imageHeight,
  }) async {
    await _ensureSession();
    final session = _session!;

    final fileBytes = await File(imagePath).readAsBytes();
    final input = await compute(_preprocess, fileBytes);
    if (input == null) return null;

    final inputName =
        session.inputNames.isNotEmpty ? session.inputNames.first : _kInputName;
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      input,
      [1, 3, _kSize, _kSize],
    );
    final runOptions = OrtRunOptions();

    List<OrtValue?>? outputs;
    try {
      outputs = await session.runAsync(runOptions, {inputName: inputTensor});
    } finally {
      inputTensor.release();
      runOptions.release();
    }
    if (outputs == null || outputs.isEmpty) return null;

    final value = outputs[0]?.value; // [1,1,320,320] -> nested List<double>
    for (final o in outputs) {
      o?.release();
    }
    if (value is! List) return null;

    final plane = (value[0] as List)[0] as List; // [320][320]
    final mask = Float32List(_kSize * _kSize);
    var minV = double.infinity;
    var maxV = -double.infinity;
    for (var y = 0; y < _kSize; y++) {
      final row = plane[y] as List;
      for (var x = 0; x < _kSize; x++) {
        final v = (row[x] as num).toDouble();
        mask[y * _kSize + x] = v;
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
    }

    // No salient region detected.
    if (maxV < 0.05) return null;

    // Stretch to 0..1 (U^2-Net normPRED).
    final range = maxV - minV;
    if (range > 1e-6) {
      for (var i = 0; i < mask.length; i++) {
        mask[i] = (mask[i] - minV) / range;
      }
    }

    return MaskData(mask: mask, width: _kSize, height: _kSize);
  }

  /// Kept for API parity with callers. The shared session is intentionally
  /// reused across editor screens, so this is a no-op.
  void dispose() {}
}
