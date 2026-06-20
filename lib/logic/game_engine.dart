import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import 'sound_manager.dart';

class GameEngine extends ChangeNotifier {
  final List<Player> _players = [];
  int _liberalPolicies = 0;
  int _fascistPolicies = 0;
  int _electionTracker = 0;

  List<PolicyType> _deck = [];
  List<PolicyType> _discardPile = [];

  int _presidentIndex = 0;
  int _chancellorIndex = -1;
  int _nominatedChancellorIndex = -1;

  int _previousPresidentIndex = -1;
  int _previousChancellorIndex = -1;

  GamePhase _phase = GamePhase.setup;
  ExecutivePower _activePower = ExecutivePower.none;

  int? _specialPresidentIndex;
  int? _lastRegularPresidentIndex;

  final Map<int, bool> _votes = {};
  List<PolicyType> _drawnPolicies = [];
  final List<String> _logs = [];

  int _revealPlayerIndex = 0;
  bool _roleCardRevealed = false;

  String? _winner;
  String? _winReason;
  String? _investigatedParty;
  int _investigatedPlayerIndex = -1;
  Map<String, dynamic>? _lastElectionResult;

  // Getters
  List<Player> get players => _players;
  int get liberalPolicies => _liberalPolicies;
  int get fascistPolicies => _fascistPolicies;
  int get electionTracker => _electionTracker;
  int get deckCount => _deck.length;
  int get discardCount => _discardPile.length;
  int get presidentIndex => _presidentIndex;
  int get chancellorIndex => _chancellorIndex;
  int get nominatedChancellorIndex => _nominatedChancellorIndex;
  int get previousPresidentIndex => _previousPresidentIndex;
  int get previousChancellorIndex => _previousChancellorIndex;
  GamePhase get phase => _phase;
  ExecutivePower get activePower => _activePower;
  Map<int, bool> get votes => _votes;
  List<PolicyType> get drawnPolicies => _drawnPolicies;
  Map<String, dynamic>? get lastElectionResult => _lastElectionResult;
  List<String> get logs => _logs;
  int get revealPlayerIndex => _revealPlayerIndex;
  bool get roleCardRevealed => _roleCardRevealed;
  String? get winner => _winner;
  String? get winReason => _winReason;
  String? get investigatedParty => _investigatedParty;
  int get investigatedPlayerIndex => _investigatedPlayerIndex;

  int get powerExecutorIndex {
    if (_phase != GamePhase.executiveAction) return -1;
    if (_fascistPolicies == 3) {
      return _chancellorIndex;
    }
    return _presidentIndex;
  }

  String get powerExecutorName {
    final idx = powerExecutorIndex;
    if (idx == -1 || idx >= _players.length) return '';
    return _players[idx].name;
  }

  Player get currentPresident => _players[_presidentIndex];
  Player? get nominatedChancellor =>
      _nominatedChancellorIndex == -1 ? null : _players[_nominatedChancellorIndex];
  Player? get currentChancellor =>
      _chancellorIndex == -1 ? null : _players[_chancellorIndex];

  int get alivePlayersCount => _players.where((p) => p.isAlive).length;

  void log(String message) {
    _logs.add(message);
    notifyListeners();
  }

  // Reset game to setup screen
  void resetToSetup() {
    _players.clear();
    _phase = GamePhase.setup;
    notifyListeners();
  }

