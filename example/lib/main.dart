import 'package:flutter/material.dart';
import 'package:flutter_image_clip/flutter_image_clip.dart';

void main() {
  runApp(const ImageClipExampleApp());
}

class ImageClipExampleApp extends StatelessWidget {
  const ImageClipExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Clip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006D77)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F8),
      ),
      home: const ImageClipEditor(),
    );
  }
}
