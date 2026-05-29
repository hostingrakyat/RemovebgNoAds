import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decoded original metadata + a downscaled preview buffer for fast editing.
class PreparedImage {
  PreparedImage({
    required this.width,
    required this.height,
    required this.previewRgba,
    required this.previewW,
    required this.previewH,
  });

  final int width;
  final int height;
  final Uint8List previewRgba; // RGBA8888, previewW * previewH * 4
  final int previewW;
  final int previewH;
}

/// A single brush stamp in normalized image coordinates.
class Stamp {
  Stamp(this.nx, this.ny, this.nr, this.erase);
  final double nx;
  final double ny;
  final double nr; // radius as a fraction of the longest side
  final bool erase;
}

enum BgMode { transparent, color, image }

class _ComposeInput {
  _ComposeInput({
    required this.srcRgba,
    required this.w,
    required this.h,
    required this.mask,
    required this.maskW,
    required this.maskH,
    required this.stamps,
    required this.bgMode,
    required this.bgColor,
    this.bgRgba,
    this.bgW = 0,
    this.bgH = 0,
  });

  final Uint8List srcRgba;
  final int w;
  final int h;
  final Float32List mask;
  final int maskW;
  final int maskH;
  final Float32List stamps; // stride 4: nx, ny, nr, erase(0/1)
  final int bgMode; // index of BgMode
  final int bgColor; // 0xAARRGGBB
  final Uint8List? bgRgba;
  final int bgW;
  final int bgH;
}

class _ExportInput {
  _ExportInput({
    required this.originalBytes,
    required this.mask,
    required this.maskW,
    required this.maskH,
    required this.stamps,
    required this.bgMode,
    required this.bgColor,
    this.bgBytes,
  });

  final Uint8List originalBytes;
  final Float32List mask;
  final int maskW;
  final int maskH;
  final Float32List stamps;
  final int bgMode;
  final int bgColor;
  final Uint8List? bgBytes;
}

const double _alphaLo = 0.35;
const double _alphaHi = 0.55;

double _alphaFromConf(double c) {
  final t = ((c - _alphaLo) / (_alphaHi - _alphaLo)).clamp(0.0, 1.0);
  return t;
}

double _sampleMask(Float32List mask, int mw, int mh, double u, double v) {
  if (mw <= 1 || mh <= 1) return mask.isEmpty ? 0 : mask[0];
  final fx = (u * (mw - 1)).clamp(0.0, mw - 1.0);
  final fy = (v * (mh - 1)).clamp(0.0, mh - 1.0);
  final x0 = fx.floor();
  final y0 = fy.floor();
  final x1 = (x0 + 1).clamp(0, mw - 1);
  final y1 = (y0 + 1).clamp(0, mh - 1);
  final dx = fx - x0;
  final dy = fy - y0;
  final a = mask[y0 * mw + x0];
  final b = mask[y0 * mw + x1];
  final c = mask[y1 * mw + x0];
  final d = mask[y1 * mw + x1];
  final top = a + (b - a) * dx;
  final bot = c + (d - c) * dx;
  return top + (bot - top) * dy;
}

/// Build the base alpha buffer (0..255) from the confidence mask.
Uint8List _baseAlpha(Float32List mask, int mw, int mh, int w, int h) {
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final v = h <= 1 ? 0.0 : y / (h - 1);
    for (var x = 0; x < w; x++) {
      final u = w <= 1 ? 0.0 : x / (w - 1);
      out[y * w + x] = (_alphaFromConf(_sampleMask(mask, mw, mh, u, v)) * 255)
          .round()
          .clamp(0, 255);
    }
  }
  return out;
}

