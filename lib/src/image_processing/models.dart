import 'dart:typed_data';

import 'exceptions.dart';

/// Encoded output formats supported by the image processing APIs.
enum ImageClipOutputFormat {
  /// Portable Network Graphics output with lossless compression.
  png,

  /// JPEG output with configurable lossy compression quality.
  jpeg,
}

/// Encoded image container formats recognized before full decoding.
enum ImageClipEncodedFormat {
  /// PNG input bytes.
  png,

  /// JPEG input bytes.
  jpeg,

  /// GIF input bytes.
  gif,

  /// WebP input bytes.
  webp,

  /// HEIC input bytes.
  heic,

  /// HEIF input bytes.
  heif,

  /// The input header is not recognized.
  unknown,
}

/// Lightweight information parsed from encoded image bytes.
///
/// This is intended for early validation and diagnostics. A value can have a
/// recognized [format] but no dimensions when the header is incomplete.
class ImageClipImageInfo {
  /// Creates encoded image information.
  const ImageClipImageInfo({required this.format, this.width, this.height})
    : assert((width == null) == (height == null));

  /// Encoded container format recognized from the byte header.
  final ImageClipEncodedFormat format;

  /// Encoded image width in pixels, when available.
  final int? width;

  /// Encoded image height in pixels, when available.
  final int? height;

  /// Whether both [width] and [height] are available.
  bool get hasDimensions => width != null && height != null;

  /// Whether the pure Dart decoder can handle this format directly.
  bool get canDecodeWithDart {
    return switch (format) {
      ImageClipEncodedFormat.png ||
      ImageClipEncodedFormat.jpeg ||
      ImageClipEncodedFormat.gif ||
      ImageClipEncodedFormat.webp ||
      ImageClipEncodedFormat.unknown => true,
      ImageClipEncodedFormat.heic || ImageClipEncodedFormat.heif => false,
    };
  }

  /// Pixel count when dimensions are available.
  int? get pixelCount {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null) {
      return null;
    }
    return width * height;
  }

  /// Image dimensions formatted as `widthxheight`, or `unknown`.
  String get dimensionsLabel {
    final width = this.width;
    final height = this.height;
    if (width == null || height == null) {
      return 'unknown';
    }
    return '${width}x$height';
  }

  @override
  String toString() {
    return 'ImageClipImageInfo('
        'format: ${format.name}, '
        'dimensions: $dimensionsLabel'
        ')';
  }
}

/// Runtime guardrails for decoding and writing image pixels.
class ImageClipProcessingSettings {
  /// Creates processing settings.
  const ImageClipProcessingSettings({
    this.maxInputPixels = 48000000,
    this.maxOutputPixels = 16000000,
    this.autoDownscale = true,
  });

  /// Creates settings without input or output pixel limits.
  const ImageClipProcessingSettings.unrestricted()
    : maxInputPixels = null,
      maxOutputPixels = null,
      autoDownscale = false;

  /// Maximum decoded input pixels before processing starts.
  ///
  /// Set to null to allow any input size.
  final int? maxInputPixels;

  /// Maximum output pixels after processing.
  ///
  /// When [autoDownscale] is true, larger outputs are resized down. When false,
  /// larger outputs throw [ImageClipImageTooLargeException].
  final int? maxOutputPixels;

  /// Whether output images larger than [maxOutputPixels] should be resized.
  final bool autoDownscale;

  /// Converts these settings to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'maxInputPixels': maxInputPixels,
    'maxOutputPixels': maxOutputPixels,
    'autoDownscale': autoDownscale,
  };

  /// Creates settings from the map used by the background processor.
  static ImageClipProcessingSettings fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const ImageClipProcessingSettings();
    }
    return ImageClipProcessingSettings(
      maxInputPixels: _nullableIntOf(map['maxInputPixels']),
      maxOutputPixels: _nullableIntOf(map['maxOutputPixels']),
      autoDownscale: _boolOf(map['autoDownscale'], fallback: true),
    );
  }
}

/// Encoding options used when an image operation writes output bytes.
class ImageClipOutputSettings {
  /// Creates output encoding settings.
  const ImageClipOutputSettings({
    this.format = ImageClipOutputFormat.png,
    this.jpegQuality = 90,
    this.pngLevel = 6,
  });

  /// Creates lossless PNG output settings.
  const ImageClipOutputSettings.png({this.pngLevel = 6})
    : format = ImageClipOutputFormat.png,
      jpegQuality = 90;

  /// Creates JPEG output settings.
  const ImageClipOutputSettings.jpeg({this.jpegQuality = 90})
    : format = ImageClipOutputFormat.jpeg,
      pngLevel = 6;

  /// Encoded output format.
  final ImageClipOutputFormat format;

  /// JPEG quality from 1 to 100.
  final int jpegQuality;

  /// PNG compression level from 0 to 9.
  final int pngLevel;

  /// MIME type for [format].
  String get mimeType => switch (format) {
    ImageClipOutputFormat.png => 'image/png',
    ImageClipOutputFormat.jpeg => 'image/jpeg',
  };

  /// File extension for [format], without a leading dot.
  String get fileExtension => switch (format) {
    ImageClipOutputFormat.png => 'png',
    ImageClipOutputFormat.jpeg => 'jpg',
  };

