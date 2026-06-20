import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'firebase_manager.dart';
import '../models/game_state.dart';
import 'sound_manager.dart';

class OnlineGameEngine extends ChangeNotifier {
  final String lobbyCode;
  final String localPlayerId;
  final String localPlayerName;

  Map<String, dynamic> _gameData = {};
  Map<String, dynamic> _privateRoleData = {};
  StreamSubscription? _subscription;
  bool _isLoading = true;

  OnlineGameEngine({
    required this.lobbyCode,
    required this.localPlayerId,
    required this.localPlayerName,
  }) {
    _subscribe();
    _fetchPrivateRole();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  bool _isTallying = false;

  void _subscribe() {
    _subscription = FirebaseManager.streamGame(lobbyCode, localPlayerId).listen((data) {
      if (data != null) {
        final previousStatus = _gameData['status'];
        final previousPhase = _gameData['phase'];
        final previousFas = _gameData['fascistPolicies'] ?? 0;
        final previousLib = _gameData['liberalPolicies'] ?? 0;
        final previousVotesCount = (_gameData['votes'] as Map?)?.length ?? 0;

        _gameData = data;
        _isLoading = false;

        // Trigger sounds based on state diffs
        if (status == 'playing') {
          if (previousStatus == 'lobby') {
            SoundManager.play(SoundEvent.shuffle);
          } else {
            // Check changes during play
            final currentPhase = phaseStr;
            final currentFas = fascistPolicies;
            final currentLib = liberalPolicies;
            final currentVotesCount = votes.length;
            final currentInvestigated = investigatedPlayerIndex;
            final currentAlive = alivePlayersCount;

            final previousInvestigated = _gameData['investigatedPlayerIndex'] ?? -1;
            final previousAlive = (_gameData['players'] as List?)?.where((p) => p['isAlive'] == true).length ?? 0;

            if (currentPhase != previousPhase) {
              if (previousPhase == 'electionVoting') {
                if (currentPhase == 'legislativePresident' || 
                    (currentPhase == 'gameOver' && winReason != null && winReason!.contains('elected'))) {
                  SoundManager.play(SoundEvent.vetoSucceeds);
                } else {
                  SoundManager.play(SoundEvent.vetoFails);
                }
              }

              if (currentPhase == 'roleReveal') {
                SoundManager.play(SoundEvent.shuffle);
              } else if (currentPhase == 'electionNomination') {
                SoundManager.play(SoundEvent.shuffle);
              } else if (currentPhase == 'electionVoting') {
                // Silent
              } else if (currentPhase == 'legislativePresident') {
                SoundManager.play(SoundEvent.presidentReceivesPolicies);
              } else if (currentPhase == 'legislativeChancellor') {
                SoundManager.play(SoundEvent.chancellorReceivesPolicies);
              } else if (currentPhase == 'executiveAction') {
                SoundManager.play(SoundEvent.alarm);
              } else if (currentPhase == 'gameOver') {
                if (winner == 'Liberals') {
                  if (winReason != null && winReason!.contains('executed')) {
                    SoundManager.play(SoundEvent.liberalsWinHitlerShow);
                  } else {
                    SoundManager.play(SoundEvent.liberalsWin);
                  }
                } else if (winner == 'Fascists') {
                  if (winReason != null && winReason!.contains('elected')) {
                    SoundManager.play(SoundEvent.fascistsWinHitlerElected);
                  } else {
                    SoundManager.play(SoundEvent.fascistsWin);
                  }
                }
              }
            } else {
              // Same phase, check action diffs
              if (currentFas > previousFas) {
                SoundManager.play(SoundEvent.alarm);
              } else if (currentLib > previousLib) {
                SoundManager.play(SoundEvent.enactPolicy);
              } else if (currentInvestigated != previousInvestigated && currentInvestigated != -1) {
                SoundManager.play(SoundEvent.policyInvestigate);
              } else if (currentAlive < previousAlive) {
                SoundManager.play(SoundEvent.playerShot);
              }
            }
          }
        }

        // If the game just started (lobby -> playing), fetch private role details
        if (data['status'] == 'playing' && (previousStatus == 'lobby' || _privateRoleData.isEmpty)) {
          _fetchPrivateRole();
        }

        // Tally check: Host (if alive and connected) or current President (as fallback)
        if (phaseStr == 'electionVoting' && votes.length >= alivePlayersCount) {
          final hostPlayer = players.firstWhere((p) => p['id'] == hostId, orElse: () => null);
          final bool isHostActive = hostPlayer != null && hostPlayer['isAlive'] == true && hostPlayer['isDisconnected'] != true;
          
          final bool shouldITally = isHostActive ? isHost : isMyTurnPresident;
          if (shouldITally) {
            _triggerHostTally();
          }
        }

        notifyListeners();
      }
    });
  }

  void _triggerHostTally() {
    if (_isTallying) return;
    _isTallying = true;
    tallyVotes().then((_) {
      _isTallying = false;
    }).catchError((err) {
      _isTallying = false;
      print("Error tallying votes: $err");
    });
  }

  Future<void> _fetchPrivateRole() async {
    final roleData = await FirebaseManager.getPrivateRole(lobbyCode, localPlayerId);
    if (roleData != null) {
      _privateRoleData = roleData;
      notifyListeners();
    }
  }

  // Getters
  bool get isLoading => _isLoading;
  String get status => _gameData['status'] ?? 'lobby';
  String get hostId => _gameData['hostId'] ?? '';
  bool get isHost => localPlayerId == hostId;

  int get powerExecutorIndex {
    if (phaseStr != 'executiveAction') return -1;
    if (fascistPolicies == 3) {
      return chancellorIndex;
    }
    return presidentIndex;
  }

  bool get isMyTurnToExecutePower {
    if (phaseStr != 'executiveAction') return false;
    final executorIndex = powerExecutorIndex;
    if (executorIndex == -1 || executorIndex >= players.length) return false;
    return players[executorIndex]['id'] == localPlayerId && amIAlive;
  }

  List<dynamic> get players => _gameData['players'] ?? [];
  List<dynamic> get playerIds => _gameData['playerIds'] ?? [];
  int get liberalPolicies => _gameData['liberalPolicies'] ?? 0;
  int get fascistPolicies => _gameData['fascistPolicies'] ?? 0;
  int get electionTracker => _gameData['electionTracker'] ?? 0;
  int get presidentIndex => _gameData['presidentIndex'] ?? 0;
  int get chancellorIndex => _gameData['chancellorIndex'] ?? -1;
  int get nominatedChancellorIndex => _gameData['nominatedChancellorIndex'] ?? -1;
  int get previousPresidentIndex => _gameData['previousPresidentIndex'] ?? -1;
  int get previousChancellorIndex => _gameData['previousChancellorIndex'] ?? -1;
  String get phaseStr => _gameData['phase'] ?? 'setup';
  String get activePowerStr => _gameData['activePower'] ?? 'none';
  Map<String, dynamic> get votes => Map<String, dynamic>.from(_gameData['votes'] ?? {});
  List<dynamic> get drawnPolicies => _gameData['drawnPolicies'] ?? [];
  List<dynamic> get logs => _gameData['logs'] ?? [];
  String? get winner => _gameData['winner'];
  String? get winReason => _gameData['winReason'];
  String? get investigatedParty => _gameData['investigatedParty'];
  int get investigatedPlayerIndex => _gameData['investigatedPlayerIndex'] ?? -1;
  Map<String, dynamic>? get lastElectionResult => _gameData['lastElectionResult'];

  // Private role details
  String get myRoleName => _privateRoleData['role'] ?? 'Unknown';
  String get myPartyName => _privateRoleData['party'] ?? 'Unknown';
  String get myTeammateInfo => _privateRoleData['teammateInfo'] ?? '';

  int get alivePlayersCount => players.where((p) => p['isAlive'] == true).length;

  bool get amIAlive {
    final me = players.firstWhere((p) => p['id'] == localPlayerId, orElse: () => null);
    return me != null ? me['isAlive'] == true : false;
  }

  bool get isMyTurnPresident {
    if (phaseStr == 'gameOver') return false;
    if (players.isEmpty || presidentIndex >= players.length) return false;
    return players[presidentIndex]['id'] == localPlayerId && amIAlive;
  }

  bool get isMyTurnChancellor {
    if (phaseStr == 'gameOver') return false;
    if (chancellorIndex == -1 || chancellorIndex >= players.length) return false;
    return players[chancellorIndex]['id'] == localPlayerId && amIAlive;
  }

  // Lobby actions
  Future<void> startGame() async {
    if (!isHost) return;
    if (players.length < 5 || players.length > 10) return;

    // 1. Generate Roles & Shuffled Deck
    final playerCount = players.length;
    final List<String> roles = _generateRolesForCount(playerCount);
    roles.shuffle();

    // 2. Prepare Private Roles map
    final Map<String, Map<String, dynamic>> privateRolesMap = {};
    for (int i = 0; i < playerCount; i++) {
      final String playerId = players[i]['id'];
      final String role = roles[i];
      final String party = (role == 'Liberal') ? 'Liberal' : 'Fascist';

      String instructions = '';
      String teammateInfo = '';

      if (role == 'Liberal') {
        instructions = 'هدف: تصویب ۵ سیاست لیبرال یا اعدام هیتلر مخفی.';
      } else if (role == 'Fascist') {
        instructions = 'هدف: تصویب ۶ سیاست فاشیستی یا انتخاب هیتلر مخفی به عنوان صدراعظم پس از ۳ سیاست فاشیستی.';
        final otherFascists = <String>[];
        String hitlerName = '';

        for (int j = 0; j < playerCount; j++) {
          if (i == j) continue;
          if (roles[j] == 'Fascist') {
            otherFascists.add(players[j]['name']);
          } else if (roles[j] == 'Secret Hitler') {
            hitlerName = players[j]['name'];
          }
        }

        if (playerCount <= 6) {
          teammateInfo = 'هیتلر مخفی: $hitlerName';
        } else {
          final fascistsStr = otherFascists.isEmpty ? 'هیچ‌کدام' : otherFascists.join('، ');
          teammateInfo = 'سایر فاشیست‌ها: $fascistsStr\nهیتلر مخفی: $hitlerName';
        }
      } else if (role == 'Secret Hitler') {
        if (playerCount <= 6) {
          final fascistPlayer = players[roles.indexOf('Fascist')];
          teammateInfo = 'همکار فاشیست شما: ${fascistPlayer['name']}';
        } else {
          teammateInfo = 'فاشیست‌ها: شما نمی‌دانید فاشیست‌ها چه کسانی هستند.';
        }
      }

      privateRolesMap[playerId] = {
        'role': role,
        'party': party,
        'teammateInfo': teammateInfo,
      };
    }

    // 3. Save Private Roles documents
    await FirebaseManager.savePrivateRoles(lobbyCode, privateRolesMap);

    // 4. Initialize Policy Deck (6 Liberal, 11 Fascist)
    final List<String> deck = [];
    for (int i = 0; i < 6; i++) deck.add('liberal');
    for (int i = 0; i < 11; i++) deck.add('fascist');
    deck.shuffle();

    // 5. Update Game Document to transition phase
    final logsCopy = List<String>.from(logs);
    logsCopy.add('میزبان بازی را شروع کرد! همه بازیکنان در حال بررسی نقش‌های خود هستند.');

    await FirebaseManager.updateGame(lobbyCode, {
      'status': 'playing',
      'phase': 'roleReveal',
      'deck': deck,
      'discardPile': [],
      'logs': logsCopy,
    });
  }

  // Reveal screen finished
  Future<void> confirmRoleReveal() async {
    // We increment a ready count or transition once all players confirm.
    // To keep it simple: the host can transition the game, or once players tap, they see the nomination screen.
    // In our multiplayer system, once the host transitions status to roleReveal, any player can tap "Confirm".
    // Let's make it so that once the host clicks "Proceed from Reveal", it goes to electionNomination.
    if (isHost && phaseStr == 'roleReveal') {
      final logsCopy = List<String>.from(logs);
      logsCopy.add('دور اول: رئیس‌جمهور ${players[0]['name']} در حال نامزد کردن صدراعظم است.');
      await FirebaseManager.updateGame(lobbyCode, {
        'phase': 'electionNomination',
        'logs': logsCopy,
      });
    }
  }

  // President nominates Chancellor
  Future<void> nominateChancellor(int targetIndex) async {
    if (!isMyTurnPresident || phaseStr != 'electionNomination') return;

    final target = players[targetIndex];
    final logsCopy = List<String>.from(logs);
    logsCopy.add('$localPlayerName، ${target['name']} را برای صدراعظمی نامزد کرد. رای‌های خود را بدهید!');

    await FirebaseManager.updateGame(lobbyCode, {
      'nominatedChancellorIndex': targetIndex,
      'votes': {}, // Reset votes
      'phase': 'electionVoting',
      'logs': logsCopy,
    });
  }

  // Cast vote
  Future<void> castVote(bool vote) async {
    if (!amIAlive || phaseStr != 'electionVoting') return;

    final updatedVotes = Map<String, dynamic>.from(votes);
    updatedVotes[localPlayerId] = vote;

    await FirebaseManager.updateGame(lobbyCode, {
      'votes': updatedVotes,
    });
  }

  // Tally votes (Host or President fallback if host is dead/disconnected)
  Future<void> tallyVotes() async {
    final hostPlayer = players.firstWhere((p) => p['id'] == hostId, orElse: () => null);
    final bool isHostActive = hostPlayer != null && hostPlayer['isAlive'] == true && hostPlayer['isDisconnected'] != true;
    
    final bool canITally = isHostActive ? isHost : isMyTurnPresident;
    if (!canITally || phaseStr != 'electionVoting') return;

    int jaCount = 0;
    int neinCount = 0;
    votes.forEach((_, vote) {
      if (vote == true) jaCount++;
      if (vote == false) neinCount++;
    });

    final targetChancellor = players[nominatedChancellorIndex];
    final logsCopy = List<String>.from(logs);
    logsCopy.add('نتایج انتخابات برای ${targetChancellor['name']}: $jaCount موافق، $neinCount مخالف.');

    final lastElectionResult = {
      'nomineeName': targetChancellor['name'],
      'passed': jaCount > neinCount,
      'votes': votes,
    };

    // First save the last election results so everyone receives it
    await FirebaseManager.updateGame(lobbyCode, {
      'lastElectionResult': lastElectionResult,
    });

    if (jaCount > neinCount) {
      logsCopy.add('انتخابات تایید شد! ${targetChancellor['name']} اکنون صدراعظم است.');

      // Check Hitler win condition
      // Query private collection for nominated chancellor's role (since it is hidden in public gameData)
      final chancellorRoleData = await FirebaseManager.getPrivateRole(lobbyCode, targetChancellor['id']);
      final isHitler = chancellorRoleData?['role'] == 'Secret Hitler';

      if (fascistPolicies >= 3 && isHitler) {
        logsCopy.add('فاشیست‌ها برنده شدند! هیتلر مخفی پس از ۳ سیاست فاشیستی به عنوان صدراعظم انتخاب شد!');
        await FirebaseManager.updateGame(lobbyCode, {
          'chancellorIndex': nominatedChancellorIndex,
          'winner': 'Fascists',
          'winReason': 'Secret Hitler was elected Chancellor after 3 Fascist policies were enacted!',
          'phase': 'gameOver',
          'logs': logsCopy,
        });
      } else {
        // Enact successful government, draw cards
        await _drawPoliciesForLegislative(logsCopy);
      }
    } else {
      // Election failed
      final int newTracker = electionTracker + 1;
      logsCopy.add('انتخابات با شکست مواجه شد. ردیاب انتخابات: $newTracker/3.');

      if (newTracker >= 3) {
        logsCopy.add('هرج‌ومرج! کشیدن اولین کارت سیاست از دسته کارت‌ها.');
        await _enactChaosPolicy(logsCopy);
      } else {
        await _rotatePresident(logsCopy, failedElection: true, nextTracker: newTracker);
      }
    }
  }

  Future<void> _drawPoliciesForLegislative(List<String> currentLogs) async {
    final List<dynamic> deck = List.from(_gameData['deck'] ?? []);
    final List<dynamic> discard = List.from(_gameData['discardPile'] ?? []);

    final updatedDeck = _checkAndReshuffleDeckIfNeeded(deck, discard, 3, currentLogs);
    final drawn = [updatedDeck.removeLast(), updatedDeck.removeLast(), updatedDeck.removeLast()];

    await FirebaseManager.updateGame(lobbyCode, {
      'chancellorIndex': nominatedChancellorIndex,
      'electionTracker': 0,
      'deck': updatedDeck,
      'discardPile': discard,
      'drawnPolicies': drawn,
      'phase': 'legislativePresident',
      'logs': currentLogs,
    });
  }

  List<dynamic> _checkAndReshuffleDeckIfNeeded(
    List<dynamic> deck,
    List<dynamic> discard,
    int countNeeded,
    List<String> currentLogs,
  ) {
    if (deck.length < countNeeded) {
      currentLogs.add('مخلوط کردن مجدد کارت‌های سوخته در دسته کارت‌ها.');
      final List<dynamic> newDeck = List.from(deck)..addAll(discard);
      discard.clear();
      newDeck.shuffle();
      return newDeck;
    }
    return deck;
  }

  // President discards one card
  Future<void> presidentDiscardPolicy(int discardIndex) async {
    if (!isMyTurnPresident || phaseStr != 'legislativePresident') return;

    final List<dynamic> drawn = List.from(drawnPolicies);
    final discardedPolicy = drawn.removeAt(discardIndex);

    final List<dynamic> discard = List.from(_gameData['discardPile'] ?? []);
    discard.add(discardedPolicy);

    final logsCopy = List<String>.from(logs);
    logsCopy.add('$localPlayerName یک کارت سیاست را سوزاند و ۲ کارت باقی‌مانده را به صدراعظم داد.');

    await FirebaseManager.updateGame(lobbyCode, {
      'drawnPolicies': drawn,
      'discardPile': discard,
      'phase': 'legislativeChancellor',
      'logs': logsCopy,
    });
  }

  // Chancellor enacts one card (clicks it to enact)
  Future<void> chancellorEnactPolicy(int enactIndex) async {
    if (!isMyTurnChancellor || phaseStr != 'legislativeChancellor') return;

    final List<dynamic> drawn = List.from(drawnPolicies);
    final enactedPolicy = drawn.removeAt(enactIndex);
    final discardedPolicy = drawn.removeLast(); // The other card

    final List<dynamic> discard = List.from(_gameData['discardPile'] ?? []);
    discard.add(discardedPolicy);

    final logsCopy = List<String>.from(logs);
    logsCopy.add('$localPlayerName یک کارت سیاست ${enactedPolicy == 'liberal' ? 'لیبرال' : 'فاشیستی'} را تصویب کرد.');

    await _enactPolicy(enactedPolicy, discard, logsCopy, isChaos: false);
  }

  Future<void> _enactPolicy(
    String policy,
    List<dynamic> discard,
    List<String> currentLogs, {
    required bool isChaos,
  }) async {
    int newLib = liberalPolicies;
    int newFas = fascistPolicies;

    if (policy == 'liberal') {
      newLib++;
      currentLogs.add('سیاست‌های لیبرال: $newLib/5.');

      if (newLib >= 5) {
        currentLogs.add('لیبرال‌ها برنده شدند! ۵ سیاست لیبرال تصویب شده است.');
        await FirebaseManager.updateGame(lobbyCode, {
          'liberalPolicies': newLib,
          'winner': 'Liberals',
          'winReason': '5 Liberal policies have been enacted!',
          'phase': 'gameOver',
          'logs': currentLogs,
        });
        return;
      }
    } else {
      newFas++;
      currentLogs.add('سیاست‌های فاشیستی: $newFas/6.');

      if (newFas >= 6) {
        currentLogs.add('فاشیست‌ها برنده شدند! ۶ سیاست فاشیستی تصویب شده است.');
        await FirebaseManager.updateGame(lobbyCode, {
          'fascistPolicies': newFas,
          'winner': 'Fascists',
          'winReason': '6 Fascist policies have been enacted!',
          'phase': 'gameOver',
          'logs': currentLogs,
        });
        return;
      }

      // Check if presidential power triggers (only for regular enactments)
      if (!isChaos) {
        final power = _getPowerForFascistSlot(newFas, players.length);
        if (power != 'none') {
          currentLogs.add('اقدام رئیس‌جمهوری باز شد: $power.');
          await FirebaseManager.updateGame(lobbyCode, {
            'fascistPolicies': newFas,
            'discardPile': discard,
            'drawnPolicies': [],
            'phase': 'executiveAction',
            'activePower': power,
            'investigatedParty': null,
            'investigatedPlayerIndex': -1,
            'logs': currentLogs,
          });
          return;
        }
      }
    }

    // Normal round wrap-up
    await _rotatePresident(
      currentLogs,
      failedElection: false,
      nextTracker: 0,
      newFas: newFas,
      newLib: newLib,
      newDiscard: discard,
      isChaos: isChaos,
    );
  }

  Future<void> _enactChaosPolicy(List<String> currentLogs) async {
    final List<dynamic> deck = List.from(_gameData['deck'] ?? []);
    final List<dynamic> discard = List.from(_gameData['discardPile'] ?? []);

    final updatedDeck = _checkAndReshuffleDeckIfNeeded(deck, discard, 1, currentLogs);
    final policy = updatedDeck.removeLast();

    currentLogs.add('کارت هرج‌ومرج: ${policy == 'liberal' ? 'لیبرال' : 'فاشیست'}.');

    // Reset previous term limits so anyone is eligible
    await FirebaseManager.updateGame(lobbyCode, {
      'previousPresidentIndex': -1,
      'previousChancellorIndex': -1,
      'deck': updatedDeck,
    });

    await _enactPolicy(policy, discard, currentLogs, isChaos: true);
  }

  // Executive actions
  Future<void> executeInvestigateLoyalty(int targetIndex) async {
    if (!isMyTurnToExecutePower || activePowerStr != 'investigateLoyalty') return;
    if (investigatedPlayerIndex != -1) return;

    final target = players[targetIndex];
    final targetRoleData = await FirebaseManager.getPrivateRole(lobbyCode, target['id']);
    final party = targetRoleData?['party'] ?? 'Liberal';

    final logsCopy = List<String>.from(logs);
    final executorTitle = fascistPolicies == 3 ? 'Chancellor' : 'President';
    logsCopy.add('${executorTitle == 'Chancellor' ? 'صدراعظم' : 'رئیس‌جمهور'} $localPlayerName وفاداری ${target['name']} را بررسی کرد.');

    // Update target examined status locally (we can flag target player examined in players list)
    final List<dynamic> playersCopy = List.from(players);
    playersCopy[targetIndex] = Map<String, dynamic>.from(playersCopy[targetIndex])
      ..['isInvestigated'] = true;

    await FirebaseManager.updateGame(lobbyCode, {
      'players': playersCopy,
      'investigatedParty': party,
      'investigatedPlayerIndex': targetIndex,
      'logs': logsCopy,
    });
  }

  Future<void> completeInvestigateLoyalty() async {
    if (!isMyTurnToExecutePower || activePowerStr != 'investigateLoyalty') return;
    await FirebaseManager.updateGame(lobbyCode, {
      'activePower': 'none',
      'investigatedParty': null,
      'investigatedPlayerIndex': -1,
    });
    // Rotate president
    await _rotatePresident(List<String>.from(logs), failedElection: false, nextTracker: 0);
  }

  Future<void> executePolicyPeek() async {
    if (!isMyTurnToExecutePower || activePowerStr != 'policyPeek') return;

    final List<dynamic> deck = List.from(_gameData['deck'] ?? []);
    final List<dynamic> discard = List.from(_gameData['discardPile'] ?? []);
    final List<String> logsCopy = List<String>.from(logs);

    final updatedDeck = _checkAndReshuffleDeckIfNeeded(deck, discard, 3, logsCopy);
    final peeked = updatedDeck.sublist(updatedDeck.length - 3).reversed.toList();

    final executorTitle = fascistPolicies == 3 ? 'Chancellor' : 'President';
    logsCopy.add('${executorTitle == 'Chancellor' ? 'صدراعظم' : 'رئیس‌جمهور'} $localPlayerName ۳ کارت بالای دسته سیاست را پیش‌بینی کرد.');

    await FirebaseManager.updateGame(lobbyCode, {
      'deck': updatedDeck,
      'discardPile': discard,
      'drawnPolicies': peeked,
      'logs': logsCopy,
    });
  }

  Future<void> completePolicyPeek() async {
    if (!isMyTurnToExecutePower || activePowerStr != 'policyPeek') return;
    await FirebaseManager.updateGame(lobbyCode, {
      'activePower': 'none',
      'drawnPolicies': [],
    });
    await _rotatePresident(List<String>.from(logs), failedElection: false, nextTracker: 0);
  }

  Future<void> executeCallSpecialElection(int targetIndex) async {
    if (!isMyTurnToExecutePower || activePowerStr != 'callSpecialElection') return;

    final target = players[targetIndex];
    final logsCopy = List<String>.from(logs);
    final executorTitle = fascistPolicies == 3 ? 'Chancellor' : 'President';
    logsCopy.add('${executorTitle == 'Chancellor' ? 'صدراعظم' : 'رئیس‌جمهور'} $localPlayerName، ${target['name']} را برای ریاست‌جمهوری ویژه بعدی نامزد کرد.');

    await FirebaseManager.updateGame(lobbyCode, {
      'specialPresidentIndex': targetIndex,
      'lastRegularPresidentIndex': presidentIndex,
      'activePower': 'none',
    });

    await _rotatePresident(logsCopy, failedElection: false, nextTracker: 0);
  }

  Future<void> executeExecution(int targetIndex) async {
    if (!isMyTurnToExecutePower || activePowerStr != 'execution') return;

    final target = players[targetIndex];
    final targetRoleData = await FirebaseManager.getPrivateRole(lobbyCode, target['id']);
    final isHitler = targetRoleData?['role'] == 'Secret Hitler';

    final logsCopy = List<String>.from(logs);
    final executorTitle = fascistPolicies == 3 ? 'Chancellor' : 'President';
    logsCopy.add('${executorTitle == 'Chancellor' ? 'صدراعظم' : 'رئیس‌جمهور'} $localPlayerName، ${target['name']} را اعدام کرد!');

    final List<dynamic> playersCopy = List.from(players);
    playersCopy[targetIndex] = Map<String, dynamic>.from(playersCopy[targetIndex])
      ..['isAlive'] = false;

    if (isHitler) {
      logsCopy.add('لیبرال‌ها برنده شدند! هیتلر مخفی اعدام شده است!');
      await FirebaseManager.updateGame(lobbyCode, {
        'players': playersCopy,
        'winner': 'Liberals',
        'winReason': 'Secret Hitler was executed!',
        'phase': 'gameOver',
        'logs': logsCopy,
      });
    } else {
      await _rotatePresident(logsCopy, failedElection: false, nextTracker: 0, newPlayersList: playersCopy);
    }
  }

  // Internal rotations
  Future<void> _rotatePresident(
    List<String> currentLogs, {
    required bool failedElection,
    required int nextTracker,
    int? newFas,
    int? newLib,
    List<dynamic>? newDiscard,
    List<dynamic>? newPlayersList,
    bool isChaos = false,
  }) async {
    final activePlayersList = newPlayersList ?? players;
    int nextPresident = presidentIndex;

    // Check term limits
    int newPrevPres = previousPresidentIndex;
    int newPrevChan = previousChancellorIndex;

    if (isChaos) {
      newPrevPres = -1;
      newPrevChan = -1;
    } else if (!failedElection) {
      newPrevPres = presidentIndex;
      newPrevChan = chancellorIndex;
    }

    final int? specialPres = _gameData['specialPresidentIndex'];
    final int? lastRegularPres = _gameData['lastRegularPresidentIndex'];

    if (specialPres != null) {
      nextPresident = specialPres;
      await FirebaseManager.updateGame(lobbyCode, {
        'specialPresidentIndex': null,
      });
      currentLogs.add('انتخابات ویژه آغاز شد. ${activePlayersList[nextPresident]['name']} ریاست‌جمهوری را بر عهده می‌گیرد.');
    } else {
      if (lastRegularPres != null) {
        nextPresident = lastRegularPres;
        await FirebaseManager.updateGame(lobbyCode, {
          'lastRegularPresidentIndex': null,
        });
      }

      // Rotate to next alive player
      do {
        nextPresident = (nextPresident + 1) % activePlayersList.length;
      } while (activePlayersList[nextPresident]['isAlive'] == false);

      currentLogs.add('دور جدید: ${activePlayersList[nextPresident]['name']} کاندیدای ریاست‌جمهوری است.');
    }

    final Map<String, dynamic> updates = {
      'presidentIndex': nextPresident,
      'chancellorIndex': -1,
      'nominatedChancellorIndex': -1,
      'votes': {},
      'phase': 'electionNomination',
      'electionTracker': nextTracker,
      'logs': currentLogs,
      'previousPresidentIndex': newPrevPres,
      'previousChancellorIndex': newPrevChan,
      'activePower': 'none',
    };

    if (newPlayersList != null) updates['players'] = newPlayersList;
    if (newFas != null) updates['fascistPolicies'] = newFas;
    if (newLib != null) updates['liberalPolicies'] = newLib;
    if (newDiscard != null) updates['discardPile'] = newDiscard;

    await FirebaseManager.updateGame(lobbyCode, updates);
  }

  // Helpers
  List<String> _generateRolesForCount(int count) {
    switch (count) {
      case 5:
        return ['Liberal', 'Liberal', 'Liberal', 'Fascist', 'Secret Hitler'];
      case 6:
        return ['Liberal', 'Liberal', 'Liberal', 'Liberal', 'Fascist', 'Secret Hitler'];
      case 7:
        return ['Liberal', 'Liberal', 'Liberal', 'Liberal', 'Fascist', 'Fascist', 'Secret Hitler'];
      case 8:
        return ['Liberal', 'Liberal', 'Liberal', 'Liberal', 'Liberal', 'Fascist', 'Fascist', 'Secret Hitler'];
      case 9:
        return ['Liberal', 'Liberal', 'Liberal', 'Liberal', 'Liberal', 'Fascist', 'Fascist', 'Fascist', 'Secret Hitler'];
      case 10:
        return ['Liberal', 'Liberal', 'Liberal', 'Liberal', 'Liberal', 'Liberal', 'Fascist', 'Fascist', 'Fascist', 'Secret Hitler'];
      default:
        return ['Liberal', 'Liberal', 'Liberal', 'Fascist', 'Secret Hitler'];
    }
  }

  String _getPowerForFascistSlot(int fascistCount, int playerCount) {
    if (fascistCount == 1) {
      return playerCount >= 9 ? 'investigateLoyalty' : 'none';
    } else if (fascistCount == 2) {
      return playerCount >= 7 ? 'investigateLoyalty' : 'none';
    } else if (fascistCount == 3) {
      return 'investigateLoyalty';
    } else if (fascistCount == 4) {
      return 'execution';
    } else if (fascistCount == 5) {
      return 'execution';
    }
    return 'none';
  }
}