/// Apply brush stamps onto [alpha] in place. Erase -> 0, restore -> base value.
void _applyStamps(
  Uint8List alpha,
  Uint8List base,
  Float32List stamps,
  int w,
  int h,
) {
  final longest = w > h ? w : h;
  for (var s = 0; s + 3 < stamps.length; s += 4) {
    final cx = stamps[s] * w;
    final cy = stamps[s + 1] * h;
    final r = stamps[s + 2] * longest;
    final erase = stamps[s + 3] >= 0.5;
    if (r <= 0) continue;
    final r2 = r * r;
    final minX = (cx - r).floor().clamp(0, w - 1);
    final maxX = (cx + r).ceil().clamp(0, w - 1);
    final minY = (cy - r).floor().clamp(0, h - 1);
    final maxY = (cy + r).ceil().clamp(0, h - 1);
    for (var y = minY; y <= maxY; y++) {
      final dy = y - cy;
      for (var x = minX; x <= maxX; x++) {
        final dx = x - cx;
        if (dx * dx + dy * dy > r2) continue;
        final i = y * w + x;
        alpha[i] = erase ? 0 : base[i];
      }
    }
  }
}

/// Composite src pixels + alpha over the chosen background, returns RGBA.
Uint8List _composeRgba(_ComposeInput a) {
  final base = _baseAlpha(a.mask, a.maskW, a.maskH, a.w, a.h);
  final alpha = Uint8List.fromList(base);
  if (a.stamps.isNotEmpty) {
    _applyStamps(alpha, base, a.stamps, a.w, a.h);
  }

  final out = Uint8List(a.w * a.h * 4);
  final mode = BgMode.values[a.bgMode];
  final bgA = (a.bgColor >> 24) & 0xFF;
  final bgR = (a.bgColor >> 16) & 0xFF;
  final bgG = (a.bgColor >> 8) & 0xFF;
  final bgB = a.bgColor & 0xFF;

  for (var y = 0; y < a.h; y++) {
    for (var x = 0; x < a.w; x++) {
      final i = y * a.w + x;
      final p = i * 4;
      final sr = a.srcRgba[p];
      final sg = a.srcRgba[p + 1];
      final sb = a.srcRgba[p + 2];
      final al = alpha[i];

      switch (mode) {
        case BgMode.transparent:
          out[p] = sr;
          out[p + 1] = sg;
          out[p + 2] = sb;
          out[p + 3] = al;
          break;
        case BgMode.color:
          final t = al / 255.0;
          out[p] = (sr * t + bgR * (1 - t)).round();
          out[p + 1] = (sg * t + bgG * (1 - t)).round();
          out[p + 2] = (sb * t + bgB * (1 - t)).round();
          out[p + 3] = 255;
          break;
        case BgMode.image:
          int br = bgR, bg = bgG, bb = bgB;
          if (a.bgRgba != null && a.bgW > 0 && a.bgH > 0) {
            // Cover-fit sample.
            final scale = (a.bgW / a.w) > (a.bgH / a.h)
                ? a.bgH / a.h
                : a.bgW / a.w;
            final offX = (a.bgW - a.w * scale) / 2;
            final offY = (a.bgH - a.h * scale) / 2;
            final bx = (x * scale + offX).floor().clamp(0, a.bgW - 1);
            final by = (y * scale + offY).floor().clamp(0, a.bgH - 1);
            final bp = (by * a.bgW + bx) * 4;
            br = a.bgRgba![bp];
            bg = a.bgRgba![bp + 1];
            bb = a.bgRgba![bp + 2];
          }
          final t = al / 255.0;
          out[p] = (sr * t + br * (1 - t)).round();
          out[p + 1] = (sg * t + bg * (1 - t)).round();
          out[p + 2] = (sb * t + bb * (1 - t)).round();
          out[p + 3] = 255;
          break;
      }
    }
  }
  // Suppress unused warning for bgA when not transparent.
  if (bgA < 0) out[0] = 0;
  return out;
}

// ---------- Isolate entry points ----------

PreparedImage _prepareEntry(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Unable to decode image');
  }
  final oriented = img.bakeOrientation(decoded);
  final w = oriented.width;
  final h = oriented.height;

  const maxSide = 1000;
  final longest = w > h ? w : h;
  img.Image preview = oriented;
  int pw = w, ph = h;
  if (longest > maxSide) {
    final scale = maxSide / longest;
    pw = (w * scale).round();
    ph = (h * scale).round();
    preview = img.copyResize(oriented, width: pw, height: ph);
  }
  final previewRgba = preview.getBytes(order: img.ChannelOrder.rgba);
  return PreparedImage(
    width: w,
    height: h,
    previewRgba: previewRgba,
    previewW: pw,
    previewH: ph,
  );
}

