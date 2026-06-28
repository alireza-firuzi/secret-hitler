import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'dart:js' as js;

enum SoundEvent {
  alarm,
  enactPolicy,
  fascistsWin,
  fascistsWinHitlerElected,
  liberalsWin,
  liberalsWinHitlerShow,
  playerShot,
  policyInvestigate,
  policySpecialElection,
  presidentReceivesPolicies,
  vetoFails,
  vetoSucceeds,
}

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();
  factory SoundManager() => _instance;
  SoundManager._internal();

  static bool _muted = false;
  static bool get isMuted => _muted;

  static AudioPlayer? _loopPlayer;
  static AudioPlayer? _soundPlayer;
  static AudioPlayer? _speechPlayer;

  static void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      stopLoop();
      if (_soundPlayer != null) {
        try {
          _soundPlayer!.stop();
          _soundPlayer!.dispose();
        } catch (_) {}
        _soundPlayer = null;
      }
      if (_speechPlayer != null) {
        try {
          _speechPlayer!.stop();
          _speechPlayer!.dispose();
        } catch (_) {}
        _speechPlayer = null;
      }
    }
  }

  static Future<void> play(SoundEvent event) async {
    if (_muted) return;

    try {
      if (_soundPlayer != null) {
        try {
          await _soundPlayer!.stop();
          await _soundPlayer!.dispose();
        } catch (_) {}
        _soundPlayer = null;
      }

      final player = AudioPlayer();
      _soundPlayer = player;
      final String fileName = _getFileName(event);
      // AssetSource assumes assets/ as default prefix
      await player.play(AssetSource('sounds/$fileName'));
      
      // Auto dispose player after playback completes to free resources
      player.onPlayerComplete.listen((_) {
        if (_soundPlayer == player) {
          _soundPlayer = null;
        }
        try {
          player.dispose();
        } catch (_) {}
      });
    } catch (e) {
      print("Error playing sound $event: $e");
    }
  }

  static Future<void> playSpeech(String text) async {
    if (_muted || text.trim().isEmpty) return;

    try {
      String protocol = 'http';
      String serverHost = 'localhost:3000';
      String apiPath = '/api/tts';

      if (kIsWeb) {
        final uri = Uri.base;
        protocol = uri.scheme == 'https' ? 'https' : 'http';
        if (uri.host != 'localhost' && uri.host != '127.0.0.1' && uri.host.isNotEmpty) {
          serverHost = uri.host;
          apiPath = '/secret-hitler/api/tts';
        }
      }

      final String encodedText = Uri.encodeComponent(text);
      final String url = '$protocol://$serverHost$apiPath?text=$encodedText';

      if (_speechPlayer != null) {
        try {
          await _speechPlayer!.stop();
          await _speechPlayer!.dispose();
        } catch (_) {}
        _speechPlayer = null;
      }

      final player = AudioPlayer();
      _speechPlayer = player;
      await player.play(UrlSource(url));

      player.onPlayerComplete.listen((_) {
        if (_speechPlayer == player) {
          _speechPlayer = null;
        }
        try {
          player.dispose();
        } catch (_) {}
      });
    } catch (e) {
      print("Error playing speech: $e");
    }
  }

  static Future<void> startLoop(SoundEvent event) async {
    if (_muted) return;

    try {
      await stopLoop(); // Stop any existing loop
      _loopPlayer = AudioPlayer();
      await _loopPlayer!.setReleaseMode(ReleaseMode.loop);
      final String fileName = _getFileName(event);
      await _loopPlayer!.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      print("Error starting loop $event: $e");
    }
  }

  static Future<void> stopLoop() async {
    try {
      if (_loopPlayer != null) {
        await _loopPlayer!.stop();
        await _loopPlayer!.dispose();
        _loopPlayer = null;
      }
    } catch (e) {
      print("Error stopping loop: $e");
    }
  }

  static String _getFileName(SoundEvent event) {
    switch (event) {
      case SoundEvent.alarm:
        return 'alarm.mp3';
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
      case SoundEvent.policySpecialElection:
        return 'policyspecialelection.mp3';
      case SoundEvent.presidentReceivesPolicies:
        return 'presidentreceivespolicies.mp3';
      case SoundEvent.vetoFails:
        return 'vetofails.mp3';
      case SoundEvent.vetoSucceeds:
        return 'vetosucceeds.mp3';
    }
  }
}