  /// Converts these settings to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'format': format.name,
    'jpegQuality': jpegQuality,
    'pngLevel': pngLevel,
  };

  /// Creates settings from the map used by the background processor.
  static ImageClipOutputSettings fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return const ImageClipOutputSettings();
    }
    return ImageClipOutputSettings(
      format: _formatFromName(map['format'] as String?),
      jpegQuality: _intOf(map['jpegQuality'], fallback: 90),
      pngLevel: _intOf(map['pngLevel'], fallback: 6),
    );
  }
}

/// Describes an image generated or transformed by the image processing APIs.
class EditedImage {
  /// Creates an immutable image processing result.
  const EditedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.label,
    required this.operation,
    required this.elapsedMs,
    this.format = ImageClipOutputFormat.png,
  });

  /// Encoded bytes for the image.
  final Uint8List bytes;

  /// Width of the image in physical pixels.
  final int width;

  /// Height of the image in physical pixels.
  final int height;

  /// Human-readable image label preserved through processing operations.
  final String label;

  /// Human-readable name of the operation that produced this image.
  final String operation;

  /// Processing time in milliseconds.
  final int elapsedMs;

  /// Encoded output format for [bytes].
  final ImageClipOutputFormat format;

  /// MIME type for [format].
  String get mimeType => switch (format) {
    ImageClipOutputFormat.png => 'image/png',
    ImageClipOutputFormat.jpeg => 'image/jpeg',
  };

  /// File extension for [format], without a leading dot.
  String get fileExtension => switch (format) {
    ImageClipOutputFormat.png => 'png',
    ImageClipOutputFormat.jpeg => 'jpg',
  };

  /// Image dimensions formatted as `widthxheight`.
  String get dimensionsLabel => '${width}x$height';

  /// Encoded byte length formatted for display.
  String get bytesLabel => _formatBytes(bytes.length);

  /// Converts this result to a map that can be sent across Flutter isolates.
  Map<String, Object?> toMap() => <String, Object?>{
    'bytes': bytes,
    'width': width,
    'height': height,
    'label': label,
    'operation': operation,
    'elapsedMs': elapsedMs,
    'format': format.name,
  };

  /// Creates an [EditedImage] from the isolate-safe map returned by [toMap].
  static EditedImage fromMap(Map<String, Object?> map) {
    return EditedImage(
      bytes: map['bytes']! as Uint8List,
      width: map['width']! as int,
      height: map['height']! as int,
      label: map['label']! as String,
      operation: map['operation']! as String,
      elapsedMs: map['elapsedMs']! as int,
      format: _formatFromName(map['format'] as String?),
    );
  }
}

/// Relative crop settings used by center-crop operations.
class CropSettings {
  /// Creates center-crop settings with width, height, and corner radius values.
  const CropSettings({
    required this.widthRatio,
    required this.heightRatio,
    required this.cornerRadius,
  });

  /// Fraction of the source image width to keep, clamped between 0.1 and 1.0.
  final double widthRatio;

  /// Fraction of the source image height to keep, clamped between 0.1 and 1.0.
  final double heightRatio;

  /// Rounded corner radius in source-image pixels.
  final double cornerRadius;

  /// Converts these settings to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'widthRatio': widthRatio,
    'heightRatio': heightRatio,
    'cornerRadius': cornerRadius,
  };
}

/// Pixel crop rectangle used by explicit crop-region operations.
class CropRegion {
  /// Creates a crop rectangle in source-image pixel coordinates.
  const CropRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.cornerRadius,
  });

  /// Left edge of the crop rectangle in source-image pixels.
  final int x;

  /// Top edge of the crop rectangle in source-image pixels.
  final int y;

  /// Width of the crop rectangle in source-image pixels.
  final int width;

  /// Height of the crop rectangle in source-image pixels.
  final int height;

  /// Rounded corner radius in source-image pixels.
  final double cornerRadius;

  /// Converts this region to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'cornerRadius': cornerRadius,
  };
}

/// Multipliers used by color adjustment operations.
class ColorAdjustment {
  /// Creates color adjustment multipliers.
  const ColorAdjustment({
    required this.brightness,
    required this.contrast,
    required this.saturation,
  });

  /// Brightness multiplier passed to the image package.
  final double brightness;

  /// Contrast multiplier passed to the image package.
  final double contrast;

  /// Saturation multiplier passed to the image package.
  final double saturation;

  /// Converts these multipliers to the map used by the background processor.
  Map<String, Object?> toMap() => <String, Object?>{
    'brightness': brightness,
    'contrast': contrast,
    'saturation': saturation,
  };
}

ImageClipOutputFormat _formatFromName(String? name) {
  for (final format in ImageClipOutputFormat.values) {
    if (format.name == name) {
      return format;
    }
  }
  return ImageClipOutputFormat.png;
}

int _intOf(Object? value, {required int fallback}) {
  if (value is num) {
    return value.round();
  }
  return fallback;
}

int? _nullableIntOf(Object? value) {
  if (value is num) {
    return value.round();
  }
  return null;
}

bool _boolOf(Object? value, {required bool fallback}) {
  if (value is bool) {
    return value;
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
