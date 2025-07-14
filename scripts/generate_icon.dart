import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// This script generates the app icon PNG file
/// Run with: dart scripts/generate_icon.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final iconWidget = Container(
    width: 1024,
    height: 1024,
    decoration: BoxDecoration(
      color: const Color(0xFF2196F3),
      borderRadius: BorderRadius.circular(180),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Main pill icon
        const Icon(
          Icons.medication,
          size: 500,
          color: Colors.white,
        ),
        // Plus sign
        Positioned(
          right: 150,
          top: 150,
          child: Container(
            width: 200,
            height: 200,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 120,
            ),
          ),
        ),
      ],
    ),
  );

  // Convert widget to image
  final repaintBoundary = RepaintBoundary(child: iconWidget);
  final renderRepaintBoundary = RenderRepaintBoundary();
  
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  
  final element = repaintBoundary.createElement();
  element.mount(null, null);
  
  buildOwner.buildScope(element);
  
  final renderObject = element.renderObject as RenderRepaintBoundary;
  pipelineOwner.rootNode = renderObject;
  
  renderObject.layout(const BoxConstraints.tightFor(width: 1024, height: 1024));
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  
  final image = await renderObject.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  
  if (byteData != null) {
    final file = File('assets/icon/app_icon.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    print('App icon generated successfully at: ${file.path}');
  } else {
    print('Failed to generate app icon');
  }
  
  element.unmount();
}
