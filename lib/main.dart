import 'package:flutter/material.dart';
import 'package:signbride/screens/edit_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: EditScreen());
  }
}




















/*import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Import the plugin's main class.
import 'package:hand_landmarker/hand_landmarker.dart';
import 'dart:isolate';
import 'hand_isolate.dart'; // your new file above

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Hand Landmarker Example',
      home: HandTrackerView(),
    );
  }
}

class HandTrackerView extends StatefulWidget {
  const HandTrackerView({super.key});

  @override
  State<HandTrackerView> createState() => _HandTrackerViewState();
}

class _HandTrackerViewState extends State<HandTrackerView> {
  CameraController? _controller;
  // List<Hand> _landmarks = [];
  final _handsNotifier = ValueNotifier<List<Hand>>([]);
  bool _isInitialized = false;
  bool _isDetecting = false;

  // Isolate handles
  Isolate? _isolate;
  SendPort? _isolateSendPort; // we send frames here
  ReceivePort? _setupPort; // used once during setup to get _isolateSendPort

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final camera = _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    // Spawn the isolate and wait for it to hand back its SendPort.
    _setupPort = ReceivePort();
    _isolate = await Isolate.spawn(handIsolateEntry, _setupPort!.sendPort);

    // The first message is always the background isolate's SendPort.
    _isolateSendPort = await _setupPort!.first as SendPort;
    _setupPort!.close();

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _isolateSendPort?.send('dispose');
    _isolate?.kill(priority: Isolate.immediate);
    _handsNotifier.dispose(); // ← dispose it
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isInitialized || _isolateSendPort == null) return;
    _isDetecting = true;

    try {
      // One-shot port for this frame's reply.
      final replyPort = ReceivePort();

      _isolateSendPort!.send(
        FrameRequest(
          image,
          _controller!.description.sensorOrientation,
          replyPort.sendPort,
        ),
      );

      final hands = await replyPort.first as List<Hand>;
      replyPort.close();

      if (mounted) {
        _handsNotifier.value = hands;
      }
    } catch (e) {
      debugPrint('Detection error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while initializing.
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final controller = _controller!;
    final previewSize = controller.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Hand Tracking')),
      body: Center(
        child: AspectRatio(
          aspectRatio: previewAspectRatio,
          child: Stack(
            children: [
              CameraPreview(controller),
              CustomPaint(
                // Tell the painter to fill the available space
                size: Size.infinite,
                painter: LandmarkPainter(
                  handsNotifier: _handsNotifier,
                  previewSize: previewSize,
                  lensDirection: controller.description.lensDirection,
                  sensorOrientation: controller.description.sensorOrientation,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A custom painter that renders the hand landmarks and connections.
class LandmarkPainter extends CustomPainter {
  LandmarkPainter({
    required this.handsNotifier,
    required this.previewSize,
    required this.lensDirection,
    required this.sensorOrientation,
  }) : super(repaint: handsNotifier); // ← this is the key line

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
  bool shouldRepaint(LandmarkPainter old) => false; // ← repaint is driven by notifier, not rebuilds
}

/// Helper class.
class HandLandmarkConnections {
  static const List<List<int>> connections = [
    [0, 1], [1, 2], [2, 3], [3, 4], // Thumb
    [0, 5], [5, 6], [6, 7], [7, 8], // Index finger
    [5, 9], [9, 10], [10, 11], [11, 12], // Middle finger
    [9, 13], [13, 14], [14, 15], [15, 16], // Ring finger
    [13, 17], [0, 17], [17, 18], [18, 19], [19, 20], // Pinky
  ];
}
*/

