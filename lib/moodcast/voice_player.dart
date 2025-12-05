// lib/moodcast/voice_player.dart
// Piper TTS (Play + Stop) — LOCAL SERVER VERSION

import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

class PiperPlayer {
  static final AudioPlayer _player = AudioPlayer();

  // Clean text for safer TTS processing
  static String _clean(String input) {
    return input
        .replaceAll(RegExp(r'[\n\r\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // -------------------------------------------------------------
  // PLAY TTS (Piper)
  // -------------------------------------------------------------
  static Future<void> speak(String rawText, {String voice = "cori"}) async {
    try {
      await _player.stop();

      final text = _clean(rawText);

      final url = Uri.parse(
        "https://auranaguidance.co.uk/api/tts/piper",
      );

      final request = http.MultipartRequest("POST", url);
      request.fields["text"] = text;
      request.fields["voice"] = voice; // "cori" or "ryan"

      final streamed = await request.send();

      if (streamed.statusCode != 200) {
        print("❌ Piper error: ${streamed.statusCode}");
        return;
      }

      final bytes = await streamed.stream.toBytes();
      await _player.play(BytesSource(bytes));

    } catch (e) {
      print("❌ Piper exception: $e");
    }
  }

  // -------------------------------------------------------------
  // STOP
  // -------------------------------------------------------------
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      print("❌ Stop error: $e");
    }
  }
}
