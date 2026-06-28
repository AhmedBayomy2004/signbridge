import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'package:signbride/data/data.dart';
import 'package:signbride/services/hand_isolate.dart';
import 'package:signbride/services/csv_file_service.dart';
import 'package:signbride/services/tflite_sevice.dart';
import 'package:signbride/widgets/landmark_painter.dart';
import 'package:signbride/widgets/ouput_confidence_card.dart';

late List<CameraDescription> _cameras;

class HandTrackerScreen extends StatefulWidget {
  const HandTrackerScreen({super.key, required this.isVideo});
  final bool isVideo;

  @override
  State<HandTrackerScreen> createState() => _HandTrackerScreenState();
}

class _HandTrackerScreenState extends State<HandTrackerScreen> {
  CameraController? _controller;
  CameraDescription? _currentCamera;

  Isolate? _isolate;
  SendPort? _isolateSendPort;
  ReceivePort? _setupPort;

  final _handsNotifier = ValueNotifier<List<Hand>>([]);
  final _outputWordNotifier = ValueNotifier<String>('No output');
  final _confidenceNotifier = ValueNotifier<double>(0.0);

  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isModelLoaded = false;
  bool _isInferring = false;

  final Queue<List<double>> buffer = Queue();
  List<String> classes = [];
  List<double> _meanList = [];
  List<double> _stdList = [];

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _loadNormalizationData(); // normalization only for video model
    }
    _loadClassesData();
    _initModel();
    _initTrackingSystem(); // Unified setup flow
  }

  void _loadClassesData() {
    classes = widget.isVideo
        ? Data.videoModelClasses
        : Data.pictureModelClasses;
  }

  void _loadNormalizationData() async {
    final meanRaw = await CsvFileService.readSingleColumnCsv(
      'assets/normalization/mean.csv',
    );
    _meanList = meanRaw.map((e) => double.parse(e.toString())).toList();
    _meanList.removeAt(0);

    final stdRaw = await CsvFileService.readSingleColumnCsv(
      'assets/normalization/std.csv',
    );
    _stdList = stdRaw.map((e) => double.parse(e.toString())).toList();
    _stdList.removeAt(0);
  }

  void _initModel() async {
    try {
      await TFLiteService.loadModel(isVideo: widget.isVideo);
      if (mounted) setState(() => _isModelLoaded = true);
    } catch (e) {
      debugPrint("Model load error: $e");
    }
  }

  Future<void> _initTrackingSystem() async {
    _cameras = await availableCameras();

    // Default to front camera
    _currentCamera ??= _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      _currentCamera!,
      ResolutionPreset.low,
      enableAudio: false,
    );

    _setupPort = ReceivePort();
    await Isolate.spawn(handIsolateEntry, [
      _setupPort!.sendPort,
      widget.isVideo,
    ]);
    _isolateSendPort = await _setupPort!.first as SendPort;
    _setupPort!.close();

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return; // can't switch if only one camera exists

    if (mounted) setState(() => _isInitialized = false);

    // Clean up current running camera and the isolates
    await _controller?.stopImageStream();
    await _controller?.dispose();
    _isolateSendPort?.send('dispose');
    _isolate?.kill(priority: Isolate.immediate);

    final newLensDirection =
        _currentCamera!.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    _currentCamera = _cameras.firstWhere(
      (cam) => cam.lensDirection == newLensDirection,
      orElse: () => _cameras.first,
    );

    buffer.clear();
    _handsNotifier.value = [];
    await _initTrackingSystem();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _isolateSendPort?.send('dispose');
    _isolate?.kill(priority: Isolate.immediate);
    _handsNotifier.dispose();
    _outputWordNotifier.dispose();
    _confidenceNotifier.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isModelLoaded ||
        _isDetecting ||
        !_isInitialized ||
        _isolateSendPort == null) {
      return;
    }

    _isDetecting = true;

    try {
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

      _handsNotifier.value = hands;

      if (buffer.length == 20 || (!widget.isVideo && buffer.isNotEmpty)) {
        buffer.removeFirst(); // picture model requires only one frame
      }

      if (hands.isEmpty) {
        buffer.add(
          List.filled(widget.isVideo ? 126 : 63, 0.0),
        ); // picture model only takes one hand (63 values)
      } else if (!widget.isVideo) {
        List<double> frame = hands[0].landmarks
            .map((lm) => [lm.x, lm.y, lm.z])
            .expand((e) => e)
            .toList();
        buffer.add(frame);
      } else {
        List<double> leftHandFrame = List.filled(63, 0.0);
        List<double> rightHandFrame = List.filled(63, 0.0);

        for (var hand in hands) {
          List<double> landmarks = hand.landmarks
              .map((lm) => [lm.x, lm.y, lm.z])
              .expand((e) => e)
              .toList();

          double thumbMcpX = hand.landmarks[2].x;
          double pinkyMcpX = hand.landmarks[17].x;
          bool isRightHand = thumbMcpX < pinkyMcpX;

          if (isRightHand) {
            rightHandFrame = landmarks;
          } else {
            leftHandFrame = landmarks;
          }
        }

        List<double> frame = [...leftHandFrame, ...rightHandFrame];

        int currentIndex = 0;
        frame = frame.map((value) {
          double normalizedValue =
              (value - _meanList[currentIndex]) / _stdList[currentIndex];
          currentIndex++;
          return normalizedValue;
        }).toList();

        buffer.add(frame);
      }

      if ((buffer.length == 20 || !widget.isVideo) && !_isInferring) {
        _isInferring = true;
        processOutput().then((_) {
          _isInferring = false;
        });
      }
    } catch (e) {
      debugPrint('Error detecting landmarks: $e');
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> processOutput() async {
    if (buffer.length < 20 && widget.isVideo) return;

    final input = [buffer.toList()];
    final output = widget.isVideo
        ? await TFLiteService.runVideoInference(input)
        : await TFLiteService.runPictureInference(input[0]);

    if (output.isEmpty) return;

    int maxIndex = 0;
    double maxValue = output[0];
    for (int i = 1; i < output.length; i++) {
      if (output[i] > maxValue) {
        maxValue = output[i];
        maxIndex = i;
      }
    }
    _outputWordNotifier.value = classes[maxIndex];
    _confidenceNotifier.value = maxValue;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                size: Size.infinite,
                painter: LandmarkPainter(
                  handsNotifier: _handsNotifier,
                  previewSize: previewSize,
                  lensDirection: controller.description.lensDirection,
                  sensorOrientation: controller.description.sensorOrientation,
                ),
              ),

              // camera toggle button
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.small(
                  heroTag: 'camera_toggle',
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                  onPressed: _toggleCamera,
                  child: const Icon(Icons.flip_camera_ios),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _outputWordNotifier,
                    _confidenceNotifier,
                  ]),
                  builder: (context, _) => OutputConfidenceCard(
                    output: _outputWordNotifier.value,
                    confidence: _confidenceNotifier.value,
                    primaryColor: widget.isVideo
                        ? const Color(0xff5D5FEF)
                        : const Color(0xffFFC857),
                    secondaryColor: widget.isVideo
                        ? const Color(0xff7d7ef1)
                        : const Color(0xffFFD97D),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
