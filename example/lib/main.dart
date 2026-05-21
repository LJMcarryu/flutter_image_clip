import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:image_picker/image_picker.dart';

const _allAspectRatios = <ImageClipAspectRatio>[
  ImageClipAspectRatio.square,
  ImageClipAspectRatio.portrait,
  ImageClipAspectRatio.landscape,
  ImageClipAspectRatio.widescreen,
  ImageClipAspectRatio.ratio16x10,
  ImageClipAspectRatio.ratio10x16,
];

const _unset = Object();

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
  ImageClipEditorController _controller = ImageClipEditorController();
  final _processor = const ImageProcessor();
  final _picker = ImagePicker();

  _DemoSettings _settings = _DemoSettings.defaults();
  Uint8List? _pickedImageBytes;
  String? _pickedImagePath;
  String _pickedImageLabel = '';
  ImageClipImageInfo? _inputInfo;
  ImageClipResult? _result;
  ImageClipTaskProgress? _progress;
  int? _pickElapsedMs;
  String _status = 'Ready';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Clip Lab')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final summary = _ExampleSummary(
              settings: _settings,
              inputInfo: _inputInfo,
              result: _result,
              previewImage: _controller.image,
              progress: _progress,
              pickElapsedMs: _pickElapsedMs,
              status: _status,
              canCancel: _controller.isBusy,
              onSettingsChanged: _setSettings,
              onPickFromGallery: _pickFromGallery,
              onLoadSample: _loadSample,
              onOpenFullscreen: _openFullscreenEditor,
              onCancelTask: _cancelTask,
            );
            final editor = ImageClipEditor(
              key: ValueKey(_settings.editorResetKey),
              controller: _controller,
              processor: _settings.useCustomProcessor
                  ? ImageProcessor(
                      processingSettings: _settings.processingSettings,
                      decodeAdapter: const ImageClipPlatformDecodeAdapter(),
                    )
                  : null,
              initialImageBytes: _pickedImagePath == null
                  ? _pickedImageBytes
                  : null,
              initialImagePath: _pickedImagePath,
              initialImageLabel: _pickedImageLabel,
              initialOrientation: _settings.initialOrientation,
              initialAspectRatio: _settings.initialAspectRatio,
              initialRotationDegrees: _settings.initialRotationDegrees,
              initialCropRegion: _settings.initialCropRegion,
              aspectRatios: _settings.aspectRatiosList,
              initialScaleMode: _settings.initialScaleMode,
              outputSettings: _settings.outputSettings,
              previewDecodeSettings: _settings.previewDecodeSettings,
              processingSettings: _settings.processingSettings,
              labels: _settings.labels,
              theme: _settings.themeFor(context),
              cropAreaHeight: _settings.cropAreaHeight,
              loadSampleOnStart: _settings.loadSampleOnStart,
              closeOnCancel: _settings.closeOnCancel,
              closeOnSave: _settings.closeOnSave,
              showResultPage: _settings.showResultPage,
              onCancel: () {
                setState(() {
                  _progress = null;
                  _status = 'Canceled';
                });
              },
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
                  _pickElapsedMs = null;
                  _status = 'Saved ${result.cropped.dimensionsLabel}';
                });
              },
            );

            if (constraints.maxWidth >= 980) {
              return Row(
                children: [
                  Expanded(child: editor),
                  SizedBox(width: 380, child: summary),
                ],
              );
            }

            final panelHeight = math.min(
              460.0,
              math.max(300.0, constraints.maxHeight * 0.46),
            );
            return Column(
              children: [
                Expanded(child: editor),
                SizedBox(height: panelHeight, child: summary),
              ],
            );
          },
        ),
      ),
    );
  }

  void _setSettings(_DemoSettings settings) {
    final shouldResetEditor =
        settings.editorResetKey != _settings.editorResetKey;
    setState(() {
      if (shouldResetEditor) {
        _controller = ImageClipEditorController();
      }
      _settings = settings;
      _progress = null;
      _status = 'Settings updated';
    });
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

      final stopwatch = Stopwatch()..start();
      var path = picked.path.trim().isEmpty ? null : picked.path;
      Uint8List? bytes;
      late ImageClipImageInfo info;
      if (path == null) {
        bytes = await picked.readAsBytes();
        info = _processor.probeBytes(bytes);
      } else {
        try {
          info = await _processor.probeFile(path);
        } catch (_) {
          path = null;
          bytes = await picked.readAsBytes();
          info = _processor.probeBytes(bytes);
        }
      }
      stopwatch.stop();
      setState(() {
        _pickedImagePath = path;
        _pickedImageBytes = bytes;
        _pickedImageLabel = picked.name;
        _inputInfo = info;
        _result = null;
        _progress = null;
        _pickElapsedMs = stopwatch.elapsedMilliseconds;
        _status = 'Loaded ${picked.name}';
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _loadSample() async {
    try {
      setState(() {
        _pickedImagePath = null;
        _pickedImageBytes = null;
        _pickedImageLabel = '';
        _result = null;
        _progress = null;
        _pickElapsedMs = null;
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

      final result = await _pushFullscreenEditor();

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
        _pickElapsedMs = null;
        _status = 'Fullscreen saved ${result.cropped.dimensionsLabel}';
      });
    } catch (error) {
      _showError(error);
    }
  }

  Future<ImageClipResult?> _pushFullscreenEditor() {
    final imagePath = _pickedImagePath;
    if (imagePath != null) {
      return showImageClipEditor(
        context,
        imagePath: imagePath,
        imageLabel: _pickedImageLabel,
      );
    }
    final imageBytes = _pickedImageBytes;
    if (imageBytes == null) {
      return showImageClipEditor(context);
    }
    return showImageClipEditor(
      context,
      imageBytes: imageBytes,
      imageLabel: _pickedImageLabel,
    );
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

enum _LabelPreset { english, zhHans, demo }

enum _ThemePreset { light, dark, colorScheme }

class _DemoSettings {
  const _DemoSettings({
    required this.initialOrientation,
    required this.initialAspectRatio,
    required this.initialRotationDegrees,
    required this.useInitialCropRegion,
    required this.initialCropX,
    required this.initialCropY,
    required this.initialCropWidth,
    required this.initialCropHeight,
    required this.aspectRatios,
    required this.initialScaleMode,
    required this.outputFormat,
    required this.jpegQuality,
    required this.pngLevel,
    required this.previewLongSide,
    required this.usePlatformAdapter,
    required this.maxInputPixels,
    required this.maxOutputPixels,
    required this.autoDownscale,
    required this.unrestrictedProcessing,
    required this.useCustomProcessor,
    required this.labelPreset,
    required this.themePreset,
    required this.cropAreaHeight,
    required this.loadSampleOnStart,
    required this.closeOnCancel,
    required this.closeOnSave,
    required this.showResultPage,
  });

  factory _DemoSettings.defaults() {
    return const _DemoSettings(
      initialOrientation: ImageClipCropOrientation.portrait,
      initialAspectRatio: ImageClipAspectRatio.landscape,
      initialRotationDegrees: 0,
      useInitialCropRegion: false,
      initialCropX: 240,
      initialCropY: 180,
      initialCropWidth: 960,
      initialCropHeight: 720,
      aspectRatios: _allAspectRatios,
      initialScaleMode: ImageClipScaleMode.fit,
      outputFormat: ImageClipOutputFormat.jpeg,
      jpegQuality: 88,
      pngLevel: 6,
      previewLongSide: 1200,
      usePlatformAdapter: true,
      maxInputPixels: 48000000,
      maxOutputPixels: 16000000,
      autoDownscale: true,
      unrestrictedProcessing: false,
      useCustomProcessor: true,
      labelPreset: _LabelPreset.demo,
      themePreset: _ThemePreset.light,
      cropAreaHeight: 800,
      loadSampleOnStart: true,
      closeOnCancel: false,
      closeOnSave: false,
      showResultPage: false,
    );
  }

  final ImageClipCropOrientation initialOrientation;
  final ImageClipAspectRatio? initialAspectRatio;
  final int initialRotationDegrees;
  final bool useInitialCropRegion;
  final int initialCropX;
  final int initialCropY;
  final int initialCropWidth;
  final int initialCropHeight;
  final List<ImageClipAspectRatio> aspectRatios;
  final ImageClipScaleMode initialScaleMode;
  final ImageClipOutputFormat outputFormat;
  final int jpegQuality;
  final int pngLevel;
  final int? previewLongSide;
  final bool usePlatformAdapter;
  final int? maxInputPixels;
  final int? maxOutputPixels;
  final bool autoDownscale;
  final bool unrestrictedProcessing;
  final bool useCustomProcessor;
  final _LabelPreset labelPreset;
  final _ThemePreset themePreset;
  final double? cropAreaHeight;
  final bool loadSampleOnStart;
  final bool closeOnCancel;
  final bool closeOnSave;
  final bool showResultPage;

  List<ImageClipAspectRatio> get aspectRatiosList {
    if (aspectRatios.isEmpty) {
      return ImageClipAspectRatio.defaults;
    }
    return aspectRatios;
  }

  CropRegion? get initialCropRegion {
    if (!useInitialCropRegion) {
      return null;
    }
    return CropRegion(
      x: initialCropX,
      y: initialCropY,
      width: initialCropWidth,
      height: initialCropHeight,
      cornerRadius: 0,
    );
  }

  ImageClipOutputSettings get outputSettings {
    return ImageClipOutputSettings(
      format: outputFormat,
      jpegQuality: jpegQuality,
      pngLevel: pngLevel,
    );
  }

  ImageClipDecodeSettings get previewDecodeSettings {
    return ImageClipDecodeSettings(
      targetLongSide: previewLongSide,
      usePlatformAdapter: usePlatformAdapter,
    );
  }

  ImageClipProcessingSettings get processingSettings {
    if (unrestrictedProcessing) {
      return const ImageClipProcessingSettings.unrestricted();
    }
    return ImageClipProcessingSettings(
      maxInputPixels: maxInputPixels,
      maxOutputPixels: maxOutputPixels,
      autoDownscale: autoDownscale,
    );
  }

  ImageClipEditorLabels get labels {
    return switch (labelPreset) {
      _LabelPreset.english => ImageClipEditorLabels.english,
      _LabelPreset.zhHans => ImageClipEditorLabels.zhHans,
      _LabelPreset.demo => const ImageClipEditorLabels(
        positionHint: 'Pinch to zoom • Drag to reposition',
        saveButton: 'Save',
      ),
    };
  }

  ImageClipEditorTheme themeFor(BuildContext context) {
    return switch (themePreset) {
      _ThemePreset.light => const ImageClipEditorTheme(),
      _ThemePreset.dark => const ImageClipEditorTheme.dark(),
      _ThemePreset.colorScheme => ImageClipEditorTheme.fromColorScheme(
        Theme.of(context).colorScheme,
      ),
    };
  }

  Object get editorResetKey {
    return Object.hashAll(<Object?>[
      initialOrientation,
      initialAspectRatio,
      initialRotationDegrees,
      useInitialCropRegion,
      initialCropX,
      initialCropY,
      initialCropWidth,
      initialCropHeight,
      initialScaleMode,
      previewLongSide,
      usePlatformAdapter,
      maxInputPixels,
      maxOutputPixels,
      autoDownscale,
      unrestrictedProcessing,
      useCustomProcessor,
      loadSampleOnStart,
    ]);
  }

  _DemoSettings copyWith({
    ImageClipCropOrientation? initialOrientation,
    Object? initialAspectRatio = _unset,
    int? initialRotationDegrees,
    bool? useInitialCropRegion,
    int? initialCropX,
    int? initialCropY,
    int? initialCropWidth,
    int? initialCropHeight,
    List<ImageClipAspectRatio>? aspectRatios,
    ImageClipScaleMode? initialScaleMode,
    ImageClipOutputFormat? outputFormat,
    int? jpegQuality,
    int? pngLevel,
    Object? previewLongSide = _unset,
    bool? usePlatformAdapter,
    Object? maxInputPixels = _unset,
    Object? maxOutputPixels = _unset,
    bool? autoDownscale,
    bool? unrestrictedProcessing,
    bool? useCustomProcessor,
    _LabelPreset? labelPreset,
    _ThemePreset? themePreset,
    Object? cropAreaHeight = _unset,
    bool? loadSampleOnStart,
    bool? closeOnCancel,
    bool? closeOnSave,
    bool? showResultPage,
  }) {
    return _DemoSettings(
      initialOrientation: initialOrientation ?? this.initialOrientation,
      initialAspectRatio: identical(initialAspectRatio, _unset)
          ? this.initialAspectRatio
          : initialAspectRatio as ImageClipAspectRatio?,
      initialRotationDegrees:
          initialRotationDegrees ?? this.initialRotationDegrees,
      useInitialCropRegion: useInitialCropRegion ?? this.useInitialCropRegion,
      initialCropX: initialCropX ?? this.initialCropX,
      initialCropY: initialCropY ?? this.initialCropY,
      initialCropWidth: initialCropWidth ?? this.initialCropWidth,
      initialCropHeight: initialCropHeight ?? this.initialCropHeight,
      aspectRatios: aspectRatios ?? this.aspectRatios,
      initialScaleMode: initialScaleMode ?? this.initialScaleMode,
      outputFormat: outputFormat ?? this.outputFormat,
      jpegQuality: jpegQuality ?? this.jpegQuality,
      pngLevel: pngLevel ?? this.pngLevel,
      previewLongSide: identical(previewLongSide, _unset)
          ? this.previewLongSide
          : previewLongSide as int?,
      usePlatformAdapter: usePlatformAdapter ?? this.usePlatformAdapter,
      maxInputPixels: identical(maxInputPixels, _unset)
          ? this.maxInputPixels
          : maxInputPixels as int?,
      maxOutputPixels: identical(maxOutputPixels, _unset)
          ? this.maxOutputPixels
          : maxOutputPixels as int?,
      autoDownscale: autoDownscale ?? this.autoDownscale,
      unrestrictedProcessing:
          unrestrictedProcessing ?? this.unrestrictedProcessing,
      useCustomProcessor: useCustomProcessor ?? this.useCustomProcessor,
      labelPreset: labelPreset ?? this.labelPreset,
      themePreset: themePreset ?? this.themePreset,
      cropAreaHeight: identical(cropAreaHeight, _unset)
          ? this.cropAreaHeight
          : cropAreaHeight as double?,
      loadSampleOnStart: loadSampleOnStart ?? this.loadSampleOnStart,
      closeOnCancel: closeOnCancel ?? this.closeOnCancel,
      closeOnSave: closeOnSave ?? this.closeOnSave,
      showResultPage: showResultPage ?? this.showResultPage,
    );
  }
}

class _ExampleSummary extends StatelessWidget {
  const _ExampleSummary({
    required this.settings,
    required this.inputInfo,
    required this.result,
    required this.previewImage,
    required this.progress,
    required this.pickElapsedMs,
    required this.status,
    required this.canCancel,
    required this.onSettingsChanged,
    required this.onPickFromGallery,
    required this.onLoadSample,
    required this.onOpenFullscreen,
    required this.onCancelTask,
  });

  final _DemoSettings settings;
  final ImageClipImageInfo? inputInfo;
  final ImageClipResult? result;
  final EditedImage? previewImage;
  final ImageClipTaskProgress? progress;
  final int? pickElapsedMs;
  final String status;
  final bool canCancel;
  final ValueChanged<_DemoSettings> onSettingsChanged;
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
      child: ListView(
        padding: const EdgeInsets.all(16),
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
              _MetricChip(
                label: 'Pick/probe',
                value: _millisecondsLabel(pickElapsedMs),
              ),
              _MetricChip(
                label: 'Preview task',
                value: _millisecondsLabel(previewImage?.elapsedMs),
              ),
              _MetricChip(
                label: 'Save task',
                value: _millisecondsLabel(cropped?.elapsedMs),
              ),
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
          const SizedBox(height: 16),
          _SettingsPanel(settings: settings, onChanged: onSettingsChanged),
        ],
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.settings, required this.onChanged});

  final _DemoSettings settings;
  final ValueChanged<_DemoSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          title: 'Editor parameters',
          children: [
            _DropdownSetting<ImageClipCropOrientation>(
              label: 'initialOrientation',
              value: settings.initialOrientation,
              values: ImageClipCropOrientation.values,
              labelFor: (value) => value.name,
              onChanged: (value) =>
                  onChanged(settings.copyWith(initialOrientation: value)),
            ),
            _DropdownSetting<ImageClipAspectRatio?>(
              label: 'initialAspectRatio',
              value: settings.initialAspectRatio,
              values: const <ImageClipAspectRatio?>[null, ..._allAspectRatios],
              labelFor: (value) => value?.label ?? 'from orientation',
              onChanged: (value) =>
                  onChanged(settings.copyWith(initialAspectRatio: value)),
            ),
            _DropdownSetting<int>(
              label: 'initialRotationDegrees',
              value: settings.initialRotationDegrees,
              values: const <int>[0, 90, 180, 270],
              labelFor: (value) => '$value°',
              onChanged: (value) =>
                  onChanged(settings.copyWith(initialRotationDegrees: value)),
            ),
            _DropdownSetting<ImageClipScaleMode>(
              label: 'initialScaleMode',
              value: settings.initialScaleMode,
              values: ImageClipScaleMode.values,
              labelFor: (value) => value.name,
              onChanged: (value) =>
                  onChanged(settings.copyWith(initialScaleMode: value)),
            ),
            _DropdownSetting<double?>(
              label: 'cropAreaHeight',
              value: settings.cropAreaHeight,
              values: const <double?>[null, 360, 520, 800],
              labelFor: (value) =>
                  value == null ? 'adaptive' : value.round().toString(),
              onChanged: (value) =>
                  onChanged(settings.copyWith(cropAreaHeight: value)),
            ),
            SwitchListTile(
              value: settings.useInitialCropRegion,
              title: const Text('initialCropRegion'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(useInitialCropRegion: value)),
            ),
            if (settings.useInitialCropRegion) ...[
              _NumberSetting(
                label: 'x',
                value: settings.initialCropX,
                onChanged: (value) =>
                    onChanged(settings.copyWith(initialCropX: value)),
              ),
              _NumberSetting(
                label: 'y',
                value: settings.initialCropY,
                onChanged: (value) =>
                    onChanged(settings.copyWith(initialCropY: value)),
              ),
              _NumberSetting(
                label: 'width',
                value: settings.initialCropWidth,
                min: 1,
                onChanged: (value) =>
                    onChanged(settings.copyWith(initialCropWidth: value)),
              ),
              _NumberSetting(
                label: 'height',
                value: settings.initialCropHeight,
                min: 1,
                onChanged: (value) =>
                    onChanged(settings.copyWith(initialCropHeight: value)),
              ),
            ],
            SwitchListTile(
              value: settings.loadSampleOnStart,
              title: const Text('loadSampleOnStart'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(loadSampleOnStart: value)),
            ),
            SwitchListTile(
              value: settings.showResultPage,
              title: const Text('showResultPage'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(showResultPage: value)),
            ),
            SwitchListTile(
              value: settings.closeOnCancel,
              title: const Text('closeOnCancel'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(closeOnCancel: value)),
            ),
            SwitchListTile(
              value: settings.closeOnSave,
              title: const Text('closeOnSave'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(closeOnSave: value)),
            ),
          ],
        ),
        _Section(
          title: 'aspectRatios',
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ratio in _allAspectRatios)
                  FilterChip(
                    label: Text(ratio.label),
                    selected: settings.aspectRatios.contains(ratio),
                    onSelected: (selected) {
                      final next = <ImageClipAspectRatio>[
                        ...settings.aspectRatios,
                      ];
                      if (selected) {
                        next.add(ratio);
                      } else if (next.length > 1) {
                        next.remove(ratio);
                      }
                      onChanged(settings.copyWith(aspectRatios: next));
                    },
                  ),
              ],
            ),
          ],
        ),
        _Section(
          title: 'Output settings',
          children: [
            SegmentedButton<ImageClipOutputFormat>(
              segments: const [
                ButtonSegment(
                  value: ImageClipOutputFormat.png,
                  label: Text('PNG'),
                ),
                ButtonSegment(
                  value: ImageClipOutputFormat.jpeg,
                  label: Text('JPEG'),
                ),
              ],
              selected: {settings.outputFormat},
              onSelectionChanged: (values) =>
                  onChanged(settings.copyWith(outputFormat: values.single)),
            ),
            if (settings.outputFormat == ImageClipOutputFormat.jpeg)
              _SliderSetting(
                label: 'jpegQuality',
                value: settings.jpegQuality.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                valueLabel: settings.jpegQuality.toString(),
                onChanged: (value) =>
                    onChanged(settings.copyWith(jpegQuality: value.round())),
              )
            else
              _SliderSetting(
                label: 'pngLevel',
                value: settings.pngLevel.toDouble(),
                min: 0,
                max: 9,
                divisions: 9,
                valueLabel: settings.pngLevel.toString(),
                onChanged: (value) =>
                    onChanged(settings.copyWith(pngLevel: value.round())),
              ),
          ],
        ),
        _Section(
          title: 'Decode and processing',
          children: [
            _DropdownSetting<int?>(
              label: 'preview targetLongSide',
              value: settings.previewLongSide,
              values: const <int?>[null, 320, 640, 1200, 2048],
              labelFor: (value) => value?.toString() ?? 'original',
              onChanged: (value) =>
                  onChanged(settings.copyWith(previewLongSide: value)),
            ),
            SwitchListTile(
              value: settings.usePlatformAdapter,
              title: const Text('preview usePlatformAdapter'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(usePlatformAdapter: value)),
            ),
            SwitchListTile(
              value: settings.useCustomProcessor,
              title: const Text('processor with platform adapter'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(useCustomProcessor: value)),
            ),
            SwitchListTile(
              value: settings.unrestrictedProcessing,
              title: const Text('processing unrestricted'),
              onChanged: (value) =>
                  onChanged(settings.copyWith(unrestrictedProcessing: value)),
            ),
            if (!settings.unrestrictedProcessing) ...[
              _DropdownSetting<int?>(
                label: 'maxInputPixels',
                value: settings.maxInputPixels,
                values: const <int?>[null, 12000000, 48000000, 96000000],
                labelFor: _pixelsLabel,
                onChanged: (value) =>
                    onChanged(settings.copyWith(maxInputPixels: value)),
              ),
              _DropdownSetting<int?>(
                label: 'maxOutputPixels',
                value: settings.maxOutputPixels,
                values: const <int?>[null, 4000000, 16000000, 32000000],
                labelFor: _pixelsLabel,
                onChanged: (value) =>
                    onChanged(settings.copyWith(maxOutputPixels: value)),
              ),
              SwitchListTile(
                value: settings.autoDownscale,
                title: const Text('autoDownscale'),
                onChanged: (value) =>
                    onChanged(settings.copyWith(autoDownscale: value)),
              ),
            ],
          ],
        ),
        _Section(
          title: 'Labels and theme',
          children: [
            _DropdownSetting<_LabelPreset>(
              label: 'labels',
              value: settings.labelPreset,
              values: _LabelPreset.values,
              labelFor: (value) => value.name,
              onChanged: (value) =>
                  onChanged(settings.copyWith(labelPreset: value)),
            ),
            _DropdownSetting<_ThemePreset>(
              label: 'theme',
              value: settings.themePreset,
              values: _ThemePreset.values,
              labelFor: (value) => value.name,
              onChanged: (value) =>
                  onChanged(settings.copyWith(themePreset: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: title == 'Editor parameters',
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(title),
        children: [
          for (final child in children) ...[
            child,
            if (child != children.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _DropdownSetting<T> extends StatelessWidget {
  const _DropdownSetting({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = math.max(
      0,
      values.indexWhere((item) => item == value),
    );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedIndex,
          isExpanded: true,
          isDense: true,
          items: [
            for (var i = 0; i < values.length; i++)
              DropdownMenuItem<int>(
                value: i,
                child: Text(
                  labelFor(values[i]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (index) {
            if (index != null) {
              onChanged(values[index]);
            }
          },
        ),
      ),
    );
  }
}

class _NumberSetting extends StatefulWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final int value;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberSetting> createState() => _NumberSettingState();
}

class _NumberSettingState extends State<_NumberSetting> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: _commit,
      onEditingComplete: () => _commit(_controller.text),
    );
  }

  void _commit(String text) {
    final parsed = int.tryParse(text);
    if (parsed == null) {
      _controller.text = widget.value.toString();
      return;
    }
    widget.onChanged(parsed < widget.min ? widget.min : parsed);
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(valueLabel),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
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

String _pixelsLabel(int? pixels) {
  if (pixels == null) {
    return 'unlimited';
  }
  final megapixels = pixels / 1000000;
  final text = megapixels == megapixels.roundToDouble()
      ? megapixels.toStringAsFixed(0)
      : megapixels.toStringAsFixed(1);
  return '$text MP';
}

String _millisecondsLabel(int? milliseconds) {
  if (milliseconds == null) {
    return '-';
  }
  return '${milliseconds}ms';
}