  // Start a new game
  void startGame(List<String> names) {
    SoundManager.play(SoundEvent.shuffle);
    if (names.length < 5 || names.length > 10) {
      throw ArgumentError('Game requires between 5 and 10 players.');
    }

    _players.clear();
    _liberalPolicies = 0;
    _fascistPolicies = 0;
    _electionTracker = 0;
    _deck.clear();
    _discardPile.clear();
    _presidentIndex = 0;
    _chancellorIndex = -1;
    _nominatedChancellorIndex = -1;
    _previousPresidentIndex = -1;
    _previousChancellorIndex = -1;
    _phase = GamePhase.roleReveal;
    _activePower = ExecutivePower.none;
    _specialPresidentIndex = null;
    _lastRegularPresidentIndex = null;
    _votes.clear();
    _drawnPolicies.clear();
    _logs.clear();
    _revealPlayerIndex = 0;
    _roleCardRevealed = false;
    _winner = null;
    _winReason = null;
    _investigatedParty = null;
    _investigatedPlayerIndex = -1;

    // 1. Assign Roles
    final int playerCount = names.length;
    final List<Role> roles = _generateRolesForCount(playerCount);
    final random = Random();
    for (int i = 0; i < 3; i++) {
      roles.shuffle(random);
    }

    for (int i = 0; i < playerCount; i++) {
      _players.add(Player(id: i, name: names[i], role: roles[i]));
    }

    // 2. Setup Policy Deck (6 Liberal, 11 Fascist)
    for (int i = 0; i < 6; i++) {
      _deck.add(PolicyType.liberal);
    }
    for (int i = 0; i < 11; i++) {
      _deck.add(PolicyType.fascist);
    }
    for (int i = 0; i < 3; i++) {
      _deck.shuffle(random);
    }

    log('Game started with $playerCount players.');
    notifyListeners();
  }

  List<Role> _generateRolesForCount(int count) {
    switch (count) {
      case 5:
        return [Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.secretHitler];
      case 6:
        return [Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.secretHitler];
      case 7:
        return [Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.fascist, Role.secretHitler];
      case 8:
        return [Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.fascist, Role.secretHitler];
      case 9:
        return [Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.fascist, Role.fascist, Role.secretHitler];
      case 10:
        return [Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.liberal, Role.fascist, Role.fascist, Role.fascist, Role.secretHitler];
      default:
        throw ArgumentError('Invalid player count');
    }
  }

  // Pass-and-play role reveal helpers
  void toggleRevealRole() {
    _roleCardRevealed = !_roleCardRevealed;
    if (_roleCardRevealed) {
      SoundManager.play(SoundEvent.presidentReceivesPolicies);
    }
    notifyListeners();
  }

  void confirmAndNextRole() {
    _roleCardRevealed = false;
    if (_revealPlayerIndex < _players.length - 1) {
      _revealPlayerIndex++;
    } else {
      _phase = GamePhase.electionNomination;
      log('All players reviewed their roles. Initial Presidential candidate is ${_players[_presidentIndex].name}.');
    }
    notifyListeners();
  }

  // Eligibility check for nominating Chancellor
  bool isEligibleForChancellor(int index) {
    final player = _players[index];
    if (!player.isAlive) return false;
    if (index == _presidentIndex) return false; // Cannot nominate self

    // Term limit rules:
    // If only 5 players remain alive in the game, only the last Chancellor is ineligible.
    if (alivePlayersCount == 5) {
      return index != _previousChancellorIndex;
    } else {
      return index != _previousChancellorIndex && index != _previousPresidentIndex;
    }
  }

  // Nominate Chancellor
  void nominateChancellor(int index) {
    if (!isEligibleForChancellor(index)) {
      throw StateError('Player is not eligible for Chancellor nomination.');
    }
    _nominatedChancellorIndex = index;
    _votes.clear();
    _phase = GamePhase.electionVoting;
    log('${currentPresident.name} nominated ${players[index].name} for Chancellor.');
    notifyListeners();
  }

  // Cast a vote
  void castVote(int playerIndex, bool vote) {
    if (!_players[playerIndex].isAlive) return;
    _votes[playerIndex] = vote;
    notifyListeners();
  }

