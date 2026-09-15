import 'dart:ui' as ui;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

/// Tiles the 100×100 rasterised [tileImage] across the canvas using a single
/// GPU-side [ImageShader] draw call instead of a CPU-side loop.
class NovaChatPatternPainter extends CustomPainter {
  const NovaChatPatternPainter({
    required this.tileImage,
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  final ui.Image tileImage;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Solid background.
    if (backgroundColor != Colors.transparent) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = backgroundColor,
      );
    }

    // 2. Single GPU draw — the shader handles tiling.
    final shader = ImageShader(
      tileImage,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant NovaChatPatternPainter old) =>
      old.tileImage != tileImage || old.backgroundColor != backgroundColor;
}

// ---------------------------------------------------------------------------
// Static image cache
// ---------------------------------------------------------------------------

/// Static store — at most one entry per distinct (color, opacity) pair.
/// Images are intentionally long-lived (app lifetime) so no disposal is needed.
final Map<int, ui.Image> _tileCache = {};

/// Returns a 100×100 rasterised [ui.Image] from [_tileCache], creating it
/// synchronously on first use via [ui.Picture.toImageSync].
ui.Image _getOrCreateTile(Color color, double opacity) {
  final key = Object.hash(color, opacity);
  return _tileCache.putIfAbsent(
    key,
    () => _renderTileSync(color, opacity),
  );
}

/// Draws all 7 landing-page motifs into a 100×100 tile and rasterises it
/// synchronously. [ui.Picture] is disposed immediately after rasterisation.
ui.Image _renderTileSync(Color color, double opacity) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 100, 100));

  final effectiveColor = color.withValues(alpha: opacity);

  final strokePaint = Paint()
    ..color = effectiveColor
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final fillPaint = Paint()
    ..color = effectiveColor
    ..style = PaintingStyle.fill;

  // 1. Chevrons < > — d='M12 18l-4-4 4-4M20 10l4 4-4 4'
  canvas.drawPath(
    Path()
      ..moveTo(12, 18)
      ..lineTo(8, 14)
      ..lineTo(12, 10)
      ..moveTo(20, 10)
      ..lineTo(24, 14)
      ..lineTo(20, 18),
    strokePaint,
  );

  // 2. 4-pointed star (filled) — d='M50 15l1.5 3.5L55 20l-3.5 1.5L50 25l-1.5-3.5L45 20l3.5-1.5z'
  canvas.drawPath(
    Path()
      ..moveTo(50, 15)
      ..lineTo(51.5, 18.5)
      ..lineTo(55, 20)
      ..lineTo(51.5, 21.5)
      ..lineTo(50, 25)
      ..lineTo(48.5, 21.5)
      ..lineTo(45, 20)
      ..lineTo(48.5, 18.5)
      ..close(),
    fillPaint,
  );

  // 3. Lock — d='M80 18v-2a3 3 0 0 0-6 0v2h-1v6h8v-6h-1z'
  canvas.drawPath(
    Path()
      ..moveTo(80, 18)
      ..lineTo(80, 16)
      ..arcToPoint(
        const Offset(74, 16),
        radius: const Radius.circular(3),
        clockwise: false,
      )
      ..lineTo(74, 18)
      ..lineTo(73, 18)
      ..lineTo(73, 24)
      ..lineTo(81, 24)
      ..lineTo(81, 18)
      ..close(),
    strokePaint,
  );

  // 4. Speech bubble — d='M15 55a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v3a4 4 0 0 1-4 4h-3l-3 3v-3h-2a4 4 0 0 1-4-4v-3z'
  canvas.drawPath(
    Path()
      ..moveTo(15, 55)
      ..arcToPoint(const Offset(19, 51), radius: const Radius.circular(4))
      ..lineTo(27, 51)
      ..arcToPoint(const Offset(31, 55), radius: const Radius.circular(4))
      ..lineTo(31, 58)
      ..arcToPoint(const Offset(27, 62), radius: const Radius.circular(4))
      ..lineTo(24, 62)
      ..lineTo(21, 65)
      ..lineTo(21, 62)
      ..lineTo(19, 62)
      ..arcToPoint(const Offset(15, 58), radius: const Radius.circular(4))
      ..close(),
    strokePaint,
  );

  // 5. Crosshair — circle cx='80' cy='55' r='5', M75 55h10M80 50v10
  canvas.drawCircle(const Offset(80, 55), 5, strokePaint);
  canvas.drawLine(const Offset(75, 55), const Offset(85, 55), strokePaint);
  canvas.drawLine(const Offset(80, 50), const Offset(80, 60), strokePaint);

  // 6. Shield — d='M50 80l4-2v-4a4 4 0 0 0-4-4 4 4 0 0 0-4 4v4l4 2z'
  canvas.drawPath(
    Path()
      ..moveTo(50, 80)
      ..lineTo(54, 78)
      ..lineTo(54, 74)
      ..arcToPoint(
        const Offset(50, 70),
        radius: const Radius.circular(4),
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(46, 74),
        radius: const Radius.circular(4),
        clockwise: false,
      )
      ..lineTo(46, 78)
      ..close(),
    strokePaint,
  );

  // 7. Lightning bolt (filled) — d='M20 85l3-5h-3l2-5-5 6h3l-2 4z'
  canvas.drawPath(
    Path()
      ..moveTo(20, 85)
      ..lineTo(23, 80)
      ..lineTo(20, 80)
      ..lineTo(22, 75)
      ..lineTo(17, 81)
      ..lineTo(20, 81)
      ..lineTo(18, 85)
      ..close(),
    fillPaint,
  );

  final picture = recorder.endRecording();
  final image = picture.toImageSync(100, 100); // synchronous — no Future
  picture.dispose(); // picture no longer needed after rasterisation
  return image;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Renders the translucent tech pattern background that matches the Kockatoos
/// landing page, tiled via a single GPU [ImageShader] draw call.
///
/// The 100×100 tile image is created once per distinct [patternColor] +
/// [patternOpacity] combination and cached for the lifetime of the app.
/// No [State] is needed — [StatelessWidget] is sufficient because the tile
/// image is ready synchronously via [ui.Picture.toImageSync].
class NovaChatPatternBackground extends StatelessWidget {
  const NovaChatPatternBackground({
    super.key,
    this.child,
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.patternColor = const Color(0xFF475569),
    this.patternOpacity = 0.05,
  });

  final Widget? child;

  /// Solid wash painted beneath the repeating pattern.
  final Color backgroundColor;

  /// Stroke / fill colour of the motifs before opacity is applied.
  final Color patternColor;

  /// Opacity applied to [patternColor] (0.0 – 1.0).
  final double patternOpacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      isComplex: true,    // hint: engine may cache the raster layer
      willChange: false,  // hint: content is static
      painter: NovaChatPatternPainter(
        tileImage: _getOrCreateTile(patternColor, patternOpacity),
        backgroundColor: backgroundColor,
      ),
      child: child,
    );
  }
}
