import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class EditedImage {
  const EditedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.label,
    required this.operation,
    required this.elapsedMs,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final String label;
  final String operation;
  final int elapsedMs;

  String get dimensionsLabel => '${width}x$height';

  String get bytesLabel => _formatBytes(bytes.length);

  Map<String, Object?> toMap() => <String, Object?>{
    'bytes': bytes,
    'width': width,
    'height': height,
    'label': label,
    'operation': operation,
    'elapsedMs': elapsedMs,
  };

  static EditedImage fromMap(Map<String, Object?> map) {
    return EditedImage(
      bytes: map['bytes']! as Uint8List,
      width: map['width']! as int,
      height: map['height']! as int,
      label: map['label']! as String,
      operation: map['operation']! as String,
      elapsedMs: map['elapsedMs']! as int,
    );
  }
}

class CropSettings {
  const CropSettings({
    required this.widthRatio,
    required this.heightRatio,
    required this.cornerRadius,
  });

  final double widthRatio;
  final double heightRatio;
  final double cornerRadius;

  Map<String, Object?> toMap() => <String, Object?>{
    'widthRatio': widthRatio,
    'heightRatio': heightRatio,
    'cornerRadius': cornerRadius,
  };
}

class CropRegion {
  const CropRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.cornerRadius,
  });

  final int x;
  final int y;
  final int width;
  final int height;
  final double cornerRadius;

  Map<String, Object?> toMap() => <String, Object?>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'cornerRadius': cornerRadius,
  };
}

class ColorAdjustment {
  const ColorAdjustment({
    required this.brightness,
    required this.contrast,
    required this.saturation,
  });

  final double brightness;
  final double contrast;
  final double saturation;

  Map<String, Object?> toMap() => <String, Object?>{
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
  };
}

class ImageProcessor {
  Future<EditedImage> createSample() =>
      _run(<String, Object?>{'kind': 'sample', 'label': '内置示例图'});

  Future<EditedImage> decodeBytes(Uint8List bytes, {required String label}) {
    return _run(<String, Object?>{
      'kind': 'decode',
      'bytes': bytes,
      'label': label,
    });
  }

  Future<EditedImage> cropCenter(EditedImage source, CropSettings settings) {
    return _run(<String, Object?>{
      'kind': 'crop',
      'source': source.toMap(),
      ...settings.toMap(),
    });
  }

  Future<EditedImage> cropRegion(EditedImage source, CropRegion region) {
    return _run(<String, Object?>{
      'kind': 'cropRegion',
      'source': source.toMap(),
      ...region.toMap(),
    });
  }

  Future<EditedImage> rotate(EditedImage source, {int degrees = 90}) {
    return _run(<String, Object?>{
      'kind': 'rotate',
      'source': source.toMap(),
      'angle': degrees,
    });
  }

  Future<EditedImage> rotateRight(EditedImage source) => rotate(source);

  Future<EditedImage> flipHorizontal(EditedImage source) {
    return _run(<String, Object?>{
      'kind': 'flipHorizontal',
      'source': source.toMap(),
    });
  }

  Future<EditedImage> flipVertical(EditedImage source) {
    return _run(<String, Object?>{
      'kind': 'flipVertical',
      'source': source.toMap(),
    });
  }

  Future<EditedImage> resizeLongSide(EditedImage source, int maxSide) {
    return _run(<String, Object?>{
      'kind': 'resize',
      'source': source.toMap(),
      'maxSide': maxSide,
    });
  }

  Future<EditedImage> adjustColor(
    EditedImage source,
    ColorAdjustment adjustment,
  ) {
    return _run(<String, Object?>{
      'kind': 'adjust',
      'source': source.toMap(),
      ...adjustment.toMap(),
    });
  }

  Future<EditedImage> exportPng(EditedImage source) {
    return _run(<String, Object?>{
      'kind': 'exportPng',
      'source': source.toMap(),
    });
  }

  Future<EditedImage> _run(Map<String, Object?> request) async {
    final result = await compute(
      _runImageJob,
      request,
      debugLabel: 'image-job',
    );
    return EditedImage.fromMap(result);
  }
}

