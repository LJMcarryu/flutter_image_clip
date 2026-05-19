import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'decode_adapter.dart';
import 'exceptions.dart';
import 'models.dart';
import 'pipeline.dart';

export 'crop_transform.dart';
export 'decode_adapter.dart';
export 'exceptions.dart';
export 'models.dart';
export 'pipeline.dart';

part 'image_job.dart';
part 'image_operations.dart';
part 'sample_image.dart';
part 'session.dart';
part 'tasks.dart';

/// Performs image decoding and transformations on a background isolate.
class ImageProcessor {
  /// Creates an image processor.
  const ImageProcessor({
    this.processingSettings = const ImageClipProcessingSettings(),
    this.decodeAdapter,
  });

  /// Runtime guardrails used for decode and output processing.
  final ImageClipProcessingSettings processingSettings;

  /// Optional platform adapter used before Dart decoding starts.
  final ImageClipDecodeAdapter? decodeAdapter;

  /// Reads lightweight format and dimension metadata from encoded [bytes].
  ///
  /// This does not fully decode pixel data. It is useful for validating mobile
  /// camera or gallery input before starting a more expensive image task.
  ImageClipImageInfo probeBytes(Uint8List bytes) {
    return _probeEncodedImage(bytes);
  }

  /// Creates a generated sample image for demos and tests.
  Future<EditedImage> createSample({ImageClipTaskOptions? options}) {
    return createSampleTask(options: options).result;
  }

  /// Starts generating a sample image as a cancelable task.
  ImageClipTask<EditedImage> createSampleTask({ImageClipTaskOptions? options}) {
    return _start(<String, Object?>{
      'kind': 'sample',
      'label': 'Sample image',
    }, options: options);
  }

  /// Decodes encoded image [bytes] into a normalized PNG [EditedImage].
  Future<EditedImage> decodeBytes(
    Uint8List bytes, {
    required String label,
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    ImageClipTaskOptions? options,
  }) {
    return decodeBytesTask(
      bytes,
      label: label,
      decodeSettings: decodeSettings,
      options: options,
    ).result;
  }

  /// Starts decoding encoded image [bytes] as a cancelable task.
  ImageClipTask<EditedImage> decodeBytesTask(
    Uint8List bytes, {
    required String label,
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    ImageClipTaskOptions? options,
  }) {
    return processBytesTask(
      bytes,
      label: label,
      decodeSettings: decodeSettings,
      operationLabel: 'Decode',
      options: options,
    );
  }

  /// Decodes [bytes] into a preview image constrained by [targetLongSide].
  Future<EditedImage> decodePreviewBytes(
    Uint8List bytes, {
    required String label,
    required int targetLongSide,
    ImageClipTaskOptions? options,
  }) {
    return decodePreviewBytesTask(
      bytes,
      label: label,
      targetLongSide: targetLongSide,
      options: options,
    ).result;
  }

  /// Starts decoding [bytes] into a preview image constrained by [targetLongSide].
  ImageClipTask<EditedImage> decodePreviewBytesTask(
    Uint8List bytes, {
    required String label,
    required int targetLongSide,
    ImageClipTaskOptions? options,
  }) {
    return decodeBytesTask(
      bytes,
      label: label,
      decodeSettings: ImageClipDecodeSettings.preview(
        targetLongSide: targetLongSide,
      ),
      options: options,
    );
  }

  /// Reads lightweight format and dimension metadata from an image file.
  Future<ImageClipImageInfo> probeFile(String path) async {
    return probeBytes(await File(path).readAsBytes());
  }

  /// Decodes an image file in a background isolate.
  Future<EditedImage> decodeFile(
    String path, {
    String? label,
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    ImageClipTaskOptions? options,
  }) {
    return decodeFileTask(
      path,
      label: label,
      decodeSettings: decodeSettings,
      options: options,
    ).result;
  }

  /// Starts decoding an image file as a cancelable background task.
  ImageClipTask<EditedImage> decodeFileTask(
    String path, {
    String? label,
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    ImageClipTaskOptions? options,
  }) {
    return processFileTask(
      path,
      label: label,
      decodeSettings: decodeSettings,
      operationLabel: 'Decode',
      options: options,
    );
  }

  /// Runs [pipeline] as a single background image job.
  ///
  /// Unlike chaining single-operation methods, a pipeline decodes the source
  /// image once, applies all steps in order, and encodes only the final result.
  Future<EditedImage> processPipeline(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(pipeline, options: options).result;
  }

