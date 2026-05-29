import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Result of running ML Kit subject segmentation:
/// a foreground confidence mask (0..1) plus the grid dimensions it maps to.
class MaskData {
  MaskData({required this.mask, required this.width, required this.height});

  /// Confidence per cell, row-major, length == width * height.
  final Float32List mask;
  final int width;
  final int height;
}

/// Wraps ML Kit Subject Segmentation. Fully on-device after the one-time
/// model download (handled by Google Play Services on first use).
class SegmentationService {
  SegmentationService();

  final SubjectSegmenter _segmenter = SubjectSegmenter(
    options: SubjectSegmenterOptions(
      enableForegroundBitmap: false,
      enableForegroundConfidenceMask: true,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    ),
  );

  /// Runs segmentation on the image file.
  ///
  /// [imageWidth]/[imageHeight] are the decoded original dimensions, used to
  /// infer the mask grid. The foreground confidence mask is the same size as
  /// the input image; if a device returns a different count we recover the
  /// grid from the count and the image aspect ratio.
  ///
  /// Returns null when no subject is detected.
  Future<MaskData?> segment(
    String imagePath, {
    required int imageWidth,
    required int imageHeight,
  }) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _segmenter.processImage(input);
    final confidence = result.foregroundConfidenceMask;
    if (confidence == null || confidence.isEmpty) return null;

    final mask = Float32List.fromList(confidence);

    int w = imageWidth;
    int h = imageHeight;
    if (mask.length != imageWidth * imageHeight) {
      // Recover the grid from the count keeping the image aspect ratio.
      final aspect = imageWidth / imageHeight;
      w = _approxWidth(mask.length, aspect);
      h = (mask.length / w).round().clamp(1, mask.length);
    }
    return MaskData(mask: mask, width: w, height: h);
  }

  int _approxWidth(int count, double aspect) {
    // count = w * h, w = aspect * h  => w = sqrt(count * aspect)
    final w = (count * aspect);
    final root = _isqrt(w.round());
    return root.clamp(1, count);
  }

  int _isqrt(int n) {
    if (n <= 0) return 1;
    var x = n;
    var y = (x + 1) >> 1;
    while (y < x) {
      x = y;
      y = (x + n ~/ x) >> 1;
    }
    return x;
  }

  /// Probes whether the on-device model is ready by running the segmenter on a
  /// tiny generated image. Running the segmenter triggers the one-time Play
  /// Services model download; the call throws until the model is available, so
  /// a successful return means the model is downloaded and we can work offline.
  Future<bool> ensureReady() async {
    try {
      final path = await _probeImagePath();
      await _segmenter.processImage(InputImage.fromFilePath(path));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _probeImagePath() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'mlkit_probe.png'));
    if (!await file.exists()) {
      final image = img.Image(width: 256, height: 256);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      img.fillCircle(image,
          x: 128, y: 128, radius: 70, color: img.ColorRgb8(240, 240, 240));
      await file.writeAsBytes(img.encodePng(image));
    }
    return file.path;
  }

  void dispose() => _segmenter.close();
}
