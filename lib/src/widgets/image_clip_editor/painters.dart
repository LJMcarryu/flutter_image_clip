part of '../image_clip_editor.dart';

class _CropShade extends StatelessWidget {
  const _CropShade({required this.rect, required this.theme});

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(
            clipper: _CropShadeClipper(rect),
            child: _BlurredCropShade(theme: theme),
          ),
          CustomPaint(painter: _CropGridPainter(rect, theme)),
        ],
      ),
    );
  }
}

class _BlurredCropShade extends StatelessWidget {
  const _BlurredCropShade({required this.theme});

  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    final child = ColoredBox(color: theme.cropShadeColor);
    if (theme.cropShadeBlurSigma == 0) {
      return child;
    }
    return BackdropFilter(
      filter: ui.ImageFilter.blur(
        sigmaX: theme.cropShadeBlurSigma,
        sigmaY: theme.cropShadeBlurSigma,
      ),
      child: child,
    );
  }
}

class _CropShadeClipper extends CustomClipper<Path> {
  const _CropShadeClipper(this.rect);

  final Rect rect;

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
  }

  @override
  bool shouldReclip(covariant _CropShadeClipper oldClipper) {
    return oldClipper.rect != rect;
  }
}

class _CropGridPainter extends CustomPainter {
  const _CropGridPainter(this.rect, this.theme);

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = theme.cropGridColor
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = rect.left + rect.width * i / 3;
      final dy = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(dx, rect.top), Offset(dx, rect.bottom), grid);
      canvas.drawLine(Offset(rect.left, dy), Offset(rect.right, dy), grid);
    }
  }

  @override
  bool shouldRepaint(covariant _CropGridPainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.theme != theme;
  }
}