  // Submit all votes (after everyone has chosen)
  void tallyVotes() {
    final int aliveCount = alivePlayersCount;
    if (_votes.length < aliveCount) {
      throw StateError('Not all alive players have voted yet.');
    }

    int yesVotes = 0;
    int noVotes = 0;
    _votes.forEach((playerIdx, vote) {
      if (vote) {
        yesVotes++;
      } else {
        noVotes++;
      }
    });

    // Save the election results before clearing votes in subsequent states
    final Map<String, bool> playerIndexVotes = {};
    _votes.forEach((index, vote) {
      if (index >= 0 && index < _players.length) {
        playerIndexVotes[_players[index].name] = vote;
      }
    });

    _lastElectionResult = {
      'nomineeName': nominatedChancellor!.name,
      'passed': yesVotes > noVotes,
      'votes': playerIndexVotes,
    };

    log('Election results for Chancellor ${nominatedChancellor!.name}: $yesVotes Ja, $noVotes Nein.');

    if (yesVotes > noVotes) {
      // Election passed!
      _chancellorIndex = _nominatedChancellorIndex;
      _electionTracker = 0;
      log('The election passed! ${nominatedChancellor!.name} is now Chancellor.');

      // Check Hitler win condition: If 3 or more fascist policies are enacted and Hitler is elected Chancellor
      if (_fascistPolicies >= 3 && currentChancellor!.role == Role.secretHitler) {
        _winner = 'Fascists';
        _winReason = 'Secret Hitler was elected Chancellor after 3 Fascist policies were enacted!';
        _phase = GamePhase.gameOver;
        log('Fascists win! $_winReason');
        SoundManager.play(SoundEvent.fascistsWinHitlerElected);
      } else {
        SoundManager.play(SoundEvent.vetoSucceeds);
        // Draw policies for the President
        _drawPoliciesForLegislative();
      }
    } else {
      // Election failed
      _electionTracker++;
      log('The election failed. Election tracker is now at $_electionTracker/3.');
      SoundManager.play(SoundEvent.vetoFails);

      if (_electionTracker >= 3) {
        // Chaos rule: enact top policy
        _enactChaosPolicy();
      } else {
        // Next president candidates
        _rotatePresident();
      }
    }
    notifyListeners();
  }

  void _drawPoliciesForLegislative() {
    _checkAndReshuffleDeckIfNeeded(3);
    _drawnPolicies = [_deck.removeLast(), _deck.removeLast(), _deck.removeLast()];
    _phase = GamePhase.legislativePresident;
    notifyListeners();
  }

  void _checkAndReshuffleDeckIfNeeded(int countNeeded) {
    if (_deck.length < countNeeded) {
      log('Deck has ${_deck.length} cards, which is less than $countNeeded. Reshuffling discard pile into the deck.');
      _deck.addAll(_discardPile);
      _discardPile.clear();
      final random = Random();
      for (int i = 0; i < 3; i++) {
        _deck.shuffle(random);
      }
    }
  }

  // President discards one policy, leaving 2
  void presidentDiscardPolicy(int discardIndex) {
    if (_phase != GamePhase.legislativePresident) return;
    if (discardIndex < 0 || discardIndex >= _drawnPolicies.length) return;

    final discarded = _drawnPolicies.removeAt(discardIndex);
    _discardPile.add(discarded);

    _phase = GamePhase.legislativeChancellor;
    log('${currentPresident.name} discarded a policy and passed 2 cards to Chancellor ${currentChancellor!.name}.');
    SoundManager.play(SoundEvent.chancellorReceivesPolicies);
    notifyListeners();
  }

  // Chancellor plays (enacts) one policy, discarding the other
  void chancellorEnactPolicy(int enactIndex) {
    if (_phase != GamePhase.legislativeChancellor) return;
    if (enactIndex < 0 || enactIndex >= _drawnPolicies.length) return;

    final enacted = _drawnPolicies.removeAt(enactIndex);
    final discarded = _drawnPolicies.removeLast();
    _drawnPolicies.clear();

    _discardPile.add(discarded);
    _enactPolicy(enacted, isChaos: false);
  }