  /// Starts [pipeline] as a cancelable background image task.
  ImageClipTask<EditedImage> processPipelineTask(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    if (pipeline.bytes != null &&
        decodeAdapter != null &&
        pipeline.decodeSettings.usePlatformAdapter) {
      return _processBytesPipelineTask(pipeline, options: options);
    }
    return _runPipelineTask(pipeline, options: options);
  }

  /// Decodes [bytes], applies [steps], and encodes the final result.
  Future<EditedImage> processBytes(
    Uint8List bytes, {
    required String label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return processBytesTask(
      bytes,
      label: label,
      steps: steps,
      outputSettings: outputSettings,
      decodeSettings: decodeSettings,
      operationLabel: operationLabel,
      options: options,
    ).result;
  }

  /// Starts decoding [bytes] and applying [steps] as a cancelable task.
  ImageClipTask<EditedImage> processBytesTask(
    Uint8List bytes, {
    required String label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    final pipeline = ImageClipPipeline.decode(
      bytes: bytes,
      label: label,
      steps: steps,
      outputSettings: outputSettings,
      decodeSettings: decodeSettings,
      operationLabel: operationLabel,
    );
    return processPipelineTask(pipeline, options: options);
  }

  /// Decodes an image file, applies [steps], and encodes the final result.
  Future<EditedImage> processFile(
    String path, {
    String? label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return processFileTask(
      path,
      label: label,
      steps: steps,
      outputSettings: outputSettings,
      decodeSettings: decodeSettings,
      operationLabel: operationLabel,
      options: options,
    ).result;
  }

  /// Starts a file-backed processing task.
  ///
  /// The source file is read inside the worker isolate, avoiding an additional
  /// source-byte copy on the UI isolate for large local gallery files.
  ImageClipTask<EditedImage> processFileTask(
    String path, {
    String? label,
    List<ImageClipPipelineStep> steps = const <ImageClipPipelineStep>[],
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    String? operationLabel,
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.decodeFile(
        path: path,
        label: label ?? _fileLabel(path),
        steps: steps,
        outputSettings: outputSettings,
        decodeSettings: decodeSettings,
        operationLabel: operationLabel,
      ),
      options: options,
    );
  }

  /// Writes [image] bytes to [path], creating parent directories if needed.
  Future<File> writeImageToFile(EditedImage image, String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(image.bytes, flush: true);
  }

  ImageClipTask<EditedImage> _processBytesPipelineTask(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    final bytes = pipeline.bytes;
    if (bytes == null ||
        decodeAdapter == null ||
        !pipeline.decodeSettings.usePlatformAdapter) {
      return processPipelineTask(pipeline, options: options);
    }

    final effectiveOptions = options ?? const ImageClipTaskOptions();
    late final ImageClipTask<EditedImage> task;
    ImageClipTask<EditedImage>? pipelineTask;
    StreamSubscription<ImageClipTaskProgress>? progressSubscription;

    Future<EditedImage> run() async {
      task._emitProgress(
        const ImageClipTaskProgress(
          stage: ImageClipTaskProgressStage.decoding,
          completedSteps: 0,
          totalSteps: 0,
          message: 'Normalizing image',
        ),
      );
      final normalized = await _normalizedPipeline(pipeline);
      if (task.isCanceled) {
        throw const ImageClipTaskCanceledException();
      }
      pipelineTask = _runPipelineTask(normalized);
      progressSubscription = pipelineTask!.progress.listen(task._emitProgress);
      return pipelineTask!.result;
    }

    task = ImageClipTask<EditedImage>._manual(
      effectiveOptions,
      onCancel: () {
        pipelineTask?.cancel();
        unawaited(progressSubscription?.cancel());
      },
    );
    task._emitProgress(
      const ImageClipTaskProgress(
        stage: ImageClipTaskProgressStage.queued,
        completedSteps: 0,
        totalSteps: 0,
        message: 'Queued',
      ),
    );
    task._bindFuture(
      Future<EditedImage>(
        run,
      ).whenComplete(() => progressSubscription?.cancel()),
    );
    return task;
  }

  ImageClipTask<EditedImage> _runPipelineTask(
    ImageClipPipeline pipeline, {
    ImageClipTaskOptions? options,
  }) {
    return _start(<String, Object?>{
      'kind': 'pipeline',
      'pipeline': pipeline.toMap(),
    }, options: options);
  }

  Future<ImageClipPipeline> _normalizedPipeline(
    ImageClipPipeline pipeline,
  ) async {
    final adapter = decodeAdapter;
    final bytes = pipeline.bytes;
    if (adapter == null || bytes == null) {
      return pipeline;
    }
    final info = probeBytes(bytes);
    if (!adapter.supportsDecode(info, pipeline.decodeSettings)) {
      return pipeline;
    }
    final result = await adapter.decode(
      bytes,
      info: info,
      label: pipeline.label,
      settings: pipeline.decodeSettings,
    );
    if (result == null) {
      return pipeline;
    }
    return ImageClipPipeline.decode(
      bytes: result.bytes,
      label: pipeline.label,
      steps: pipeline.steps,
      outputSettings: pipeline.outputSettings,
      decodeSettings: pipeline.decodeSettings,
      sourceWidth: result.sourceWidth,
      sourceHeight: result.sourceHeight,
      operationLabel: pipeline.operationLabel,
    );
  }

  /// Crops the center of [source] using relative [settings].
  Future<EditedImage> cropCenter(
    EditedImage source,
    CropSettings settings, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropCenter(settings),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Crop',
      ),
      options: options,
    );
  }

  /// Crops [source] to an explicit pixel [region].
  Future<EditedImage> cropRegion(
    EditedImage source,
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return cropRegionTask(
      source,
      region,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts cropping [source] to an explicit pixel [region].
  ImageClipTask<EditedImage> cropRegionTask(
    EditedImage source,
    CropRegion region, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.cropRegion(region),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Crop region',
      ),
      options: options,
    );
  }

  /// Rotates [source] clockwise by [degrees].
  Future<EditedImage> rotate(
    EditedImage source, {
    int degrees = 90,
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(
      source,
      degrees: degrees,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts rotating [source] clockwise by [degrees].
  ImageClipTask<EditedImage> rotateTask(
    EditedImage source, {
    int degrees = 90,
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.rotate(degrees: degrees),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Rotate',
      ),
      options: options,
    );
  }

  /// Rotates [source] clockwise by 90 degrees.
  Future<EditedImage> rotateRight(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return rotate(source, outputSettings: outputSettings, options: options);
  }

  /// Starts rotating [source] clockwise by 90 degrees.
  ImageClipTask<EditedImage> rotateRightTask(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return rotateTask(source, outputSettings: outputSettings, options: options);
  }

  /// Flips [source] around the vertical axis.
  Future<EditedImage> flipHorizontal(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return flipHorizontalTask(
      source,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts flipping [source] around the vertical axis.
  ImageClipTask<EditedImage> flipHorizontalTask(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipHorizontal(),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Flip horizontal',
      ),
      options: options,
    );
  }

  /// Flips [source] around the horizontal axis.
  Future<EditedImage> flipVertical(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return flipVerticalTask(
      source,
      outputSettings: outputSettings,
      options: options,
    ).result;
  }

  /// Starts flipping [source] around the horizontal axis.
  ImageClipTask<EditedImage> flipVerticalTask(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipelineTask(
      ImageClipPipeline.fromImage(
        source: source,
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.flipVertical(),
        ],
        outputSettings: outputSettings,
        operationLabel: 'Flip vertical',
      ),
      options: options,
    );
  }

  /// Resizes [source] so its longest side is [maxSide] pixels.
  Future<EditedImage> resizeLongSide(
    EditedImage source,
    int maxSide, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.resizeLongSide(maxSide),
        ],
        operationLabel: 'Resize',
      ),
      options: options,
    );
  }

  /// Applies brightness, contrast, and saturation multipliers to [source].
  Future<EditedImage> adjustColor(
    EditedImage source,
    ColorAdjustment adjustment, {
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        steps: <ImageClipPipelineStep>[
          ImageClipPipelineStep.adjustColor(adjustment),
        ],
        operationLabel: 'Adjust color',
      ),
      options: options,
    );
  }

  /// Re-encodes [source] using [outputSettings].
  Future<EditedImage> exportImage(
    EditedImage source, {
    ImageClipOutputSettings outputSettings =
        const ImageClipOutputSettings.png(),
    ImageClipTaskOptions? options,
  }) {
    return processPipeline(
      ImageClipPipeline.fromImage(
        source: source,
        outputSettings: outputSettings,
        operationLabel: 'Export ${outputSettings.format.name.toUpperCase()}',
      ),
      options: options,
    );
  }

  /// Re-encodes [source] as a PNG [EditedImage].
  Future<EditedImage> exportPng(
    EditedImage source, {
    ImageClipTaskOptions? options,
  }) {
    return exportImage(source, options: options);
  }

  /// Re-encodes [source] as a JPEG [EditedImage].
  Future<EditedImage> exportJpeg(
    EditedImage source, {
    int quality = 90,
    ImageClipTaskOptions? options,
  }) {
    return exportImage(
      source,
      outputSettings: ImageClipOutputSettings.jpeg(jpegQuality: quality),
      options: options,
    );
  }

  ImageClipTask<EditedImage> _start(
    Map<String, Object?> request, {
    ImageClipTaskOptions? options,
  }) {
    final payload = <String, Object?>{
      ...request,
      'processing': processingSettings.toMap(),
    };
    return ImageClipTask._start(payload, options: options);
  }
}

