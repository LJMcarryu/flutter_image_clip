part of '../image_clip_editor.dart';

class _CropShade extends StatelessWidget {
  const _CropShade({required this.rect, required this.theme});

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _CropShadePainter(rect, theme)),
    );
  }
}

class _CropShadePainter extends CustomPainter {
  const _CropShadePainter(this.rect, this.theme);

  final Rect rect;
  final ImageClipEditorTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = theme.cropShadeColor;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, shade);

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
  bool shouldRepaint(covariant _CropShadePainter oldDelegate) {
    return oldDelegate.rect != rect || oldDelegate.theme != theme;
  }
}