  void _enactPolicy(PolicyType policy, {required bool isChaos}) {
    if (policy == PolicyType.liberal) {
      _liberalPolicies++;
      log('A Liberal policy was enacted. Total: $_liberalPolicies/5.');

      if (_liberalPolicies >= 5) {
        _winner = 'Liberals';
        _winReason = '5 Liberal policies have been enacted!';
        _phase = GamePhase.gameOver;
        log('Liberals win! $_winReason');
        SoundManager.play(SoundEvent.liberalsWin);
        notifyListeners();
        return;
      }
    } else {
      _fascistPolicies++;
      log('A Fascist policy was enacted. Total: $_fascistPolicies/6.');

      if (_fascistPolicies >= 6) {
        _winner = 'Fascists';
        _winReason = '6 Fascist policies have been enacted!';
        _phase = GamePhase.gameOver;
        log('Fascists win! $_winReason');
        SoundManager.play(SoundEvent.fascistsWin);
        notifyListeners();
        return;
      }

      // Check if presidential power triggers (only for regular enactments, not chaos)
      if (!isChaos) {
        final power = _getPowerForFascistSlot(_fascistPolicies, _players.length);
        if (power != ExecutivePower.none) {
          _activePower = power;
          _phase = GamePhase.executiveAction;
          _investigatedParty = null;
          _investigatedPlayerIndex = -1;
          log('Presidential power unlocked: ${power.toString().split('.').last}.');
          SoundManager.play(SoundEvent.alarm);
          notifyListeners();
          return;
        }
      }
    }

    // Normal round wrap-up
    if (policy == PolicyType.liberal) {
      SoundManager.play(SoundEvent.enactPolicy);
    } else {
      SoundManager.play(SoundEvent.alarm);
    }
    _completeRound(isChaos: isChaos);
  }

  void _enactChaosPolicy() {
    _checkAndReshuffleDeckIfNeeded(1);
    final policy = _deck.removeLast();
    log('Chaos! Top policy from deck is drawn: ${policy == PolicyType.liberal ? 'Liberal' : 'Fascist'}.');

    // Reset election tracker
    _electionTracker = 0;

    // Reset previous term limits so anyone is eligible
    _previousPresidentIndex = -1;
    _previousChancellorIndex = -1;

    // Enact without triggering executive actions
    _enactPolicy(policy, isChaos: true);
  }

  ExecutivePower _getPowerForFascistSlot(int fascistCount, int playerCount) {
    if (fascistCount == 1) {
      if (playerCount >= 9) return ExecutivePower.investigateLoyalty;
      return ExecutivePower.none;
    } else if (fascistCount == 2) {
      if (playerCount >= 7) return ExecutivePower.investigateLoyalty;
      return ExecutivePower.none;
    } else if (fascistCount == 3) {
      return ExecutivePower.investigateLoyalty;
    } else if (fascistCount == 4) {
      return ExecutivePower.execution;
    } else if (fascistCount == 5) {
      return ExecutivePower.execution;
    }
    return ExecutivePower.none;
  }

  // Executive Power Actions
  void executeInvestigateLoyalty(int targetIndex) {
    if (_activePower != ExecutivePower.investigateLoyalty) return;
    if (_investigatedPlayerIndex != -1) return;
    if (targetIndex == powerExecutorIndex || !_players[targetIndex].isAlive) return;

    final target = _players[targetIndex];
    _investigatedParty = target.role!.partyName;
    _investigatedPlayerIndex = targetIndex;
    target.isInvestigated = true;

    final executorTitle = _fascistPolicies == 3 ? 'Chancellor' : 'President';
    log('$executorTitle $powerExecutorName investigated the loyalty of ${target.name}.');
    SoundManager.play(SoundEvent.policyInvestigate);
    notifyListeners();
  }

  void completeInvestigateLoyalty() {
    _investigatedParty = null;
    _investigatedPlayerIndex = -1;
    _activePower = ExecutivePower.none;
    _completeRound();
  }