String _fileLabel(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

ImageClipImageInfo _probeEncodedImage(Uint8List bytes) {
  if (_isPng(bytes)) {
    if (bytes.length >= 24 && _matchesAscii(bytes, 12, 'IHDR')) {
      return _imageInfo(
        ImageClipEncodedFormat.png,
        _uint32be(bytes, 16),
        _uint32be(bytes, 20),
      );
    }
    return const ImageClipImageInfo(format: ImageClipEncodedFormat.png);
  }

  if (_isJpeg(bytes)) {
    return _probeJpeg(bytes);
  }

  if (_isGif(bytes)) {
    if (bytes.length >= 10) {
      return _imageInfo(
        ImageClipEncodedFormat.gif,
        _uint16le(bytes, 6),
        _uint16le(bytes, 8),
      );
    }
    return const ImageClipImageInfo(format: ImageClipEncodedFormat.gif);
  }

  if (_isWebP(bytes)) {
    return _probeWebP(bytes);
  }

  final isoFormat = _probeIsoBaseMediaImage(bytes);
  if (isoFormat != null) {
    return ImageClipImageInfo(format: isoFormat);
  }

  return const ImageClipImageInfo(format: ImageClipEncodedFormat.unknown);
}

ImageClipImageInfo _probeJpeg(Uint8List bytes) {
  var offset = 2;
  while (offset < bytes.length) {
    while (offset < bytes.length && bytes[offset] != 0xFF) {
      offset++;
    }
    while (offset < bytes.length && bytes[offset] == 0xFF) {
      offset++;
    }
    if (offset >= bytes.length) {
      break;
    }

    final marker = bytes[offset++];
    if (marker == 0xD9 || marker == 0xDA) {
      break;
    }
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      continue;
    }
    if (offset + 2 > bytes.length) {
      break;
    }

    final segmentLength = _uint16be(bytes, offset);
    if (segmentLength < 2) {
      break;
    }
    final segmentStart = offset + 2;
    final nextOffset = offset + segmentLength;
    if (_isJpegSofMarker(marker) && segmentStart + 5 <= bytes.length) {
      return _imageInfo(
        ImageClipEncodedFormat.jpeg,
        _uint16be(bytes, segmentStart + 3),
        _uint16be(bytes, segmentStart + 1),
      );
    }
    if (nextOffset <= offset) {
      break;
    }
    offset = nextOffset;
  }

  return const ImageClipImageInfo(format: ImageClipEncodedFormat.jpeg);
}

