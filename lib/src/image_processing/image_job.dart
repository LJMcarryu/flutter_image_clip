part of 'image_processor.dart';

Map<String, Object?> _runImageJob(Map<String, Object?> request) {
  final stopwatch = Stopwatch()..start();
  final kind = request['kind']! as String;
  final processingSettings = ImageClipProcessingSettings.fromMap(
    request['processing'] == null
        ? null
        : Map<Object?, Object?>.from(request['processing']! as Map),
  );

  late img.Image image;
  late String label;
  late String operation;
  late ImageClipOutputSettings outputSettings;

  switch (kind) {
    case 'sample':
      image = _createSampleImage();
      label = (request['label'] as String?) ?? 'Sample image';
      operation = 'Create sample';
      outputSettings = const ImageClipOutputSettings.png();
      break;
    case 'pipeline':
      final pipeline = Map<Object?, Object?>.from(request['pipeline']! as Map);
      final result = _runPipeline(pipeline, processingSettings);
      image = result.image;
      label = result.label;
      operation = result.operation;
      outputSettings = result.outputSettings;
      break;
    default:
      throw ImageClipProcessingException(
        'Unsupported image processing task: $kind',
      );
  }

  image = _prepareOutputImage(image, processingSettings);
  final encoded = _encodeImage(image, outputSettings);
  stopwatch.stop();

  return <String, Object?>{
    'bytes': encoded,
    'width': image.width,
    'height': image.height,
    'label': label,
    'operation': operation,
    'elapsedMs': stopwatch.elapsedMilliseconds,
    'format': outputSettings.format.name,
  };
}

_PipelineJobResult _runPipeline(
  Map<Object?, Object?> pipeline,
  ImageClipProcessingSettings processingSettings,
) {
  final outputSettings = ImageClipOutputSettings.fromMap(
    pipeline['output'] == null
        ? null
        : Map<Object?, Object?>.from(pipeline['output']! as Map),
  );
  final source = pipeline['source'] == null
      ? null
      : Map<Object?, Object?>.from(pipeline['source']! as Map);
  final bytes = pipeline['bytes'] as Uint8List?;
  final label =
      (pipeline['label'] as String?) ??
      (source == null ? 'Image' : source['label']! as String);

  if (source == null && bytes == null) {
    throw const ImageClipProcessingException(
      'Image pipeline requires source image bytes',
    );
  }

  var image = _decode(
    source == null ? bytes! : source['bytes']! as Uint8List,
    processingSettings,
  );
  final stepMaps = (pipeline['steps'] as List<Object?>? ?? const <Object?>[])
      .map((step) => Map<Object?, Object?>.from(step! as Map))
      .toList(growable: false);

  for (final step in stepMaps) {
    image = _applyPipelineStep(image, step);
  }

  final operation =
      pipeline['operationLabel'] as String? ??
      _defaultPipelineOperationLabel(
        steps: stepMaps,
        startsFromEditedImage: source != null,
        outputSettings: outputSettings,
      );

  return _PipelineJobResult(
    image: image,
    label: label,
    operation: operation,
    outputSettings: outputSettings,
  );
}

img.Image _applyPipelineStep(img.Image image, Map<Object?, Object?> step) {
  final kind = step['kind']! as String;
  return switch (kind) {
    'cropCenter' => _cropCenter(
      image,
      widthRatio: _doubleOf(step['widthRatio'], fallback: 0.75),
      heightRatio: _doubleOf(step['heightRatio'], fallback: 0.75),
      cornerRadius: _doubleOf(step['cornerRadius'], fallback: 0),
    ),
    'cropRegion' => _cropRegion(
      image,
      x: _intOf(step['x'], fallback: 0),
      y: _intOf(step['y'], fallback: 0),
      width: _intOf(step['width'], fallback: image.width),
      height: _intOf(step['height'], fallback: image.height),
      cornerRadius: _doubleOf(step['cornerRadius'], fallback: 0),
    ),
    'rotate' => img.copyRotate(
      image,
      angle: _intOf(step['angle'], fallback: 90),
      interpolation: img.Interpolation.linear,
    ),
    'flipHorizontal' => img.flipHorizontal(image),
    'flipVertical' => img.flipVertical(image),
    'resizeLongSide' => _resizeLongSide(
      image,
      _intOf(step['maxSide'], fallback: 1080),
    ),
    'adjustColor' => img.adjustColor(
      image,
      brightness: _doubleOf(step['brightness'], fallback: 1),
      contrast: _doubleOf(step['contrast'], fallback: 1),
      saturation: _doubleOf(step['saturation'], fallback: 1),
    ),
    _ => throw ImageClipProcessingException(
      'Unsupported image pipeline step: $kind',
    ),
  };
}

String _defaultPipelineOperationLabel({
  required List<Map<Object?, Object?>> steps,
  required bool startsFromEditedImage,
  required ImageClipOutputSettings outputSettings,
}) {
  if (steps.isEmpty) {
    if (startsFromEditedImage) {
      return 'Export ${outputSettings.format.name.toUpperCase()}';
    }
    return 'Decode';
  }
  if (steps.length == 1) {
    return _pipelineStepOperationLabel(steps.single['kind']! as String);
  }
  return 'Pipeline';
}

String _pipelineStepOperationLabel(String kind) {
  return switch (kind) {
    'cropCenter' => 'Crop',
    'cropRegion' => 'Crop region',
    'rotate' => 'Rotate',
    'flipHorizontal' => 'Flip horizontal',
    'flipVertical' => 'Flip vertical',
    'resizeLongSide' => 'Resize',
    'adjustColor' => 'Adjust color',
    _ => 'Pipeline',
  };
}

class _PipelineJobResult {
  const _PipelineJobResult({
    required this.image,
    required this.label,
    required this.operation,
    required this.outputSettings,
  });

  final img.Image image;
  final String label;
  final String operation;
  final ImageClipOutputSettings outputSettings;
}