  void executePolicyPeek() {
    if (_activePower != ExecutivePower.policyPeek) return;
    _checkAndReshuffleDeckIfNeeded(3);
    // Top 3 policies of the deck (last 3 in the array)
    _drawnPolicies = _deck.sublist(_deck.length - 3).reversed.toList();
    log('President ${currentPresident.name} peeked at the top 3 cards in the policy deck.');
    SoundManager.play(SoundEvent.policyPeek);
    notifyListeners();
  }

  void completePolicyPeek() {
    _drawnPolicies.clear();
    _activePower = ExecutivePower.none;
    _completeRound();
  }

  void executeCallSpecialElection(int targetIndex) {
    if (_activePower != ExecutivePower.callSpecialElection) return;
    if (targetIndex == powerExecutorIndex || !_players[targetIndex].isAlive) return;

    _specialPresidentIndex = targetIndex;
    _lastRegularPresidentIndex = _presidentIndex;

    final executorTitle = _fascistPolicies == 3 ? 'Chancellor' : 'President';
    log('$executorTitle $powerExecutorName called a special election, nominating ${_players[targetIndex].name} as the next President.');
    _activePower = ExecutivePower.none;
    _completeRound();
  }

  void executeExecution(int targetIndex) {
    if (_activePower != ExecutivePower.execution) return;
    if (targetIndex == powerExecutorIndex || !_players[targetIndex].isAlive) return;

    final target = _players[targetIndex];
    target.isAlive = false;
    final executorTitle = _fascistPolicies == 3 ? 'Chancellor' : 'President';
    log('$executorTitle $powerExecutorName executed ${target.name}!');

    // Check if executed player was Hitler
    if (target.role == Role.secretHitler) {
      _winner = 'Liberals';
      _winReason = 'Secret Hitler was executed!';
      _phase = GamePhase.gameOver;
      log('Liberals win! $_winReason');
      SoundManager.play(SoundEvent.liberalsWinHitlerShow);
      notifyListeners();
      return;
    }

    SoundManager.play(SoundEvent.playerShot);
    _activePower = ExecutivePower.none;
    _completeRound();
  }

  void _completeRound({bool isChaos = false}) {
    // Record current term limits
    if (isChaos) {
      _previousPresidentIndex = -1;
      _previousChancellorIndex = -1;
    } else {
      _previousPresidentIndex = _presidentIndex;
      _previousChancellorIndex = _chancellorIndex;
    }

    // Reset current chancellor
    _chancellorIndex = -1;
    _nominatedChancellorIndex = -1;

    // Reshuffle deck if fewer than 3 cards remain at the end of the session
    if (_deck.length < 3) {
      log('Deck has ${_deck.length} cards remaining at the end of the session. Reshuffling discard pile into the deck.');
      _deck.addAll(_discardPile);
      _discardPile.clear();
      final random = Random();
      for (int i = 0; i < 3; i++) {
        _deck.shuffle(random);
      }
    }

    _rotatePresident();
    notifyListeners();
  }

  void _rotatePresident() {
    // Check if we have a special election president queued
    if (_specialPresidentIndex != null) {
      _presidentIndex = _specialPresidentIndex!;
      _specialPresidentIndex = null;
      log('Special Election begins: ${_players[_presidentIndex].name} takes the Presidency.');
    } else {
      // If we are returning from a special election round
      if (_lastRegularPresidentIndex != null) {
        _presidentIndex = _lastRegularPresidentIndex!;
        _lastRegularPresidentIndex = null;
      }

      // Standard rotation to the next alive player
      do {
        _presidentIndex = (_presidentIndex + 1) % _players.length;
      } while (!_players[_presidentIndex].isAlive);

      log('New round starts: ${_players[_presidentIndex].name} is the Presidential candidate.');
    }

    _votes.clear();
    _phase = GamePhase.electionNomination;
  }
}
