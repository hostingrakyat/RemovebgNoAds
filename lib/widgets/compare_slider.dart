import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'checkerboard.dart';

/// Before/after compare slider with a draggable vertical divider.
/// [before] is revealed on the left, [after] on the right.
class CompareSlider extends StatefulWidget {
  const CompareSlider({
    super.key,
    required this.before,
    required this.after,
  });

  final Widget before;
  final Widget after;

  @override
  State<CompareSlider> createState() => _CompareSliderState();
}

class _CompareSliderState extends State<CompareSlider> {
  double _pos = 0.5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dividerX = (_pos * w).clamp(0.0, w);
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            setState(() {
              _pos = (_pos + d.delta.dx / w).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // After (full)
              Positioned.fill(child: const Checkerboard()),
              Positioned.fill(child: widget.after),
              // Before (clipped to the left of the divider)
              Positioned.fill(
                child: ClipRect(
                  clipper: _LeftClipper(dividerX),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Theme.of(context).colorScheme.surface),
                      widget.before,
                    ],
                  ),
                ),
              ),
              // Labels
              Positioned(
                left: 8,
                top: 8,
                child: _label(context, tr('before')),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: _label(context, tr('after')),
              ),
              // Divider handle
              Positioned(
                left: dividerX - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white),
              ),
              Positioned(
                left: dividerX - 18,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.unfold_more,
                        color: Colors.black54,
                        size: 22), // rotated visual cue
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  _LeftClipper(this.x);
  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(covariant _LeftClipper old) => old.x != x;
}
