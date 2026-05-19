import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:image_picker/image_picker.dart';

const _demoAspectRatios = <ImageClipAspectRatio>[
  ImageClipAspectRatio.square,
  ImageClipAspectRatio.portrait,
  ImageClipAspectRatio.landscape,
  ImageClipAspectRatio.widescreen,
  ImageClipAspectRatio.ratio16x10,
  ImageClipAspectRatio.ratio10x16,
];
const _demoOutputSettings = ImageClipOutputSettings.jpeg(jpegQuality: 88);
const _demoLabels = ImageClipEditorLabels(
  positionHint: 'Pinch to zoom • Drag to reposition',
  saveButton: 'Save',
);

void main() {
  runApp(const ImageClipExampleApp());
}

class ImageClipExampleApp extends StatelessWidget {
  const ImageClipExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006D77),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Image Clip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      ),
      home: const ImageClipExampleHome(),
    );
  }
}

class ImageClipExampleHome extends StatefulWidget {
  const ImageClipExampleHome({super.key});

  @override
  State<ImageClipExampleHome> createState() => _ImageClipExampleHomeState();
}

class _ImageClipExampleHomeState extends State<ImageClipExampleHome> {
  final _controller = ImageClipEditorController();
  final _processor = const ImageProcessor();
  final _picker = ImagePicker();

  Uint8List? _pickedImageBytes;
  String _pickedImageLabel = '';
  ImageClipImageInfo? _inputInfo;
  ImageClipResult? _result;
  ImageClipTaskProgress? _progress;
  String _status = 'Ready';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Clip Lab')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final summary = _ExampleSummary(
              inputInfo: _inputInfo,
              result: _result,
              progress: _progress,
              status: _status,
              canCancel: _controller.isBusy,
              onPickFromGallery: _pickFromGallery,
              onLoadSample: _loadSample,
              onOpenFullscreen: _openFullscreenEditor,
              onCancelTask: _cancelTask,
            );
            final editor = ImageClipEditor(
              controller: _controller,
              cropAreaHeight: 800,
              loadSampleOnStart: true,
              showResultPage: false,
              aspectRatios: _demoAspectRatios,
              outputSettings: _demoOutputSettings,
              labels: _demoLabels,
              onProgress: (progress) {
                setState(() {
                  _progress = progress;
                  _status = progress.message;
                });
              },
              onResult: (result) {
                setState(() {
                  _result = result;
                  _progress = null;
                  _status = 'Saved ${result.cropped.dimensionsLabel}';
                });
              },
            );

            if (constraints.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: editor),
                  SizedBox(width: 340, child: summary),
                ],
              );
            }

            return Column(
              children: [
                Expanded(child: editor),
                summary,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (!mounted || picked == null) {
        return;
      }

      final bytes = await picked.readAsBytes();
      final info = _processor.probeBytes(bytes);
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageLabel = picked.name;
        _inputInfo = info;
        _result = null;
        _progress = null;
        _status = 'Loading ${picked.name}';
      });
      await _controller.loadImage(bytes, label: picked.name);
      if (!mounted) {
        return;
      }
      setState(() {
        _progress = null;
        _status = 'Loaded ${info.dimensionsLabel}';
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _loadSample() async {
    try {
      setState(() {
        _pickedImageBytes = null;
        _pickedImageLabel = '';
        _result = null;
        _progress = null;
        _status = 'Loading sample';
      });
      await _controller.loadSample();
      if (!mounted) {
        return;
      }
      final image = _controller.image;
      setState(() {
        _inputInfo = image == null
            ? null
            : ImageClipImageInfo(
                format: ImageClipEncodedFormat.png,
                width: image.width,
                height: image.height,
              );
        _progress = null;
        _status = image == null
            ? 'Ready'
            : 'Loaded ${image.dimensionsLabel} sample';
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openFullscreenEditor() async {
    try {
      setState(() {
        _progress = null;
        _status = 'Opening fullscreen editor';
      });

      final result = await showImageClipEditor(
        context,
        imageBytes: _pickedImageBytes,
        imageLabel: _pickedImageLabel,
        aspectRatios: _demoAspectRatios,
        outputSettings: _demoOutputSettings,
        cropAreaHeight: 400,
        labels: _demoLabels,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _progress = progress;
            _status = progress.message;
          });
        },
      );

      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() {
          _progress = null;
          _status = 'Fullscreen editor closed';
        });
        return;
      }

      setState(() {
        _inputInfo = ImageClipImageInfo(
          format: _encodedFormatFor(result.source.format),
          width: result.source.sourceWidth,
          height: result.source.sourceHeight,
        );
        _result = result;
        _progress = null;
        _status = 'Fullscreen saved ${result.cropped.dimensionsLabel}';
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _cancelTask() {
    if (!_controller.cancelTask()) {
      return;
    }
    setState(() {
      _progress = null;
      _status = 'Canceled';
    });
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _progress = null;
      _status = 'Failed';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

ImageClipEncodedFormat _encodedFormatFor(ImageClipOutputFormat format) {
  return switch (format) {
    ImageClipOutputFormat.png => ImageClipEncodedFormat.png,
    ImageClipOutputFormat.jpeg => ImageClipEncodedFormat.jpeg,
  };
}

class _ExampleSummary extends StatelessWidget {
  const _ExampleSummary({
    required this.inputInfo,
    required this.result,
    required this.progress,
    required this.status,
    required this.canCancel,
    required this.onPickFromGallery,
    required this.onLoadSample,
    required this.onOpenFullscreen,
    required this.onCancelTask,
  });

  final ImageClipImageInfo? inputInfo;
  final ImageClipResult? result;
  final ImageClipTaskProgress? progress;
  final String status;
  final bool canCancel;
  final VoidCallback onPickFromGallery;
  final VoidCallback onLoadSample;
  final VoidCallback onOpenFullscreen;
  final VoidCallback onCancelTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final input = inputInfo;
    final cropped = result?.cropped;

    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              status,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (progress != null)
              LinearProgressIndicator(value: progress!.fraction),
            if (progress != null) const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onOpenFullscreen,
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open Fullscreen'),
                ),
                OutlinedButton.icon(
                  onPressed: onPickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: onLoadSample,
                  icon: const Icon(Icons.image_search_outlined),
                  label: const Text('Sample'),
                ),
                IconButton.outlined(
                  onPressed: canCancel ? onCancelTask : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Cancel task',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  label: 'Input',
                  value: input == null
                      ? 'Sample'
                      : '${input.format.name} ${input.dimensionsLabel}',
                ),
                _MetricChip(
                  label: 'Output',
                  value: cropped == null
                      ? '-'
                      : '${cropped.fileExtension} ${cropped.dimensionsLabel}',
                ),
                _MetricChip(label: 'Bytes', value: cropped?.bytesLabel ?? '-'),
              ],
            ),
            if (cropped != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: Image.memory(cropped.bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
