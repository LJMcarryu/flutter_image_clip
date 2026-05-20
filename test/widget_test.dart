import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('supports custom aspect ratios and the 16:10 / 10:16 presets', () {
    const custom = ImageClipAspectRatio(label: '21:9', width: 21, height: 9);
    final generated = ImageClipAspectRatio.fromDimensions(
      width: 480,
      height: 640,
    );
    final matched = ImageClipAspectRatio.fromDimensions(
      width: 1600,
      height: 1000,
      presets: const <ImageClipAspectRatio>[ImageClipAspectRatio.ratio16x10],
    );
    final rotatedRegionRatio = ImageClipAspectRatio.fromCropRegion(
      const CropRegion(x: 0, y: 0, width: 200, height: 100, cornerRadius: 0),
      rotationDegrees: 90,
    );

    expect(custom.value, closeTo(21 / 9, 0.0001));
    expect(generated.label, '3:4');
    expect(generated.value, closeTo(0.75, 0.0001));
    expect(matched, ImageClipAspectRatio.ratio16x10);
    expect(rotatedRegionRatio.label, '1:2');
    expect(rotatedRegionRatio.value, closeTo(0.5, 0.0001));
    expect(ImageClipAspectRatio.ratio16x10.label, '16:10');
    expect(ImageClipAspectRatio.ratio16x10.value, closeTo(1.6, 0.0001));
    expect(ImageClipAspectRatio.ratio10x16.label, '10:16');
    expect(ImageClipAspectRatio.ratio10x16.value, closeTo(0.625, 0.0001));
    expect(
      () => ImageClipAspectRatio.fromDimensions(width: 0, height: 1),
      throwsArgumentError,
    );
    expect(
      () => ImageClipAspectRatio.fromCropRegion(
        const CropRegion(x: 0, y: 0, width: 1, height: 1, cornerRadius: 0),
        rotationDegrees: 45,
      ),
      throwsArgumentError,
    );
  });

  test('normalizes crop regions and quarter-turn rotations', () {
    expect(ImageClipCropTransform.isQuarterTurnRotation(450), isTrue);
    const invalidRotation = ImageClipCropTransform(rotationDegrees: 45);
    expect(invalidRotation.hasQuarterTurnRotation, isFalse);
    expect(() => invalidRotation.quarterTurns, throwsArgumentError);

    final oversized = const CropRegion(
      x: -10,
      y: 295,
      width: 500,
      height: 50,
      cornerRadius: 99,
    ).clampToBounds(sourceWidth: 400, sourceHeight: 300);

    expect(
      oversized,
      const CropRegion(x: 0, y: 295, width: 400, height: 5, cornerRadius: 2.5),
    );

    final empty = const CropRegion(
      x: 500,
      y: -20,
      width: 0,
      height: -5,
      cornerRadius: double.nan,
    ).clampToBounds(sourceWidth: 400, sourceHeight: 300);

    expect(
      empty,
      const CropRegion(x: 399, y: 0, width: 1, height: 1, cornerRadius: 0),
    );
  });

  test('clamps encoded output settings read from maps', () {
    final settings = ImageClipOutputSettings.fromMap(<Object?, Object?>{
      'format': 'jpeg',
      'jpegQuality': 120,
      'pngLevel': -3,
    });

    expect(settings.format, ImageClipOutputFormat.jpeg);
    expect(settings.jpegQuality, 100);
    expect(settings.pngLevel, 0);
  });

  test('ignores non-positive processing and decode limits from maps', () {
    final processing = ImageClipProcessingSettings.fromMap(<Object?, Object?>{
      'maxInputPixels': -1,
      'maxOutputPixels': 0,
      'autoDownscale': false,
    });
    final decode = ImageClipDecodeSettings.fromMap(<Object?, Object?>{
      'targetLongSide': 0,
      'usePlatformAdapter': false,
    });

    expect(processing.maxInputPixels, isNull);
    expect(processing.maxOutputPixels, isNull);
    expect(processing.autoDownscale, isFalse);
    expect(decode.targetLongSide, isNull);
    expect(decode.usePlatformAdapter, isFalse);
  });

  test('maps crop regions between source and rotated preview coordinates', () {
    const transform = ImageClipCropTransform(rotationDegrees: 90);
    const sourceRegion = CropRegion(
      x: 50,
      y: 40,
      width: 200,
      height: 100,
      cornerRadius: 0,
    );

    final previewRegion = transform.previewRegionForSource(
      sourceWidth: 400,
      sourceHeight: 300,
      sourceRegion: sourceRegion,
    );

    expect(
      previewRegion,
      const CropRegion(x: 160, y: 50, width: 100, height: 200, cornerRadius: 0),
    );
    expect(
      transform.sourceRegionForPreview(
        sourceWidth: 400,
        sourceHeight: 300,
        previewRegion: previewRegion,
      ),
      sourceRegion,
    );
  });

  test('clamps crop regions before mapping rotated coordinates', () {
    const transform = ImageClipCropTransform(rotationDegrees: 90);
    const sourceRegion = CropRegion(
      x: -10,
      y: 250,
      width: 500,
      height: 100,
      cornerRadius: 99,
    );
    final boundedSourceRegion = sourceRegion.clampToBounds(
      sourceWidth: 400,
      sourceHeight: 300,
    );

    final previewRegion = transform.previewRegionForSource(
      sourceWidth: 400,
      sourceHeight: 300,
      sourceRegion: sourceRegion,
    );

    expect(
      transform.sourceRegionForPreview(
        sourceWidth: 400,
        sourceHeight: 300,
        previewRegion: previewRegion,
      ),
      boundedSourceRegion,
    );
  });

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

    expect(find.text('Position'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    expect(find.text('Pinch to zoom • Drag to reposition'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('3:4'), findsOneWidget);
    expect(find.text('4:3'), findsOneWidget);
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
      expect(find.bySemanticsLabel('Cancel'), findsOneWidget);
      expect(find.bySemanticsLabel('Fill'), findsOneWidget);
      expect(find.bySemanticsLabel('Rotate'), findsOneWidget);
      expect(find.bySemanticsLabel('3:4'), findsOneWidget);
      expect(find.bySemanticsLabel('4:3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('supports Simplified Chinese labels and semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpClippingApp(
        tester,
        editor: const ImageClipEditor(labels: ImageClipEditorLabels.zhHans),
      );

      expect(find.text('位置'), findsOneWidget);
      expect(find.text('双指缩放 • 拖动调整位置'), findsOneWidget);
      expect(find.byTooltip('取消'), findsOneWidget);
      expect(find.text('保存'), findsOneWidget);
      expect(find.bySemanticsLabel('图片裁剪预览'), findsOneWidget);
      expect(find.bySemanticsLabel('裁剪框'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('matches the default editor golden', (tester) async {
    final previousComparator = goldenFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/widget_test.dart'),
      precisionTolerance: 0.01,
    );
    addTearDown(() {
      goldenFileComparator = previousComparator;
    });

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

  testWidgets('matches Figma default mobile chrome metrics', (tester) async {
    await pumpClippingApp(
      tester,
      size: const Size(375, 812),
      editor: ImageClipEditor(
        initialImageBytes: _pngBytes(375, 456),
        initialImageLabel: 'figma-layout.png',
        loadSampleOnStart: false,
      ),
    );
    await pumpUntilIdle(tester);

    final titleRect = tester.getRect(find.text('Position'));
    final closeHitRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_close_hit_area')),
    );
    final closeIconRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_close_icon')),
    );
    final saveRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_save_action')),
    );
    final fillRect = tester.getRect(find.text('Fill'));
    final rotateRect = tester.getRect(find.text('Rotate'));

    expect(titleRect.left, 16);
    expect(titleRect.top, closeTo(14, 1));
    expect(closeHitRect.left, 315);
    expect(closeHitRect.top, closeTo(6, 0.5));
    expect(closeHitRect.size, const Size(44, 44));
    expect(closeIconRect.left, 339);
    expect(closeIconRect.top, closeTo(18, 0.5));
    expect(closeIconRect.size, const Size(20, 20));
    expect(saveRect, const Rect.fromLTWH(16, 724, 343, 48));
    expect(fillRect.center.dx, closeTo(131, 1));
    expect(rotateRect.center.dx, closeTo(243, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('can configure crop area height', (tester) async {
    await pumpClippingApp(
      tester,
      size: const Size(375, 812),
      editor: ImageClipEditor(
        cropAreaHeight: 420,
        initialImageBytes: _pngBytes(375, 456),
        initialImageLabel: 'custom-height.png',
        loadSampleOnStart: false,
      ),
    );
    await pumpUntilIdle(tester);

    final cropAreaRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_crop_area')),
    );
    final saveRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_save_action')),
    );

    expect(cropAreaRect, const Rect.fromLTWH(0, 56, 375, 420));
    expect(saveRect, const Rect.fromLTWH(16, 688, 343, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('clamps configured crop area height on compact screens', (
    tester,
  ) async {
    await pumpClippingApp(
      tester,
      size: const Size(375, 390),
      editor: ImageClipEditor(
        cropAreaHeight: 420,
        initialImageBytes: _pngBytes(375, 456),
        initialImageLabel: 'compact-height.png',
        loadSampleOnStart: false,
      ),
    );
    await pumpUntilIdle(tester);

    final cropAreaRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_crop_area')),
    );
    final saveRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_save_action')),
    );

    expect(cropAreaRect, const Rect.fromLTWH(0, 56, 375, 154));
    expect(saveRect.top, 422);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fit mode centers the image inside the crop frame', (
    tester,
  ) async {
    await pumpClippingApp(
      tester,
      size: const Size(375, 812),
      editor: ImageClipEditor(
        initialImageBytes: _pngBytes(160, 120),
        initialImageLabel: 'fit-centered.png',
        loadSampleOnStart: false,
      ),
    );
    await pumpUntilIdle(tester);

    final imageRect = tester.getRect(find.byType(Image).first);
    final cropFrameRect = tester.getRect(
      find.byKey(const ValueKey('image_clip_editor_crop_frame')),
    );

    expect(imageRect.center.dx, closeTo(cropFrameRect.center.dx, 0.01));
    expect(imageRect.center.dy, closeTo(cropFrameRect.center.dy, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded sample supports drag, pinch, rotate, fill and save', (
    tester,
  ) async {
    await pumpClippingApp(tester);

    await tester.drag(find.byType(Image).first, const Offset(32, -24));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await pinchImage(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fill'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Rotate'));
    await pumpUntilIdle(tester);
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
    final controller = ImageClipEditorController();

    await pumpClippingApp(
      tester,
      editor: ImageClipEditor(
        controller: controller,
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

    await tester.runAsync(controller.flipHorizontal);
    await tester.pump();
    await tester.runAsync(controller.flipVertical);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(progressEvents, eventsAfterLoad);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scale button toggles between fit and fill modes', (
    tester,
  ) async {
    await pumpClippingApp(tester);

    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Fit'), findsNothing);

    await tester.tap(find.text('Fill'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fit'), findsOneWidget);
    expect(find.text('Fill'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Fit'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Fill'), findsOneWidget);
    expect(find.text('Fit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('save opens result page with crop metadata', (tester) async {
    final controller = ImageClipEditorController();

    await pumpClippingApp(
      tester,
      editor: ImageClipEditor(controller: controller),
    );

    await tester.tap(find.text('Rotate'));
    await pumpUntilIdle(tester);
    await tester.runAsync(controller.flipHorizontal);
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
      await tester.runAsync(controller.flipHorizontal);
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
          saveButton: 'Use photo',
          editorTitle: 'Arrange',
          positionHint: 'Move the image into place',
          fitButton: 'Contain',
          fillButton: 'Cover',
          flipHorizontalButton: 'Mirror H',
          flipVerticalButton: 'Mirror V',
          rotateButton: 'Turn',
        ),
        initialAspectRatio: ImageClipAspectRatio.square,
        aspectRatios: <ImageClipAspectRatio>[
          ImageClipAspectRatio.square,
          ImageClipAspectRatio.widescreen,
          ImageClipAspectRatio.ratio16x10,
          ImageClipAspectRatio.ratio10x16,
        ],
      ),
    );

    expect(find.text('Arrange'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    expect(find.text('Move the image into place'), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('Turn'), findsOneWidget);
    expect(find.text('1:1'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
    expect(find.text('16:10'), findsOneWidget);
    expect(find.text('10:16'), findsOneWidget);

    await tester.tap(find.text('Cover'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Contain'), findsOneWidget);
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
    final title = tester.widget<Text>(find.text('Position'));

    expect(scaffold.backgroundColor, background);
    expect(title.style?.color, primaryText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses requested default editor theme colors', (tester) async {
    const theme = ImageClipEditorTheme();

    expect(theme.cropBorderColor, const Color(0xFFFFFFFF));
    expect(theme.cropShadeColor, const Color(0x80000000));
    expect(theme.previewBackgroundColor, const Color(0xFFF8F9FA));
    expect(theme.imageBackgroundColor, const Color(0xFFF8F9FA));
    expect(theme.surfaceColor, const Color(0xFFFFFFFF));
    expect(theme.topBarHeight, 56);
    expect(theme.bottomBarHeight, 300);
    expect(theme.compactBottomBarHeight, 180);
    expect(theme.saveButtonHeight, 48);
  });

  test('copies editor theme layout tokens', () {
    const theme = ImageClipEditorTheme(
      topBarHeight: 64,
      bottomBarHeight: 320,
      compactBottomBarHeight: 196,
      bottomBarContentHeight: 336,
      bottomBarHorizontalPadding: 20,
      maxSaveButtonWidth: 300,
      saveButtonHeight: 52,
      saveButtonTop: 224,
      positionHintTop: 18,
      toolRowTop: 56,
      toolButtonGap: 36,
      aspectRatioRowTop: 128,
      aspectRatioGap: 18,
      aspectRatioGlyphBorderRadius: 4,
    );

    final copied = theme.copyWith(
      topBarHeight: 60,
      saveButtonHeight: 44,
      aspectRatioGap: 20,
    );

    expect(copied.topBarHeight, 60);
    expect(copied.bottomBarHeight, 320);
    expect(copied.compactBottomBarHeight, 196);
    expect(copied.bottomBarContentHeight, 336);
    expect(copied.bottomBarHorizontalPadding, 20);
    expect(copied.maxSaveButtonWidth, 300);
    expect(copied.saveButtonHeight, 44);
    expect(copied.saveButtonTop, 224);
    expect(copied.positionHintTop, 18);
    expect(copied.toolRowTop, 56);
    expect(copied.toolButtonGap, 36);
    expect(copied.aspectRatioRowTop, 128);
    expect(copied.aspectRatioGap, 20);
    expect(copied.aspectRatioGlyphBorderRadius, 4);
  });

  testWidgets(
    'light color scheme theme preserves default editor chrome colors',
    (tester) async {
      final theme = ImageClipEditorTheme.fromColorScheme(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D77),
          brightness: Brightness.light,
        ),
      );

      expect(theme.cropBorderColor, const Color(0xFFFFFFFF));
      expect(theme.cropShadeColor, const Color(0x80000000));
      expect(theme.previewBackgroundColor, const Color(0xFFF8F9FA));
      expect(theme.imageBackgroundColor, const Color(0xFFF8F9FA));
      expect(theme.surfaceColor, const Color(0xFFFFFFFF));
    },
  );

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
                result = await showImageClipEditor(
                  context,
                  labels: const ImageClipEditorLabels(
                    editorTitle: 'Arrange',
                    positionHint: 'Move the image into place',
                    saveButton: 'Use photo',
                    fillButton: 'Cover',
                    rotateButton: 'Turn',
                  ),
                );
              },
              child: const Text('open editor'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open editor'));
    await pumpUntilSampleLoads(tester);
    expect(find.text('Arrange'), findsOneWidget);
    expect(find.text('Move the image into place'), findsOneWidget);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('Turn'), findsOneWidget);
    expect(find.text('Use photo'), findsOneWidget);
    await tester.tap(find.text('Use photo'));
    await pumpUntilIdle(tester);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.cropped.bytes, isNotEmpty);
    expect(result!.region.width, greaterThan(0));
    expect(result!.region.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ratio presets switch without crashing', (tester) async {
    await pumpClippingApp(tester);

    await tester.tap(find.text('4:3'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('3:4'));
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

  testWidgets('restores initial crop position and derives its ratio', (
    tester,
  ) async {
    final controller = ImageClipEditorController();
    final imageBytes = _pngBytes(400, 300);
    const initialRegion = CropRegion(
      x: 50,
      y: 40,
      width: 200,
      height: 100,
      cornerRadius: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          initialImageBytes: imageBytes,
          initialImageLabel: 'restore-source.png',
          initialRotationDegrees: 90,
          initialCropRegion: initialRegion,
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      ),
    );
    await pumpUntilIdle(tester);
    await tester.pump();

    expect(find.text('1:2'), findsOneWidget);
    final restored = controller.currentCropRegion();
    expect(restored, isNotNull);
    expect(restored!.x, closeTo(initialRegion.x, 1));
    expect(restored.y, closeTo(initialRegion.y, 1));
    expect(restored.width, closeTo(initialRegion.width, 1));
    expect(restored.height, closeTo(initialRegion.height, 1));

    final result = await tester.runAsync(controller.crop);
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.rotationDegrees, 90);
    expect(result.sourceRegion, result.region);
    expect(result.transform, const ImageClipCropTransform(rotationDegrees: 90));
    expect(result.region.x, closeTo(initialRegion.x, 1));
    expect(result.region.y, closeTo(initialRegion.y, 1));
    expect(result.region.width, closeTo(initialRegion.width, 1));
    expect(result.region.height, closeTo(initialRegion.height, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('initial crop position does not override editor controls', (
    tester,
  ) async {
    final controller = ImageClipEditorController();
    final imageBytes = _pngBytes(400, 300);
    const initialRegion = CropRegion(
      x: 30,
      y: 20,
      width: 120,
      height: 80,
      cornerRadius: 0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          initialImageBytes: imageBytes,
          initialImageLabel: 'restore-source.png',
          initialCropRegion: initialRegion,
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      ),
    );
    await pumpUntilIdle(tester);
    await tester.pump();

    expect(
      _isCloseToRegion(controller.currentCropRegion(), initialRegion),
      isTrue,
    );

    await controller.rotateRight();
    await tester.pump();
    expect(
      _isCloseToRegion(controller.currentCropRegion(), initialRegion),
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey('image_clip_editor_close_hit_area')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(
      _isCloseToRegion(controller.currentCropRegion(), initialRegion),
      isFalse,
    );

    await tester.tap(find.text('Fill'));
    await tester.pump();
    expect(
      _isCloseToRegion(controller.currentCropRegion(), initialRegion),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores invalid initial crop sizes without crashing', (
    tester,
  ) async {
    final controller = ImageClipEditorController();

    await tester.pumpWidget(
      MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          initialImageBytes: _pngBytes(400, 300),
          initialImageLabel: 'invalid-restore-source.png',
          initialAspectRatio: ImageClipAspectRatio.square,
          initialCropRegion: const CropRegion(
            x: 10,
            y: 10,
            width: 0,
            height: -20,
            cornerRadius: 0,
          ),
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      ),
    );
    await pumpUntilIdle(tester);
    await tester.pump();

    expect(find.text('1:1'), findsOneWidget);
    expect(controller.currentCropRegion(), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('updates restored crop position when initial region changes', (
    tester,
  ) async {
    final controller = ImageClipEditorController();
    final imageBytes = _pngBytes(400, 300);
    const firstRegion = CropRegion(
      x: 40,
      y: 30,
      width: 160,
      height: 120,
      cornerRadius: 0,
    );
    const nextRegion = CropRegion(
      x: 120,
      y: 80,
      width: 200,
      height: 100,
      cornerRadius: 0,
    );

    Widget buildEditor(CropRegion region) {
      return MaterialApp(
        home: ImageClipEditor(
          controller: controller,
          initialImageBytes: imageBytes,
          initialImageLabel: 'restore-source.png',
          initialCropRegion: region,
          loadSampleOnStart: false,
          showResultPage: false,
        ),
      );
    }

    await tester.pumpWidget(buildEditor(firstRegion));
    await pumpUntilIdle(tester);
    await tester.pump();
    expect(controller.currentCropRegion()?.x, closeTo(firstRegion.x, 1));

    await tester.pumpWidget(buildEditor(nextRegion));
    await pumpUntilIdle(tester);
    await tester.pump();

    final restored = controller.currentCropRegion();
    expect(restored, isNotNull);
    expect(restored!.x, closeTo(nextRegion.x, 1));
    expect(restored.y, closeTo(nextRegion.y, 1));
    expect(restored.width, closeTo(nextRegion.width, 1));
    expect(restored.height, closeTo(nextRegion.height, 1));
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

bool _isCloseToRegion(CropRegion? actual, CropRegion expected) {
  if (actual == null) {
    return false;
  }
  const tolerance = 1;
  return (actual.x - expected.x).abs() <= tolerance &&
      (actual.y - expected.y).abs() <= tolerance &&
      (actual.width - expected.width).abs() <= tolerance &&
      (actual.height - expected.height).abs() <= tolerance;
}

Uint8List _pngBytes(int width, int height) {
  return Uint8List.fromList(
    img.encodePng(img.Image(width: width, height: height)),
  );
}

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
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