ImageClipImageInfo _probeWebP(Uint8List bytes) {
  if (bytes.length < 16) {
    return const ImageClipImageInfo(format: ImageClipEncodedFormat.webp);
  }

  final chunk = String.fromCharCodes(bytes.sublist(12, 16));
  if (chunk == 'VP8X' && bytes.length >= 30) {
    final width = 1 + _uint24le(bytes, 24);
    final height = 1 + _uint24le(bytes, 27);
    return _imageInfo(ImageClipEncodedFormat.webp, width, height);
  }
  if (chunk == 'VP8 ' && bytes.length >= 30) {
    final width = _uint16le(bytes, 26) & 0x3FFF;
    final height = _uint16le(bytes, 28) & 0x3FFF;
    return _imageInfo(ImageClipEncodedFormat.webp, width, height);
  }
  if (chunk == 'VP8L' && bytes.length >= 25 && bytes[20] == 0x2F) {
    final bits =
        bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
    final width = 1 + (bits & 0x3FFF);
    final height = 1 + ((bits >> 14) & 0x3FFF);
    return _imageInfo(ImageClipEncodedFormat.webp, width, height);
  }

  return const ImageClipImageInfo(format: ImageClipEncodedFormat.webp);
}

ImageClipImageInfo _imageInfo(
  ImageClipEncodedFormat format,
  int width,
  int height,
) {
  if (width <= 0 || height <= 0) {
    return ImageClipImageInfo(format: format);
  }
  return ImageClipImageInfo(format: format, width: width, height: height);
}