Map<String, Object?> _runImageJob(Map<String, Object?> request) {
  final stopwatch = Stopwatch()..start();
  final kind = request['kind']! as String;
  final label =
      (request['label'] as String?) ?? _sourceMap(request)['label']! as String;

  late img.Image image;
  late String operation;

  switch (kind) {
    case 'sample':
      image = _createSampleImage();
      operation = '生成示例';
      break;
    case 'decode':
      image = _decode(request['bytes']! as Uint8List);
      operation = '解码';
      break;
    case 'crop':
      image = _decodeSource(request);
      image = _cropCenter(
        image,
        widthRatio: _doubleOf(request['widthRatio'], fallback: 0.75),
        heightRatio: _doubleOf(request['heightRatio'], fallback: 0.75),
        cornerRadius: _doubleOf(request['cornerRadius'], fallback: 0),
      );
      operation = '裁剪';
      break;
    case 'cropRegion':
      image = _decodeSource(request);
      image = _cropRegion(
        image,
        x: _intOf(request['x'], fallback: 0),
        y: _intOf(request['y'], fallback: 0),
        width: _intOf(request['width'], fallback: image.width),
        height: _intOf(request['height'], fallback: image.height),
        cornerRadius: _doubleOf(request['cornerRadius'], fallback: 0),
      );
      operation = '手势裁剪';
      break;
    case 'rotate':
      image = _decodeSource(request);
      image = img.copyRotate(
        image,
        angle: _intOf(request['angle'], fallback: 90),
        interpolation: img.Interpolation.linear,
      );
      operation = '旋转';
      break;
    case 'flipHorizontal':
      image = _decodeSource(request);
      image = img.flipHorizontal(image);
      operation = '水平翻转';
      break;
    case 'flipVertical':
      image = _decodeSource(request);
      image = img.flipVertical(image);
      operation = '垂直翻转';
      break;
    case 'resize':
      image = _decodeSource(request);
      image = _resizeLongSide(
        image,
        _intOf(request['maxSide'], fallback: 1080),
      );
      operation = '缩放';
      break;
    case 'adjust':
      image = _decodeSource(request);
      image = img.adjustColor(
        image,
        brightness: _doubleOf(request['brightness'], fallback: 1),
        contrast: _doubleOf(request['contrast'], fallback: 1),
        saturation: _doubleOf(request['saturation'], fallback: 1),
      );
      operation = '调色';
      break;
    case 'exportPng':
      image = _decodeSource(request);
      operation = '导出 PNG';
      break;
    default:
      throw UnsupportedError('未知图片处理任务：$kind');
  }

  final encoded = Uint8List.fromList(img.encodePng(image, level: 6));
  stopwatch.stop();

  return <String, Object?>{
    'bytes': encoded,
    'width': image.width,
    'height': image.height,
    'label': label,
    'operation': operation,
    'elapsedMs': stopwatch.elapsedMilliseconds,
  };
}

img.Image _decodeSource(Map<String, Object?> request) {
  final source = _sourceMap(request);
  return _decode(source['bytes']! as Uint8List);
}

Map<Object?, Object?> _sourceMap(Map<String, Object?> request) {
  return Map<Object?, Object?>.from(request['source']! as Map);
}

img.Image _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('无法识别图片格式');
  }
  return decoded.convert(numChannels: 4);
}

img.Image _cropCenter(
  img.Image source, {
  required double widthRatio,
  required double heightRatio,
  required double cornerRadius,
}) {
  final widthScale = widthRatio.clamp(0.1, 1.0).toDouble();
  final heightScale = heightRatio.clamp(0.1, 1.0).toDouble();
  final cropWidth = (source.width * widthScale)
      .round()
      .clamp(1, source.width)
      .toInt();
  final cropHeight = (source.height * heightScale)
      .round()
      .clamp(1, source.height)
      .toInt();
  final x = ((source.width - cropWidth) / 2).round();
  final y = ((source.height - cropHeight) / 2).round();
  final radius = cornerRadius.clamp(0, math.min(cropWidth, cropHeight) / 2);

  return img.copyCrop(
    source,
    x: x,
    y: y,
    width: cropWidth,
    height: cropHeight,
    radius: radius,
  );
}

img.Image _cropRegion(
  img.Image source, {
  required int x,
  required int y,
  required int width,
  required int height,
  required double cornerRadius,
}) {
  final safeX = x.clamp(0, source.width - 1).toInt();
  final safeY = y.clamp(0, source.height - 1).toInt();
  final safeWidth = width.clamp(1, source.width - safeX).toInt();
  final safeHeight = height.clamp(1, source.height - safeY).toInt();
  final radius = cornerRadius.clamp(0, math.min(safeWidth, safeHeight) / 2);

  return img.copyCrop(
    source,
    x: safeX,
    y: safeY,
    width: safeWidth,
    height: safeHeight,
    radius: radius,
  );
}

img.Image _resizeLongSide(img.Image source, int maxSide) {
  final safeMaxSide = maxSide.clamp(128, 4096).toInt();
  final currentLongSide = math.max(source.width, source.height);
  if (currentLongSide == safeMaxSide) {
    return img.Image.from(source);
  }

  if (source.width >= source.height) {
    return img.copyResize(
      source,
      width: safeMaxSide,
      interpolation: img.Interpolation.linear,
    );
  }

  return img.copyResize(
    source,
    height: safeMaxSide,
    interpolation: img.Interpolation.linear,
  );
}

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

double _doubleOf(Object? value, {required double fallback}) {
  if (value is num) {
    return value.toDouble();
  }
  return fallback;
}

int _intOf(Object? value, {required int fallback}) {
  if (value is num) {
    return value.round();
  }
  return fallback;
}

String _formatBytes(int value) {
  if (value < 1024) {
    return '$value B';
  }
  if (value < 1024 * 1024) {
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
  return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
}
