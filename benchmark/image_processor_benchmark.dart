import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_clip/image_processing/image_processor.dart';
import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  final processor = ImageProcessor();
  final smallPng = _pngBytes(640, 480);
  final largePng = _pngBytes(2400, 1600);

  final results = <_BenchmarkResult>[
    await _measure(
      'decode png 640x480',
      () => processor.decodeBytes(smallPng, label: 'small.png'),
    ),
    await _measure(
      'rotate crop export jpeg',
      () => processor.processBytes(
        smallPng,
        label: 'pipeline.png',
        steps: const <ImageClipPipelineStep>[
          ImageClipPipelineStep.rotate(),
          ImageClipPipelineStep.cropRegion(
            CropRegion(x: 40, y: 40, width: 360, height: 260, cornerRadius: 0),
          ),
        ],
        outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 86),
      ),
    ),
    await _measure(
      'downscale png 2400x1600',
      () => ImageProcessor(
        processingSettings: const ImageClipProcessingSettings(
          maxOutputPixels: 1000000,
        ),
      ).decodeBytes(largePng, label: 'large.png'),
      iterations: 3,
    ),
  ];

  if (args.contains('--json')) {
    _printJsonResults(results);
    return;
  }
  _printTableResults(results);
}

Future<_BenchmarkResult> _measure(
  String name,
  Future<EditedImage> Function() run, {
  int iterations = 5,
}) async {
  await run();

  final times = <int>[];
  EditedImage? last;
  for (var i = 0; i < iterations; i++) {
    final stopwatch = Stopwatch()..start();
    last = await run();
    stopwatch.stop();
    times.add(stopwatch.elapsedMilliseconds);
  }

  times.sort();
  final total = times.fold<int>(0, (sum, value) => sum + value);
  return _BenchmarkResult(
    name: name,
    averageMs: total / times.length,
    medianMs: times[times.length ~/ 2],
    outputBytes: last!.bytes.length,
    outputSize: last.dimensionsLabel,
  );
}

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 255 / width).round(),
        (y * 255 / height).round(),
        ((x + y) * 255 / (width + height)).round(),
        255,
      );
    }
  }
  return Uint8List.fromList(img.encodePng(image, level: 6));
}

void _printTableResults(List<_BenchmarkResult> results) {
  stdout.writeln('| case | avg ms | median ms | output | bytes |');
  stdout.writeln('| --- | ---: | ---: | --- | ---: |');
  for (final result in results) {
    stdout.writeln(
      '| ${result.name} | ${result.averageMs.toStringAsFixed(1)} | '
      '${result.medianMs} | ${result.outputSize} | ${result.outputBytes} |',
    );
  }
}

void _printJsonResults(List<_BenchmarkResult> results) {
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'results': <Map<String, Object?>>[
        for (final result in results) result.toJson(),
      ],
    }),
  );
}

class _BenchmarkResult {
  const _BenchmarkResult({
    required this.name,
    required this.averageMs,
    required this.medianMs,
    required this.outputBytes,
    required this.outputSize,
  });

  final String name;
  final double averageMs;
  final int medianMs;
  final int outputBytes;
  final String outputSize;

  Map<String, Object?> toJson() => <String, Object?>{
    'case': name,
    'averageMs': averageMs,
    'medianMs': medianMs,
    'outputBytes': outputBytes,
    'outputSize': outputSize,
  };
}