bool _isPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A;
}

bool _isJpeg(Uint8List bytes) {
  return bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
}

bool _isGif(Uint8List bytes) {
  return bytes.length >= 6 &&
      (_matchesAscii(bytes, 0, 'GIF87a') || _matchesAscii(bytes, 0, 'GIF89a'));
}

bool _isWebP(Uint8List bytes) {
  return bytes.length >= 12 &&
      _matchesAscii(bytes, 0, 'RIFF') &&
      _matchesAscii(bytes, 8, 'WEBP');
}

ImageClipEncodedFormat? _probeIsoBaseMediaImage(Uint8List bytes) {
  if (bytes.length < 16 || !_matchesAscii(bytes, 4, 'ftyp')) {
    return null;
  }
  final brands = <String>{_asciiOf(bytes, 8, 4)};
  for (var offset = 16; offset + 4 <= bytes.length; offset += 4) {
    brands.add(_asciiOf(bytes, offset, 4));
  }
  const heicBrands = <String>{
    'heic',
    'heix',
    'hevc',
    'hevx',
    'heim',
    'heis',
    'hevm',
    'hevs',
  };
  if (brands.any(heicBrands.contains)) {
    return ImageClipEncodedFormat.heic;
  }
  const avifBrands = <String>{'avif', 'avis'};
  if (brands.any(avifBrands.contains)) {
    return null;
  }
  const heifBrands = <String>{'heif', 'mif1', 'msf1'};
  if (brands.any(heifBrands.contains)) {
    return ImageClipEncodedFormat.heif;
  }
  return null;
}

bool _matchesAscii(Uint8List bytes, int offset, String value) {
  if (offset < 0 || offset + value.length > bytes.length) {
    return false;
  }
  for (var index = 0; index < value.length; index++) {
    if (bytes[offset + index] != value.codeUnitAt(index)) {
      return false;
    }
  }
  return true;
}

String _asciiOf(Uint8List bytes, int offset, int length) {
  if (offset < 0 || offset + length > bytes.length) {
    return '';
  }
  return String.fromCharCodes(bytes.sublist(offset, offset + length));
}

bool _isJpegSofMarker(int marker) {
  return marker >= 0xC0 &&
      marker <= 0xCF &&
      marker != 0xC4 &&
      marker != 0xC8 &&
      marker != 0xCC;
}

int _uint16be(Uint8List bytes, int offset) {
  return (bytes[offset] << 8) | bytes[offset + 1];
}

int _uint16le(Uint8List bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _uint24le(Uint8List bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
}

int _uint32be(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

Object _bytesToIsolateMessage(Uint8List bytes) {
  return TransferableTypedData.fromList(<Uint8List>[bytes]);
}

Uint8List _bytesFromIsolateMessage(Object? value) {
  if (value is TransferableTypedData) {
    return value.materialize().asUint8List();
  }
  if (value is Uint8List) {
    return value;
  }
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  throw const ImageClipProcessingException('Image byte payload is missing');
}

Map<String, Object?> _prepareRequestForIsolate(Map<String, Object?> request) {
  return Map<String, Object?>.fromEntries(
    request.entries.map(
      (entry) => MapEntry(entry.key, _prepareValueForIsolate(entry.value)),
    ),
  );
}

Object? _prepareValueForIsolate(Object? value) {
  if (value is Uint8List) {
    return _bytesToIsolateMessage(value);
  }
  if (value is Map) {
    return Map<Object?, Object?>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(entry.key, _prepareValueForIsolate(entry.value)),
      ),
    );
  }
  if (value is List) {
    return <Object?>[for (final item in value) _prepareValueForIsolate(item)];
  }
  return value;
}

Map<String, Object?> _editedImageResultFromMessage(Object? value) {
  final map = Map<String, Object?>.from(value! as Map);
  map['bytes'] = _bytesFromIsolateMessage(map['bytes']);
  return map;
}
