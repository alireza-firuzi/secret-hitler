import 'package:audioplayers/audioplayers.dart';

enum SoundEvent {
  alarm,
  chancellorReceivesPolicies,
  clockTick,
  enactPolicy,
  fascistsWin,
  fascistsWinHitlerElected,
  liberalsWin,
  liberalsWinHitlerShow,
  playerShot,
  policyInvestigate,
  policyPeek,
  policySpecialElection,
  presidentReceivesPolicies,
  shuffle,
  vetoFails,
  vetoSucceeds,
}

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  static bool _muted = false;
  static bool get isMuted => _muted;

  static void setMuted(bool muted) {
    _muted = muted;
  }

  static Future<void> play(SoundEvent event) async {
    if (_muted) return;

    try {
      final player = AudioPlayer();
      final String fileName = _getFileName(event);
      // AssetSource assumes assets/ as default prefix
      await player.play(AssetSource('sounds/$fileName'));
      
      // Auto dispose player after playback completes to free resources
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      print("Error playing sound $event: $e");
    }
  }

  static String _getFileName(SoundEvent event) {
    switch (event) {
      case SoundEvent.alarm:
        return 'alarm.mp3';
      case SoundEvent.chancellorReceivesPolicies:
        return 'chancellorreceivespolicies.mp3';
      case SoundEvent.clockTick:
        return 'clockTick.mp3';
      case SoundEvent.enactPolicy:
        return 'enactpolicy.mp3';
      case SoundEvent.fascistsWin:
        return 'fascistswin.mp3';
      case SoundEvent.fascistsWinHitlerElected:
        return 'fascistswinhitlerelected.mp3';
      case SoundEvent.liberalsWin:
        return 'liberalswin.mp3';
      case SoundEvent.liberalsWinHitlerShow:
        return 'liberalswinhitlershow.mp3';
      case SoundEvent.playerShot:
        return 'playershot.mp3';
      case SoundEvent.policyInvestigate:
        return 'policyinvestigate.mp3';
      case SoundEvent.policyPeek:
        return 'policypeek.mp3';
      case SoundEvent.policySpecialElection:
        return 'policyspecialelection.mp3';
      case SoundEvent.presidentReceivesPolicies:
        return 'presidentreceivespolicies.mp3';
      case SoundEvent.shuffle:
        return 'shuffle.mp3';
      case SoundEvent.vetoFails:
        return 'vetofails.mp3';
      case SoundEvent.vetoSucceeds:
        return 'vetosucceeds.mp3';
    }
  }
}
