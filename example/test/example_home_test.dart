import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_image_clip_example/main.dart';

void main() {
  testWidgets(
    'toggles initialCropRegion without reusing an attached controller',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const ImageClipExampleApp());
      await tester.pump();
      await tester.ensureVisible(find.text('initialCropRegion'));
      await tester.tap(find.text('initialCropRegion'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
