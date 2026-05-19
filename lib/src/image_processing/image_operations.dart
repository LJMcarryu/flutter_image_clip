part of 'image_processor.dart';

img.Image _decode(Uint8List bytes, ImageClipProcessingSettings settings) {
  final info = _probeEncodedImage(bytes);
  _checkFormatSupport(info);
  _checkProbedInputPixelLimit(info, settings);

  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (error) {
    throw ImageClipDecodeException(
      'Unable to decode image bytes',
      cause: error,
    );
  }
  if (decoded == null) {
    throw const ImageClipDecodeException('Unsupported image format');
  }
  final oriented = img.bakeOrientation(decoded);
  _checkInputPixelLimit(oriented, settings);
  return oriented.convert(numChannels: 4);
}

void _checkFormatSupport(ImageClipImageInfo info) {
  if (info.canDecodeWithDart) {
    return;
  }
  throw ImageClipUnsupportedFormatException(
    '${info.format.name.toUpperCase()} images require platform conversion '
    'before they can be processed by the pure Dart decoder',
    format: info.format.name,
  );
}

void _checkProbedInputPixelLimit(
  ImageClipImageInfo info,
  ImageClipProcessingSettings settings,
) {
  final maxPixels = settings.maxInputPixels;
  final pixels = info.pixelCount;
  final width = info.width;
  final height = info.height;
  if (maxPixels == null || pixels == null || width == null || height == null) {
    return;
  }
  if (pixels > maxPixels) {
    throw ImageClipImageTooLargeException(
      'Input image header reports $pixels pixels, which exceeds the '
      'configured limit of $maxPixels pixels',
      width: width,
      height: height,
      maxPixels: maxPixels,
    );
  }
}

void _checkInputPixelLimit(
  img.Image image,
  ImageClipProcessingSettings settings,
) {
  final maxPixels = settings.maxInputPixels;
  if (maxPixels == null) {
    return;
  }
  final pixels = _pixelCount(image);
  if (pixels > maxPixels) {
    throw ImageClipImageTooLargeException(
      'Input image has $pixels pixels, which exceeds the configured limit of '
      '$maxPixels pixels',
      width: image.width,
      height: image.height,
      maxPixels: maxPixels,
    );
  }
}

img.Image _prepareOutputImage(
  img.Image image,
  ImageClipProcessingSettings settings,
) {
  final maxPixels = settings.maxOutputPixels;
  if (maxPixels == null) {
    return image;
  }

  final pixels = _pixelCount(image);
  if (pixels <= maxPixels) {
    return image;
  }

  if (!settings.autoDownscale) {
    throw ImageClipImageTooLargeException(
      'Output image has $pixels pixels, which exceeds the configured limit of '
      '$maxPixels pixels',
      width: image.width,
      height: image.height,
      maxPixels: maxPixels,
    );
  }

  final scale = math.sqrt(maxPixels / pixels);
  final targetWidth = math.max(1, (image.width * scale).floor());
  final targetHeight = math.max(1, (image.height * scale).floor());
  return img.copyResize(
    image,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );
}

int _pixelCount(img.Image image) => image.width * image.height;

Uint8List _encodeImage(img.Image image, ImageClipOutputSettings settings) {
  return switch (settings.format) {
    ImageClipOutputFormat.png => Uint8List.fromList(
      img.encodePng(image, level: settings.pngLevel.clamp(0, 9).toInt()),
    ),
    ImageClipOutputFormat.jpeg => Uint8List.fromList(
      img.encodeJpg(image, quality: settings.jpegQuality.clamp(1, 100).toInt()),
    ),
  };
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
  if (width <= 0 || height <= 0) {
    throw ImageClipInvalidCropRegionException(
      'Crop region width and height must be greater than zero',
    );
  }
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
