import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads, transforms, crops, and returns a result', (tester) async {
    ImageClipResult? result;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ImageClipEditor(
          initialImageBytes: _pngBytes(320, 240),
          initialImageLabel: 'integration.png',
          loadSampleOnStart: false,
          showResultPage: false,
          labels: ImageClipEditorLabels.zhHans,
          previewDecodeSettings: const ImageClipDecodeSettings.preview(
            targetLongSide: 160,
          ),
          onResult: (value) {
            result = value;
          },
        ),
      ),
    );
    await _pumpUntilIdle(tester);

    await tester.tap(find.text('旋转'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水平翻转'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await _pumpUntilIdle(tester);

    expect(result, isNotNull);
    expect(result!.source.isPreviewSized, isTrue);
    expect(result!.cropped.bytes, isNotEmpty);
    expect(result!.rotationDegrees, 90);
    expect(result!.flippedHorizontally, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilIdle(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      return;
    }
  }
}

Uint8List _pngBytes(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgba(x, y, x % 255, y % 255, (x + y) % 255, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
