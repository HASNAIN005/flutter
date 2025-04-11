import 'package:audioplayers/audioplayers.dart';

class SoundPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playSound(String assetPath) async {
    try {
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }
}
