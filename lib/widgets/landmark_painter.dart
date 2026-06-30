import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_detection/hand_detection.dart';

class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
    required this.handsNotifier,
   // required this.previewSize,
    required this.lensDirection,
    //required this.sensorOrientation,
  }) : super(repaint: handsNotifier);

  final ValueNotifier<List<Hand>> handsNotifier;
  
  final CameraLensDirection lensDirection;
  

  static final Paint pointPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill;

  static final Paint linePaint = Paint()
    ..color = Colors.green
    ..strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final hands = handsNotifier.value;
    if (hands.isEmpty) return;

    // Detector image size (NOT CameraPreview size)
    final imageWidth = hands.first.imageWidth.toDouble();
    final imageHeight = hands.first.imageHeight.toDouble();

    // Same scaling used by CameraPreview
    final scale = math.max(size.width / imageWidth, size.height / imageHeight);

    final scaledWidth = imageWidth * scale;
    final scaledHeight = imageHeight * scale;

    final offsetX = (size.width - scaledWidth) / 2;
    final offsetY = (size.height - scaledHeight) / 2;

    Offset mapPoint(HandLandmark lm) {
      double x = lm.x;
      double y = lm.y;

      // Mirror for front camera
      if (lensDirection == CameraLensDirection.front) {
        x = imageWidth - x;
      }

      return Offset(x * scale + offsetX, y * scale + offsetY);
    }

    for (final hand in hands) {
      // Draw connections
      for (final connection in HandLandmarkConnections.connections) {
        final p1 = mapPoint(hand.landmarks[connection[0]]);
        final p2 = mapPoint(hand.landmarks[connection[1]]);

        canvas.drawLine(p1, p2, linePaint);
      }

      // Draw landmarks
      for (final lm in hand.landmarks) {
        canvas.drawCircle(mapPoint(lm), 5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkPainter oldDelegate) => true;
}

class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [0, 5],
    [5, 6],
    [6, 7],
    [7, 8],
    [5, 9],
    [9, 10],
    [10, 11],
    [11, 12],
    [9, 13],
    [13, 14],
    [14, 15],
    [15, 16],
    [13, 17],
    [0, 17],
    [17, 18],
    [18, 19],
    [19, 20],
  ];
}
