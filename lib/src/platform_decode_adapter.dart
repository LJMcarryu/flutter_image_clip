import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'image_processing/image_processor.dart';

const _decodeChannel = MethodChannel('flutter_image_clip/decode');

/// Decode adapter backed by the Android/iOS platform implementation.
///
/// This adapter can normalize platform-only formats such as HEIC/HEIF and can
/// ask the native side to perform sampled preview decode before the Dart image
/// pipeline receives the bytes.
class ImageClipPlatformDecodeAdapter extends ImageClipDecodeAdapter
    implements ImageClipFileProcessingAdapter {
  /// Creates a platform decode adapter.
  const ImageClipPlatformDecodeAdapter({this.channel = _decodeChannel});

  /// Method channel used to talk to the platform implementation.
  final MethodChannel channel;

  @override
  bool supportsDecode(
    ImageClipImageInfo info,
    ImageClipDecodeSettings settings,
  ) {
    if (!settings.usePlatformAdapter) {
      return false;
    }
    if (!info.canDecodeWithDart) {
      return true;
    }
    final targetLongSide = settings.targetLongSide;
    final width = info.width;
    final height = info.height;
    if (targetLongSide == null || width == null || height == null) {
      return false;
    }
    return math.max(width, height) > targetLongSide;
  }

  @override
  Future<ImageClipDecodeAdapterResult?> decode(
    Uint8List bytes, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  }) async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'decode',
        <String, Object?>{
          'bytes': bytes,
          'label': label,
          'targetLongSide': settings.targetLongSide,
        },
      );
      if (result == null) {
        return null;
      }
      final normalizedBytes = result['bytes'];
      if (normalizedBytes is! Uint8List) {
        return null;
      }
      return ImageClipDecodeAdapterResult(
        bytes: normalizedBytes,
        sourceWidth: _intOf(result['sourceWidth']),
        sourceHeight: _intOf(result['sourceHeight']),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw _platformExceptionFor(error, info);
    }
  }

  @override
  Future<ImageClipDecodeAdapterResult?> decodeFile(
    String path, {
    required ImageClipImageInfo info,
    required String label,
    required ImageClipDecodeSettings settings,
  }) async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'decode',
        <String, Object?>{
          'path': path,
          'label': label,
          'targetLongSide': settings.targetLongSide,
        },
      );
      if (result == null) {
        return null;
      }
      final normalizedBytes = result['bytes'];
      if (normalizedBytes is! Uint8List) {
        return null;
      }
      return ImageClipDecodeAdapterResult(
        bytes: normalizedBytes,
        sourceWidth: _intOf(result['sourceWidth']),
        sourceHeight: _intOf(result['sourceHeight']),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw _platformExceptionFor(error, info);
    }
  }

  @override
  Future<ImageClipFileProcessingAdapterResult?> cropFile(
    String path, {
    required CropRegion region,
    required ImageClipCropTransform transform,
    required ImageClipOutputSettings outputSettings,
    required ImageClipProcessingSettings processingSettings,
    required String label,
  }) async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'cropFile',
        <String, Object?>{
          'path': path,
          'label': label,
          'region': region.toMap(),
          'transform': <String, Object?>{
            'rotationDegrees': transform.normalizedRotation,
            'flipHorizontal': transform.flipHorizontal,
            'flipVertical': transform.flipVertical,
          },
          'output': outputSettings.toMap(),
          'processing': processingSettings.toMap(),
        },
      );
      if (result == null) {
        return null;
      }
      final bytes = result['bytes'];
      if (bytes is! Uint8List) {
        return null;
      }
      final width = _intOf(result['width']);
      final height = _intOf(result['height']);
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return ImageClipFileProcessingAdapterResult(
        bytes: bytes,
        width: width,
        height: height,
        format: _outputFormatOf(result['format']),
        sourceWidth: _intOf(result['sourceWidth']),
        sourceHeight: _intOf(result['sourceHeight']),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      throw _fileProcessingExceptionFor(error);
    }
  }
}

ImageClipException _platformExceptionFor(
  PlatformException error,
  ImageClipImageInfo info,
) {
  final message = error.message ?? 'Platform image decode failed';
  return switch (error.code) {
    'unsupported_format' => ImageClipUnsupportedFormatException(
      message,
      format: info.format.name,
    ),
    'invalid_args' => ImageClipPlatformException(message, cause: error),
    'platform_unavailable' => ImageClipPlatformException(message, cause: error),
    'encode_failed' => ImageClipDecodeException(message, cause: error),
    'decode_failed' => ImageClipDecodeException(message, cause: error),
    _ => ImageClipDecodeException(
      'Platform image decode failed: $message',
      cause: error,
    ),
  };
}

int? _intOf(Object? value) {
  if (value is num) {
    return value.round();
  }
  return null;
}

ImageClipOutputFormat _outputFormatOf(Object? value) {
  return value == ImageClipOutputFormat.jpeg.name
      ? ImageClipOutputFormat.jpeg
      : ImageClipOutputFormat.png;
}

ImageClipException _fileProcessingExceptionFor(PlatformException error) {
  final message = error.message ?? 'Platform image processing failed';
  if (error.code == 'image_too_large') {
    final details = error.details;
    if (details is Map) {
      return ImageClipImageTooLargeException(
        message,
        width: _intOf(details['width']) ?? 0,
        height: _intOf(details['height']) ?? 0,
        maxPixels: _intOf(details['maxPixels']) ?? 0,
      );
    }
  }
  return switch (error.code) {
    'invalid_args' => ImageClipInvalidCropRegionException(message),
    'unsupported_format' => ImageClipUnsupportedFormatException(
      message,
      format: 'unknown',
    ),
    'encode_failed' => ImageClipDecodeException(message, cause: error),
    'decode_failed' => ImageClipDecodeException(message, cause: error),
    _ => ImageClipProcessingException(
      'Platform image processing failed: $message',
      cause: error,
    ),
  };
}
