import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/strings.dart';
import '../services/composer.dart';
import '../services/recents_store.dart';
import '../services/segmentation_service.dart';
import '../widgets/checkerboard.dart';
import '../widgets/compare_slider.dart';
import '../widgets/credits_bar.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

enum _Stage { preparing, removing, ready, error, noSubject }

class _EditorScreenState extends State<EditorScreen> {
  final SegmentationService _seg = SegmentationService();
  final ImagePicker _picker = ImagePicker();
  final TransformationController _tc = TransformationController();

  _Stage _stage = _Stage.preparing;

  late Uint8List _originalBytes;
  PreparedImage? _prepared;
  MaskData? _mask;
  ui.Image? _previewUi;

  BgMode _bgMode = BgMode.transparent;
  int _bgColor = 0xFFFFFFFF;
  Uint8List? _bgBytes;
  PreparedImage? _bgPrepared;

  final List<Stamp> _stamps = [];
  final List<Stamp> _activeStamps = [];
  bool _brushMode = false;
  bool _erase = true;
  double _brushRadius = 0.04;

  bool _compare = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _process();
  }

  @override
  void dispose() {
    _seg.dispose();
    _previewUi?.dispose();
    _tc.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    setState(() => _stage = _Stage.preparing);
    try {
      _originalBytes = await File(widget.imagePath).readAsBytes();
      final prepared = await Composer.prepare(_originalBytes);
      _prepared = prepared;

      setState(() => _stage = _Stage.removing);
      final mask = await _seg.segment(
        widget.imagePath,
        imageWidth: prepared.width,
        imageHeight: prepared.height,
      );
      if (mask == null) {
        setState(() => _stage = _Stage.noSubject);
        return;
      }
      _mask = mask;
      await _rebuildPreview();
      setState(() => _stage = _Stage.ready);
    } catch (_) {
      setState(() => _stage = _Stage.error);
    }
  }

  Future<void> _rebuildPreview() async {
    final prepared = _prepared!;
    final mask = _mask!;
    final image = await Composer.previewImage(
      prepared: prepared,
      mask: mask.mask,
      maskW: mask.width,
      maskH: mask.height,
      stamps: _stamps,
      bgMode: _bgMode,
      bgColor: _bgColor,
      bgRgba: _bgPrepared?.previewRgba,
      bgW: _bgPrepared?.previewW ?? 0,
      bgH: _bgPrepared?.previewH ?? 0,
    );
    final old = _previewUi;
    if (mounted) {
      setState(() => _previewUi = image);
    }
    old?.dispose();
  }

  // ---------- Background controls ----------

  Future<void> _setBg(BgMode mode) async {
    if (mode == BgMode.color) {
      await _pickColor();
      return;
    }
    if (mode == BgMode.image) {
      await _pickBgImage();
      return;
    }
    setState(() => _bgMode = BgMode.transparent);
    await _rebuildPreview();
  }

  Future<void> _pickColor() async {
    Color temp = Color(_bgColor);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('pick_a_color')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: temp,
            onColorChanged: (c) => temp = c,
            enableAlpha: false,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, temp),
            child: Text(tr('select')),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _bgColor = (0xFF << 24) |
            (picked.red << 16) |
            (picked.green << 8) |
            picked.blue;
        _bgMode = BgMode.color;
      });
      await _rebuildPreview();
    }
  }

  Future<void> _pickBgImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await File(file.path).readAsBytes();
    final prepared = await Composer.prepare(bytes);
    setState(() {
      _bgBytes = bytes;
      _bgPrepared = prepared;
      _bgMode = BgMode.image;
    });
    await _rebuildPreview();
  }

  // ---------- Brush ----------

  void _brushAt(Offset local, Size size) {
    final nx = (local.dx / size.width).clamp(0.0, 1.0);
    final ny = (local.dy / size.height).clamp(0.0, 1.0);
    final stamp = Stamp(nx, ny, _brushRadius, _erase);
    _stamps.add(stamp);
    setState(() => _activeStamps.add(stamp));
  }

  Future<void> _commitBrush() async {
    _activeStamps.clear();
    await _rebuildPreview();
  }

  Future<void> _resetBrush() async {
    if (_stamps.isEmpty) return;
    setState(() {
      _stamps.clear();
      _activeStamps.clear();
    });
    await _rebuildPreview();
  }

  // ---------- Export ----------

  bool get _isPng => _bgMode == BgMode.transparent;

  Future<Uint8List> _export() async {
    return Composer.exportFull(
      originalBytes: _originalBytes,
      mask: _mask!.mask,
      maskW: _mask!.width,
      maskH: _mask!.height,
      stamps: _stamps,
      bgMode: _bgMode,
      bgColor: _bgColor,
      bgBytes: _bgMode == BgMode.image ? _bgBytes : null,
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final bytes = await _export();
      await Gal.requestAccess();
      await Gal.putImageBytes(bytes,
          name: 'removebg_${DateTime.now().millisecondsSinceEpoch}');
      await RecentsStore.save(bytes, isPng: _isPng);
      _toast(tr('saved_to_gallery'));
    } catch (_) {
      _toast(tr('save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _export();
      final dir = await getTemporaryDirectory();
      final ext = _isPng ? 'png' : 'jpg';
      final path = p.join(
          dir.path, 'removebg_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await File(path).writeAsBytes(bytes);
      await RecentsStore.save(bytes, isPng: _isPng);
      await Share.shareXFiles([XFile(path)], text: tr('app_name'));
    } catch (_) {
      _toast(tr('save_failed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('app_name')),
        actions: [
          if (_stage == _Stage.ready)
            IconButton(
              tooltip: tr('compare'),
              icon: Icon(_compare ? Icons.compare : Icons.compare_arrows),
              onPressed: () => setState(() => _compare = !_compare),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_stage == _Stage.ready) _controls(),
          const CreditsBar(),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.preparing:
        return _status(tr('removing_bg'), spinner: true);
      case _Stage.removing:
        return _status(tr('removing_bg'), spinner: true);
      case _Stage.error:
        return _status(tr('model_error'), retry: true);
      case _Stage.noSubject:
        return _status(tr('no_subject'), retry: false, back: true);
      case _Stage.ready:
        return _canvas();
    }
  }

  Widget _status(String msg,
      {bool spinner = false, bool retry = false, bool back = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
            ] else ...[
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 16),
            ],
            Text(msg, textAlign: TextAlign.center),
            if (retry) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: _process, child: Text(tr('retry'))),
            ],
            if (back) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('done')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    final prepared = _prepared!;
    final aspect = prepared.width / prepared.height;

    if (_compare) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CompareSlider(
                before: Image.memory(_originalBytes, fit: BoxFit.fill),
                after: _previewUi == null
                    ? const SizedBox()
                    : RawImage(image: _previewUi, fit: BoxFit.fill),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(
            builder: (context, cons) {
              final size = Size(cons.maxWidth, cons.maxHeight);
              final content = Stack(
                fit: StackFit.expand,
                children: [
                  if (_bgMode == BgMode.transparent) const Checkerboard(),
                  if (_previewUi != null)
                    RawImage(image: _previewUi, fit: BoxFit.fill),
                  if (_brushMode)
                    CustomPaint(
                      painter: _StampPainter(_activeStamps, _erase, size),
                    ),
                ],
              );

              if (_brushMode) {
                return GestureDetector(
                  onPanStart: (d) => _brushAt(d.localPosition, size),
                  onPanUpdate: (d) => _brushAt(d.localPosition, size),
                  onPanEnd: (_) => _commitBrush(),
                  child: content,
                );
              }
              return InteractiveViewer(
                transformationController: _tc,
                maxScale: 6,
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _controls() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Background mode selector
            Row(
              children: [
                Text(tr('background'),
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<BgMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: BgMode.transparent,
                          icon: const Icon(Icons.grid_on, size: 18),
                          label: Text(tr('transparent'))),
                      ButtonSegment(
                          value: BgMode.color,
                          icon: const Icon(Icons.palette, size: 18),
                          label: Text(tr('color'))),
                      ButtonSegment(
                          value: BgMode.image,
                          icon: const Icon(Icons.image, size: 18),
                          label: Text(tr('image'))),
                    ],
                    selected: {_bgMode},
                    onSelectionChanged: (s) => _setBg(s.first),
                  ),
                ),
              ],
            ),
            // Brush controls
            Row(
              children: [
                FilterChip(
                  selected: _brushMode,
                  label: Text(tr('brush')),
                  avatar: const Icon(Icons.brush, size: 18),
                  onSelected: (v) {
                    setState(() {
                      _brushMode = v;
                      if (v) _tc.value = Matrix4.identity();
                    });
                  },
                ),
                if (_brushMode) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    selected: _erase,
                    label: Text(tr('erase')),
                    onSelected: (_) => setState(() => _erase = true),
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    selected: !_erase,
                    label: Text(tr('restore')),
                    onSelected: (_) => setState(() => _erase = false),
                  ),
                  IconButton(
                    tooltip: tr('reset_brush'),
                    icon: const Icon(Icons.undo),
                    onPressed: _resetBrush,
                  ),
                ],
              ],
            ),
            if (_brushMode)
              Row(
                children: [
                  const Icon(Icons.circle, size: 12),
                  Expanded(
                    child: Slider(
                      value: _brushRadius,
                      min: 0.01,
                      max: 0.15,
                      onChanged: (v) => setState(() => _brushRadius = v),
                    ),
                  ),
                  const Icon(Icons.circle, size: 24),
                ],
              ),
            // Save / share
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share),
                    label: Text(tr('share')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_alt),
                    label: Text(tr('save')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.stamps, this.erase, this.size);

  final List<Stamp> stamps;
  final bool erase;
  final Size size;

  @override
  void paint(Canvas canvas, Size s) {
    final longest = s.width > s.height ? s.width : s.height;
    final paint = Paint()
      ..color = (erase ? Colors.red : Colors.green).withOpacity(0.35);
    for (final st in stamps) {
      canvas.drawCircle(
        Offset(st.nx * s.width, st.ny * s.height),
        st.nr * longest,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) => true;
}
