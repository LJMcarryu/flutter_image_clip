part of 'image_processor.dart';

img.Image _createSampleImage() {
  const width = 960;
  const height = 640;
  final image = img.Image(width: width, height: height, numChannels: 4);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final dx = x / (width - 1);
      final dy = y / (height - 1);
      final r = (32 + 122 * dx + 28 * math.sin(dy * math.pi)).round();
      final g = (76 + 100 * dy + 42 * math.cos(dx * math.pi)).round();
      final b = (112 + 88 * (1 - dx) + 26 * math.sin((dx + dy) * math.pi))
          .round();
      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  _fillRect(image, 76, 72, 318, 210, 255, 236, 179, 0.86);
  _fillRect(image, 116, 350, 462, 164, 34, 176, 166, 0.72);
  _fillRect(image, 574, 92, 258, 386, 239, 118, 122, 0.74);
  _fillCircle(image, 720, 446, 126, 248, 248, 248, 0.68);
  _fillCircle(image, 250, 274, 96, 2, 48, 71, 0.48);
  _drawDiagonalStripes(image, 0, 0, width, height);

  return image;
}

void _fillRect(
  img.Image image,
  int left,
  int top,
  int width,
  int height,
  int r,
  int g,
  int b,
  double opacity,
) {
  final startX = math.max(0, left);
  final startY = math.max(0, top);
  final right = math.min(left + width, image.width);
  final bottom = math.min(top + height, image.height);
  for (var y = startY; y < bottom; y++) {
    for (var x = startX; x < right; x++) {
      _blendPixel(image, x, y, r, g, b, opacity);
    }
  }
}

void _fillCircle(
  img.Image image,
  int cx,
  int cy,
  int radius,
  int r,
  int g,
  int b,
  double opacity,
) {
  final r2 = radius * radius;
  final left = math.max(0, cx - radius);
  final right = math.min(image.width - 1, cx + radius);
  final top = math.max(0, cy - radius);
  final bottom = math.min(image.height - 1, cy + radius);

  for (var y = top; y <= bottom; y++) {
    for (var x = left; x <= right; x++) {
      final dx = x - cx;
      final dy = y - cy;
      if (dx * dx + dy * dy <= r2) {
        _blendPixel(image, x, y, r, g, b, opacity);
      }
    }
  }
}

void _drawDiagonalStripes(
  img.Image image,
  int left,
  int top,
  int width,
  int height,
) {
  final startX = math.max(0, left);
  final startY = math.max(0, top);
  final right = math.min(left + width, image.width);
  final bottom = math.min(top + height, image.height);
  for (var y = startY; y < bottom; y++) {
    for (var x = startX; x < right; x++) {
      if (((x + y) ~/ 22).isEven) {
        _blendPixel(image, x, y, 255, 255, 255, 0.055);
      }
    }
  }
}

void _blendPixel(
  img.Image image,
  int x,
  int y,
  int r,
  int g,
  int b,
  double opacity,
) {
  final pixel = image.getPixel(x, y);
  final alpha = opacity.clamp(0, 1);
  final inverse = 1 - alpha;
  image.setPixelRgba(
    x,
    y,
    (pixel.r * inverse + r * alpha).round(),
    (pixel.g * inverse + g * alpha).round(),
    (pixel.b * inverse + b * alpha).round(),
    pixel.a,
  );
}
