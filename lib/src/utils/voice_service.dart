import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service providing local-first Text-to-Speech (TTS) and Speech-to-Text (STT).
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  
  bool _isSttInitialized = false;

  /// Initializes the voice services.
  Future<void> initialize() async {
    // Configure TTS
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  /// Speaks the provided [text] using the device's local engine.
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _tts.speak(text);
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
  }

  /// Listens for user voice input and returns the recognized text.
  ///
  /// [onResult] is called as the user speaks (intermediate results).
  /// [onListeningChange] is called when the listening state changes.
  Future<void> listen({
    required void Function(String text) onResult,
    required void Function(bool isListening) onListeningChange,
  }) async {
    if (!_isSttInitialized) {
      final hasPermission = await Permission.microphone.request().isGranted;
      if (!hasPermission) {
        throw Exception("Microphone permission denied");
      }
      _isSttInitialized = await _stt.initialize();
    }

    if (!_isSttInitialized) {
      throw Exception("Speech recognition failed to initialize");
    }

    if (_stt.isListening) {
      await _stt.stop();
      onListeningChange(false);
      return;
    }

    onListeningChange(true);
    await _stt.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onListeningChange(false);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  /// Cancels any ongoing listening session.
  Future<void> stopListening() async {
    await _stt.stop();
  }

  /// Releases resources held by the voice services.
  Future<void> dispose() async {
    await _tts.stop();
    await _stt.cancel();
  }
}
