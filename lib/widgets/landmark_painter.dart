import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
    required this.handsNotifier,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  }) : super(repaint: handsNotifier);

  final ValueNotifier<List<Hand>> handsNotifier;
  final Size previewSize;
  final CameraLensDirection lensDirection;
  final int sensorOrientation;

  static final _pointPaint = Paint()
    ..color = Colors.red
    ..strokeCap = StrokeCap.round;

  static final _linePaint = Paint()..color = Colors.lightBlueAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final hands = handsNotifier.value;
    if (hands.isEmpty) return;

    final scale = size.width / previewSize.height;
    _pointPaint.strokeWidth = 8 / scale;
    _linePaint.strokeWidth = 4 / scale;

    canvas.save();

    final center = Offset(size.width / 2, size.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sensorOrientation * math.pi / 180);

    if (lensDirection == CameraLensDirection.front) {
      canvas.scale(-1, 1);
      canvas.rotate(math.pi);
    }

    canvas.scale(scale);

    final logicalWidth = previewSize.width;
    final logicalHeight = previewSize.height;

    for (final hand in hands) {
      for (final connection in HandLandmarkConnections.connections) {
        final start = hand.landmarks[connection[0]];
        final end = hand.landmarks[connection[1]];
        canvas.drawLine(
          Offset(
            (start.x - 0.5) * logicalWidth,
            (start.y - 0.5) * logicalHeight,
          ),
          Offset((end.x - 0.5) * logicalWidth, (end.y - 0.5) * logicalHeight),
          _linePaint,
        );
      }
      for (final landmark in hand.landmarks) {
        canvas.drawCircle(
          Offset(
            (landmark.x - 0.5) * logicalWidth,
            (landmark.y - 0.5) * logicalHeight,
          ),
          8 / scale,
          _pointPaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(LandmarkPainter old) => false;
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

/// A custom painter that renders the hand landmarks and connections.
