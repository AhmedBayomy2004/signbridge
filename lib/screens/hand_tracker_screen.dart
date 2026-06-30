import 'dart:collection';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:hand_detection/hand_detection.dart'; // ← بدل hand_landmarker
import 'package:signbride/data/data.dart';
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
  CameraController? _cameraController;
  CameraDescription? _currentCamera;

  // ← حذفنا كل متغيرات الـ Isolate (Isolate, SendPort, ReceivePort)
  HandDetector? _detector; // ← ده الجديد بدل الـ isolate

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
      _loadNormalizationData();
    }
    _loadClassesData();
    _initModel();
    _initTrackingSystem();
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

    _currentCamera ??= _cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      _currentCamera!,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420, // ← مهم لأندرويد
    );

    // ← بدل Isolate.spawn، بنعمل HandDetector مباشرة
    _detector = await HandDetector.create(maxDetections: 2, detectorConf: 0.8);

    await _cameraController!.initialize();
    await _cameraController!.startImageStream(_processCameraImage);

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;

    if (mounted) setState(() => _isInitialized = false);

    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();

    // ← بدل kill الـ isolate، بندي dispose للـ detector
    await _detector?.dispose();
    _detector = null;

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
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _detector?.dispose(); // ← بدل kill الـ isolate
    _handsNotifier.dispose();
    _outputWordNotifier.dispose();
    _confidenceNotifier.dispose();
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_isModelLoaded ||
        _isDetecting ||
        !_isInitialized ||
        _detector == null) {
      return;
    }

    _isDetecting = true;

    try {
      // ← بدل FrameRequest والـ SendPort، بنكلم الـ detector مباشرة
      final hands = await _detector!.detectFromCameraImage(
        image,
        rotation: _getRotation(
          _cameraController!.description.sensorOrientation,
        ),
        maxDim: 640,
      );

      _handsNotifier.value = hands;

      if (buffer.length >= 20 || (!widget.isVideo && buffer.isNotEmpty)) {
        buffer.removeFirst();
      }

      if (hands.isEmpty) {
        buffer.add(List.filled(widget.isVideo ? 126 : 63, 0.0));
      } else if (!widget.isVideo) {
        Hand hand =
            (hands.length == 2 &&
                hands[1].handedness ==
                    Handedness
                        .right) // prefer right hand if both hands detected
            ? hands[1]
            : hands[0]; // take the first hand if only one hand detected

        List<double> frame = hand.landmarks
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

          double centerX = 0, centerY = 0, centerZ = 0;
          for (int i = 0; i < 63; i += 3) {
            centerX += landmarks[i];
            centerY += landmarks[i + 1];
            centerZ += landmarks[i + 2];
          }
          centerX /= 21;
          centerY /= 21;
          centerZ /= 21;

          double maxDistance = 0;
          for (int i = 0; i < 63; i += 3) {
            landmarks[i] -= centerX;
            landmarks[i + 1] -= centerY;
            landmarks[i + 2] -= centerZ;

            double distance = sqrt(
              landmarks[i] * landmarks[i] +
                  landmarks[i + 1] * landmarks[i + 1] +
                  landmarks[i + 2] * landmarks[i + 2],
            );
            if (distance > maxDistance) maxDistance = distance;
          }

          if (maxDistance > 0) {
            for (int i = 0; i < 63; i++) {
              landmarks[i] /= maxDistance;
            }
          }

          // ← hand.handedness في hand_detection بترجع Handedness.left أو Handedness.right
          if (hand.handedness == Handedness.right) {
            rightHandFrame = landmarks;
          } else {
            leftHandFrame = landmarks;
          }
        }

        buffer.add([...leftHandFrame, ...rightHandFrame]);
      }

      if ((buffer.length == 20 || !widget.isVideo) && !_isInferring) {
        _isInferring = true;
        processOutput().then((_) => _isInferring = false);
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

    final cameraController = _cameraController!;
    final previewSize = cameraController.value.previewSize!;
    final previewAspectRatio = previewSize.height / previewSize.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Live Hand Tracking')),
      body: Center(
        child: AspectRatio(
          aspectRatio: previewAspectRatio,
          child: Stack(
            children: [
              CameraPreview(cameraController),
              CustomPaint(
                size: Size.infinite,
                painter: LandmarkPainter(
                  handsNotifier: _handsNotifier,

                  lensDirection: cameraController.description.lensDirection,
                ),
              ),
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

CameraFrameRotation? _getRotation(int sensorOrientation) {
  switch (sensorOrientation) {
    case 90:
      return CameraFrameRotation.cw90;
    case 180:
      return CameraFrameRotation.cw180;
    case 270:
      return CameraFrameRotation.cw270;
    case 0:
    default:
      return null;
  }
}