Uint8List _exportEntry(_ExportInput a) {
  final decoded = img.decodeImage(a.originalBytes);
  if (decoded == null) throw StateError('Unable to decode image');
  final oriented = img.bakeOrientation(decoded);
  final w = oriented.width;
  final h = oriented.height;
  final srcRgba = oriented.getBytes(order: img.ChannelOrder.rgba);

  Uint8List? bgRgba;
  int bgW = 0, bgH = 0;
  if (a.bgBytes != null) {
    final bgDecoded = img.decodeImage(a.bgBytes!);
    if (bgDecoded != null) {
      final bgOriented = img.bakeOrientation(bgDecoded);
      bgW = bgOriented.width;
      bgH = bgOriented.height;
      bgRgba = bgOriented.getBytes(order: img.ChannelOrder.rgba);
    }
  }

  final rgba = _composeRgba(_ComposeInput(
    srcRgba: srcRgba,
    w: w,
    h: h,
    mask: a.mask,
    maskW: a.maskW,
    maskH: a.maskH,
    stamps: a.stamps,
    bgMode: a.bgMode,
    bgColor: a.bgColor,
    bgRgba: bgRgba,
    bgW: bgW,
    bgH: bgH,
  ));

  final outImg = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );

  if (a.bgMode == BgMode.transparent.index) {
    return Uint8List.fromList(img.encodePng(outImg));
  }
  return Uint8List.fromList(img.encodeJpg(outImg, quality: 95));
}

// ---------- Public API ----------

class Composer {
  /// Decode the original and produce a downscaled preview buffer.
  static Future<PreparedImage> prepare(Uint8List bytes) {
    return compute(_prepareEntry, bytes);
  }

  /// Build a preview [ui.Image] at preview resolution (runs the pixel loop on
  /// the platform thread is unnecessary at this size; kept on the UI isolate).
  static Future<ui.Image> previewImage({
    required PreparedImage prepared,
    required Float32List mask,
    required int maskW,
    required int maskH,
    required List<Stamp> stamps,
    required BgMode bgMode,
    required int bgColor,
    Uint8List? bgRgba,
    int bgW = 0,
    int bgH = 0,
  }) async {
    final rgba = _composeRgba(_ComposeInput(
      srcRgba: prepared.previewRgba,
      w: prepared.previewW,
      h: prepared.previewH,
      mask: mask,
      maskW: maskW,
      maskH: maskH,
      stamps: _flatten(stamps),
      bgMode: bgMode.index,
      bgColor: bgColor,
      bgRgba: bgRgba,
      bgW: bgW,
      bgH: bgH,
    ));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      prepared.previewW,
      prepared.previewH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Full-resolution export to PNG (transparent) or JPG (solid/image bg).
  static Future<Uint8List> exportFull({
    required Uint8List originalBytes,
    required Float32List mask,
    required int maskW,
    required int maskH,
    required List<Stamp> stamps,
    required BgMode bgMode,
    required int bgColor,
    Uint8List? bgBytes,
  }) {
    return compute(
      _exportEntry,
      _ExportInput(
        originalBytes: originalBytes,
        mask: mask,
        maskW: maskW,
        maskH: maskH,
        stamps: _flatten(stamps),
        bgMode: bgMode.index,
        bgColor: bgColor,
        bgBytes: bgBytes,
      ),
    );
  }

  static Float32List _flatten(List<Stamp> stamps) {
    final out = Float32List(stamps.length * 4);
    for (var i = 0; i < stamps.length; i++) {
      final s = stamps[i];
      out[i * 4] = s.nx;
      out[i * 4 + 1] = s.ny;
      out[i * 4 + 2] = s.nr;
      out[i * 4 + 3] = s.erase ? 1.0 : 0.0;
    }
    return out;
  }
}
