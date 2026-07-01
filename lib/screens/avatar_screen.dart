import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:speech_to_text/speech_to_text.dart';

class AvatarScreen extends StatefulWidget {
  const AvatarScreen({super.key});

  @override
  State<AvatarScreen> createState() => _AvatarScreenState();
}

class _AvatarScreenState extends State<AvatarScreen> {
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;
  bool _speechInitialized = false;
  String _recognizedText = "";
  String _lastSentText = "";

  Timer? _watchdogTimer;
  DateTime _lastActivity = DateTime.now();

  static const _watchdogInterval = Duration(seconds: 8);
  static const _staleThreshold = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  Future<void> _initializeSpeech() async {
    _speechInitialized = await _speech.initialize(
      onStatus: (status) {
        _lastActivity = DateTime.now();
      },
      onError: (error) {
        _lastActivity = DateTime.now();
      },
    );
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastActivity = DateTime.now();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) async {
      if (!_isListening) return;

      final stale = DateTime.now().difference(_lastActivity) > _staleThreshold;
      final notActuallyListening = !_speech.isListening;

      if (stale || notActuallyListening) {
        await _forceRestart();
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  Future<void> _forceRestart() async {
    try {
      await _speech.cancel();
    } catch (_) {}

    // إعادة init كاملة أضمن من مجرد listen تاني بعد stall
    _speechInitialized = false;
    await _initializeSpeech();

    if (_isListening && _speechInitialized) {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_speechInitialized) return;
    if (_speech.isListening) return;

    _lastActivity = DateTime.now();

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'ar',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
        // pauseFor: const Duration(minutes: 5),
        // listenFor: const Duration(minutes: 30),
      ),
      onResult: (result) {
        _lastActivity = DateTime.now();

        if (!mounted) return;

        setState(() {
          _recognizedText = result.recognizedWords;
        });

        // ابعت الجملة مرة واحدة فقط بعد انتهاء التعرف عليها
        if (result.finalResult &&
            result.recognizedWords.isNotEmpty &&
            result.recognizedWords != _lastSentText) {
          _lastSentText = result.recognizedWords;
          _sendTextToAvatar(_lastSentText);
        }
      },
    );
  }

  Future<void> _toggleListening() async {
    if (!_speechInitialized) return;

    if (!_isListening) {
      setState(() => _isListening = true);
      await _startListening();
      _startWatchdog();
    } else {
      setState(() => _isListening = false);
      _stopWatchdog();
      await _speech.stop();
    }
  }

  void _sendTextToAvatar(String text) {
    debugPrint("Avatar should say: $text");

    sendToUnity('AppManager', 'ReceiveSentenceFromFlutter', text);
  }

  @override
  void dispose() {
    _stopWatchdog();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xffF8FAFC),
        foregroundColor: const Color(0xff1E293B),
        centerTitle: true,
        title: const Text(
          "Avatar",
          style: TextStyle(fontFamily: "Lexend", fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Talk with your Avatar",
                style: TextStyle(
                  fontFamily: "Lexend",
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1E293B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Speak naturally and the avatar will translate your speech into sign language.",
                style: TextStyle(
                  fontFamily: "Lexend",
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 20),

              /// Avatar Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withAlpha((0.15 * 255).round()),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const EmbedUnity(),
                ),
              ),

              const SizedBox(height: 20),

              /// Recognized Text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withAlpha((0.15 * 255).round()),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recognized Speech",
                      style: TextStyle(
                        fontFamily: "Lexend",
                        fontWeight: FontWeight.bold,
                        color: Color(0xff00B894),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _recognizedText.isEmpty
                          ? "Start speaking..."
                          : _recognizedText,
                      style: const TextStyle(
                        fontFamily: "Lexend",
                        fontSize: 18,
                        color: Color(0xff1E293B),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              /// Status
              Center(
                child: Text(
                  _isListening ? "Listening..." : "Tap the microphone to start",
                  style: TextStyle(
                    fontFamily: "Lexend",
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? const Color(0xff00B894) : Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              /// Mic Button
              Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: _isListening ? 85 : 75,
                    width: _isListening ? 85 : 75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening
                          ? Colors.redAccent
                          : const Color(0xff00B894),
                      boxShadow: [
                        BoxShadow(
                          // Avoid deprecated withOpacity by using withAlpha
                          color:
                              (_isListening
                                      ? Colors.redAccent
                                      : const Color(0xff00B894))
                                  .withAlpha((0.35 * 255).round()),
                          blurRadius: 18,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
