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
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ImageClipEditor(),
      ),
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

    expect(find.text('裁剪结果'), findsOneWidget);
    expect(find.text('截图信息'), findsOneWidget);
    expect(find.text('旋转角度'), findsOneWidget);
    expect(find.text('90°'), findsOneWidget);
    expect(find.text('返回数据'), findsOneWidget);
    expect(find.textContaining('rotationDegrees: 90'), findsOneWidget);
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
