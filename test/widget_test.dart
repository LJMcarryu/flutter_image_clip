import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Portrait'), findsOneWidget);
    expect(find.text('Landscape'), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);
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
    await tester.tap(find.text('Save'));
    await pumpUntilIdle(tester);
    await tester.pumpAndSettle();

    expect(find.text('Crop result'), findsOneWidget);
    expect(find.text('Crop details'), findsOneWidget);
    expect(find.text('Rotation'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
    expect(find.text('Result data'), findsOneWidget);
    expect(find.textContaining('rotationDegrees: 90'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports custom labels and aspect ratio presets', (
    tester,
  ) async {
    await pumpClippingApp(
      tester,
      editor: const ImageClipEditor(
        labels: ImageClipEditorLabels(
          cancelButton: 'Dismiss',
          saveButton: 'Crop',
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
    expect(find.text('Turn'), findsOneWidget);
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('16:9'), findsOneWidget);
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
}
