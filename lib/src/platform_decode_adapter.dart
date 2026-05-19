import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'image_processing/image_processor.dart';

const _decodeChannel = MethodChannel('flutter_image_clip/decode');

/// Decode adapter backed by the Android/iOS platform implementation.
///
/// This adapter can normalize platform-only formats such as HEIC/HEIF and can
/// ask the native side to perform sampled preview decode before the Dart image
/// pipeline receives the bytes.
class ImageClipPlatformDecodeAdapter extends ImageClipDecodeAdapter {
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
      throw ImageClipDecodeException(
        'Platform image decode failed: ${error.message ?? error.code}',
        cause: error,
      );
    }
  }
}

int? _intOf(Object? value) {
  if (value is num) {
    return value.round();
  }
  return null;
}
