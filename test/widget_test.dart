import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Future<void> pumpUntilSampleLoads(WidgetTester tester) async {
    for (var i = 0; i < 40 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpUntilIdle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
        return;
      }
    }
  }

  Future<void> pumpClippingApp(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    Widget editor = const ImageClipEditor(),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(debugShowCheckedModeBanner: false, home: editor),
    );
    await pumpUntilSampleLoads(tester);
  }

  Future<void> pinchImage(WidgetTester tester) async {
    final center = tester.getCenter(find.byType(Image).first);
    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);

    await first.down(center - const Offset(24, 0));
    await second.down(center + const Offset(24, 0));
    await tester.pump();
    await first.moveTo(center - const Offset(58, 0));
    await second.moveTo(center + const Offset(58, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await first.up();
    await second.up();
    await tester.pump();
  }

  testWidgets('shows reference cropper controls', (tester) async {
    await pumpClippingApp(tester);

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Fit'), findsOneWidget);
    expect(find.text('Flip H'), findsOneWidget);
    expect(find.text('Flip V'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes crop controls to accessibility services', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpClippingApp(tester);

      expect(find.bySemanticsLabel('Image crop preview'), findsOneWidget);
      expect(find.bySemanticsLabel('Crop frame'), findsOneWidget);
      expect(find.bySemanticsLabel('Fit'), findsOneWidget);
      expect(find.bySemanticsLabel('Flip H'), findsOneWidget);
      expect(find.bySemanticsLabel('Flip V'), findsOneWidget);
      expect(find.bySemanticsLabel('Rotate'), findsOneWidget);
      expect(find.bySemanticsLabel('Portrait'), findsOneWidget);
      expect(find.bySemanticsLabel('Landscape'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('matches the default editor golden', (tester) async {
    await pumpClippingApp(
      tester,
      size: const Size(390, 844),
      editor: ImageClipEditor(
        initialImageBytes: _pngBytes(160, 120),
        initialImageLabel: 'golden.png',
        loadSampleOnStart: false,
      ),
    );

    await expectLater(
      find.byType(ImageClipEditor),
      matchesGoldenFile('goldens/image_clip_editor_default.png'),
    );
  });

  testWidgets('loaded sample supports drag, pinch, rotate, fit and save', (
    tester,
  ) async {
    await pumpClippingApp(tester);

    await tester.drag(find.byType(Image).first, const Offset(32, -24));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await pinchImage(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fit'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Rotate'));
    await pumpUntilIdle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Flip H'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Flip V'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotate updates the preview without starting a processing task', (
    tester,
  ) async {
    var progressEvents = 0;

    await pumpClippingApp(
      tester,
      editor: ImageClipEditor(
        initialImageBytes: _pngBytes(120, 80),
        initialImageLabel: 'instant-rotate.png',
        loadSampleOnStart: false,
        onProgress: (_) {
          progressEvents++;
        },
      ),
    );
    await pumpUntilIdle(tester);
    final eventsAfterLoad = progressEvents;

    await tester.tap(find.text('Rotate'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(progressEvents, eventsAfterLoad);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flip updates the preview without starting a processing task', (
    tester,
  ) async {
    var progressEvents = 0;

    await pumpClippingApp(
      tester,
      editor: ImageClipEditor(
        initialImageBytes: _pngBytes(120, 80),
        initialImageLabel: 'instant-flip.png',
        loadSampleOnStart: false,
        onProgress: (_) {
          progressEvents++;
        },
      ),
    );
    await pumpUntilIdle(tester);
    final eventsAfterLoad = progressEvents;

    await tester.tap(find.text('Flip H'));
    await tester.pump();
    await tester.tap(find.text('Flip V'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(progressEvents, eventsAfterLoad);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fit button toggles between fit and fill modes', (tester) async {
    await pumpClippingApp(tester);

    expect(find.text('Fit'), findsOneWidget);
    expect(find.text('Fill'), findsNothing);

    await tester.tap(find.text('Fit'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fit'), findsNothing);
    expect(find.text('Fill'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fill'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fit'), findsOneWidget);
    expect(find.text('Fill'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save opens result page with crop metadata', (tester) async {
    await pumpClippingApp(tester);

    await tester.tap(find.text('Rotate'));
    await pumpUntilIdle(tester);
    await tester.tap(find.text('Flip H'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);
    await tester.pumpAndSettle();

    expect(find.text('Crop result'), findsOneWidget);
    expect(find.text('Crop details'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
    expect(find.text('Flip H'), findsOneWidget);
    expect(find.text('Result data'), findsOneWidget);
    expect(find.textContaining('rotationDegrees: 90'), findsOneWidget);
    expect(find.textContaining('flippedHorizontally: true'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'rotated crop maps preview coordinates back to the source image',
    (tester) async {
      final controller = ImageClipEditorController();

      await tester.pumpWidget(
        MaterialApp(
          home: ImageClipEditor(
            controller: controller,
            initialImageBytes: _pngBytes(120, 80),
            initialImageLabel: 'rotated-crop.png',
            loadSampleOnStart: false,
            showResultPage: false,
          ),
        ),
      );
      await pumpUntilIdle(tester);

      await tester.tap(find.text('Rotate'));
      await tester.pump();
      await tester.tap(find.text('Flip H'));
      await tester.pump();

      final result = await tester.runAsync(controller.crop);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.rotationDegrees, 90);
      expect(result.flippedHorizontally, isTrue);
      expect(result.flippedVertically, isFalse);
      expect(result.previewRegion.width, greaterThan(0));
      expect(result.previewRegion.height, greaterThan(0));
      final expectedRegion =
          const ImageClipCropTransform(
            rotationDegrees: 90,
            flipHorizontal: true,
          ).sourceRegionForPreview(
            sourceWidth: 120,
            sourceHeight: 80,
            previewRegion: result.previewRegion,
          );
      expect(result.region.x, expectedRegion.x);
      expect(result.region.y, expectedRegion.y);
      expect(result.region.width, expectedRegion.width);
      expect(result.region.height, expectedRegion.height);
      expect(result.cropped.width, result.previewRegion.width);
      expect(result.cropped.height, result.previewRegion.height);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('supports custom labels and aspect ratio presets', (
    tester,
  ) async {
    await pumpClippingApp(
      tester,
      editor: const ImageClipEditor(
        labels: ImageClipEditorLabels(
          cancelButton: 'Dismiss',
          saveButton: 'Crop',
          flipHorizontalButton: 'Mirror H',
          flipVerticalButton: 'Mirror V',
          rotateButton: 'Turn',
        ),
        initialAspectRatio: ImageClipAspectRatio.square,
        aspectRatios: <ImageClipAspectRatio>[
          ImageClipAspectRatio.square,
          ImageClipAspectRatio.widescreen,
        ],
      ),
    );

    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Mirror H'), findsOneWidget);
    expect(find.text('Mirror V'), findsOneWidget);
    expect(find.text('Turn'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('applies custom editor theme tokens', (tester) async {
    const background = Color(0xFF1E293B);
    const primaryText = Color(0xFFF8FAFC);

    await pumpClippingApp(
      tester,
      editor: const ImageClipEditor(
        theme: ImageClipEditorTheme(
          backgroundColor: background,
          primaryTextColor: primaryText,
          cropBorderColor: Color(0xFFF59E0B),
          cropGridColor: Color(0x99F59E0B),
        ),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    final cancel = tester.widget<TextButton>(find.byType(TextButton).first);

    expect(scaffold.backgroundColor, background);
    expect(
      cancel.style?.foregroundColor?.resolve(<WidgetState>{}),
      primaryText,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('save can return JPEG output', (tester) async {
    ImageClipResult? result;

    await pumpClippingApp(
      tester,
      editor: ImageClipEditor(
        showResultPage: false,
        outputSettings: const ImageClipOutputSettings.jpeg(jpegQuality: 82),
        onResult: (value) {
          result = value;
        },
      ),
    );

    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);

    expect(result, isNotNull);
    expect(result!.cropped.format, ImageClipOutputFormat.jpeg);
    expect(result!.cropped.mimeType, 'image/jpeg');
    expect(result!.cropped.bytes.sublist(0, 2), <int>[0xFF, 0xD8]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('showImageClipEditor returns crop result to caller', (
    tester,
  ) async {
    ImageClipResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await showImageClipEditor(context);
              },
              child: const Text('open editor'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open editor'));
    await pumpUntilSampleLoads(tester);
    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.cropped.bytes, isNotEmpty);
    expect(result!.region.width, greaterThan(0));
    expect(result!.region.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('portrait and landscape crop modes switch without crashing', (
    tester,
  ) async {
    await pumpClippingApp(tester);

    await tester.tap(find.text('Landscape'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Portrait'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out on tall narrow phones without clamp errors', (
    tester,
  ) async {
    await pumpClippingApp(tester, size: const Size(430, 932));

    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out with large text in landscape', (tester) async {
    await pumpClippingApp(
      tester,
      size: const Size(844, 390),
      editor: MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          textScaler: TextScaler.linear(1.6),
        ),
        child: const ImageClipEditor(
          labels: ImageClipEditorLabels(
            flipHorizontalButton: 'Flip horizontally',
            flipVerticalButton: 'Flip vertically',
          ),
        ),
      ),
    );

    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller can load, reset, rotate and crop an image', (
    tester,
  ) async {
    final controller = ImageClipEditorController();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      ),
    );

    expect(controller.isAttached, isTrue);
    expect(controller.image, isNull);

    await tester.runAsync(() {
      return controller.loadImage(_pngBytes(120, 80), label: 'controller.png');
    });
    await tester.pump();

    expect(controller.image, isNotNull);
    expect(controller.currentCropRegion(), isNotNull);
    expect(find.byType(Image), findsWidgets);

    controller.resetView();
    await tester.runAsync(controller.rotateRight);
    await tester.runAsync(controller.flipHorizontal);
    await tester.pump();

    final result = await tester.runAsync(controller.crop);
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.source.label, 'controller.png');
    expect(result.cropped.bytes, isNotEmpty);
    expect(result.rotationDegrees, 90);
    expect(result.flippedHorizontally, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview decode saves from original source dimensions', (
    tester,
  ) async {
    final controller = ImageClipEditorController();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          initialImageBytes: _pngBytes(400, 200),
          initialImageLabel: 'preview-source.png',
          previewDecodeSettings: const ImageClipDecodeSettings.preview(
            targetLongSide: 100,
          ),
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      ),
    );
    await pumpUntilIdle(tester);

    expect(controller.image?.width, 100);
    expect(controller.image?.height, 50);
    expect(controller.image?.sourceWidth, 400);
    expect(controller.image?.sourceHeight, 200);

    final result = await tester.runAsync(controller.crop);
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.source.isPreviewSized, isTrue);
    expect(result.region.width, greaterThan(result.previewRegion.width));
    expect(result.region.height, greaterThan(result.previewRegion.height));
    expect(result.cropped.width, result.region.width);
    expect(result.cropped.height, result.region.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('newer image loads ignore stale async completions', (
    tester,
  ) async {
    final controller = ImageClipEditorController();
    final processor = _DelayedDecodeProcessor();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          processor: processor,
          initialImageBytes: _pngBytes(32, 32),
          initialImageLabel: 'first.png',
          loadSampleOnStart: false,
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          processor: processor,
          initialImageBytes: _pngBytes(48, 48),
          initialImageLabel: 'second.png',
          loadSampleOnStart: false,
        ),
      ),
    );
    await tester.pump();

    processor.complete('second.png', width: 48, height: 48);
    await tester.pump();

    expect(controller.image?.label, 'second.png');

    processor.complete('first.png', width: 32, height: 32);
    await tester.pump();

    expect(controller.image?.label, 'second.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('controller can cancel the active image task', (tester) async {
    final controller = ImageClipEditorController();
    final processor = _DelayedDecodeProcessor();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          processor: processor,
          loadSampleOnStart: false,
        ),
      ),
    );
    await tester.pump();

    final loadFuture = controller.loadImage(
      _pngBytes(64, 64),
      label: 'cancel.png',
    );
    await tester.pump();

    expect(controller.isBusy, isTrue);
    expect(controller.cancelTask(), isTrue);
    await tester.pump();
    await loadFuture;

    expect(controller.isBusy, isFalse);
    expect(controller.image, isNull);
    expect(tester.takeException(), isNull);
  });
}

Uint8List _pngBytes(int width, int height) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

EditedImage _editedImage(
  String label, {
  required int width,
  required int height,
}) {
  return EditedImage(
    bytes: _pngBytes(width, height),
    width: width,
    height: height,
    label: label,
    operation: 'Decode',
    elapsedMs: 1,
  );
}

class _DelayedDecodeProcessor extends ImageProcessor {
  final _pending = <String, Completer<EditedImage>>{};

  @override
  ImageClipTask<EditedImage> decodeBytesTask(
    Uint8List bytes, {
    required String label,
    ImageClipDecodeSettings decodeSettings = const ImageClipDecodeSettings(),
    ImageClipTaskOptions? options,
  }) {
    final completer = Completer<EditedImage>();
    _pending[label] = completer;
    return ImageClipTask<EditedImage>.fromFuture(
      completer.future,
      options: options,
    );
  }

  void complete(String label, {required int width, required int height}) {
    _pending
        .remove(label)!
        .complete(_editedImage(label, width: width, height: height));
  }
}
