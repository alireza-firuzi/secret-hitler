import 'package:flutter_test/flutter_test.dart';
import 'package:secret_hitler/logic/game_engine.dart';
import 'package:secret_hitler/logic/sound_manager.dart';
import 'package:secret_hitler/models/game_state.dart';

void main() {
  group('Secret Hitler Game Engine Tests', () {
    late GameEngine engine;

    setUp(() {
      SoundManager.setMuted(true);
      engine = GameEngine();
    });

    test('Game initialization assigns correct roles for 5 players', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
      engine.startGame(names);

      expect(engine.players.length, 5);
      expect(engine.phase, GamePhase.roleReveal);
      expect(engine.liberalPolicies, 0);
      expect(engine.fascistPolicies, 0);

      // Verify roles distribution
      int liberals = 0;
      int fascists = 0;
      int hitlers = 0;

      for (var player in engine.players) {
        if (player.role == Role.liberal) liberals++;
        if (player.role == Role.fascist) fascists++;
        if (player.role == Role.secretHitler) hitlers++;
      }

      expect(liberals, 3);
      expect(fascists, 1);
      expect(hitlers, 1);
    });

    test('Game initialization assigns correct roles for 7 players', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank', 'Grace'];
      engine.startGame(names);

      int liberals = 0;
      int fascists = 0;
      int hitlers = 0;

      for (var player in engine.players) {
        if (player.role == Role.liberal) liberals++;
        if (player.role == Role.fascist) fascists++;
        if (player.role == Role.secretHitler) hitlers++;
      }

      expect(liberals, 4);
      expect(fascists, 2);
      expect(hitlers, 1);
    });

    test('Pass-and-play role reveal transitions properly to electionNomination', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
      engine.startGame(names);

      for (int i = 0; i < 5; i++) {
        expect(engine.revealPlayerIndex, i);
        expect(engine.phase, GamePhase.roleReveal);
        engine.toggleRevealRole();
        expect(engine.roleCardRevealed, true);
        engine.confirmAndNextRole();
      }

      expect(engine.phase, GamePhase.electionNomination);
      expect(engine.presidentIndex, 0);
    });

    test('Term limit rules are enforced correctly for 5 players', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
      engine.startGame(names);

      // Complete reveal phase
      for (int i = 0; i < 5; i++) {
        engine.toggleRevealRole();
        engine.confirmAndNextRole();
      }

      // Round 1: President Alice (0) nominates Bob (1)
      engine.nominateChancellor(1);
      expect(engine.phase, GamePhase.electionVoting);

      // Everyone votes Ja
      for (int i = 0; i < 5; i++) {
        engine.castVote(i, true);
      }
      engine.tallyVotes();

      expect(engine.chancellorIndex, 1);
      expect(engine.phase, GamePhase.legislativePresident);

      // Legislative discard: President discards first
      engine.presidentDiscardPolicy(0);
      expect(engine.phase, GamePhase.legislativeChancellor);

      // Chancellor discards first, enacting the other card
      engine.chancellorEnactPolicy(0);

      // Round 2: President should rotate to Bob (1)
      expect(engine.presidentIndex, 1);
      expect(engine.previousPresidentIndex, 0);
      expect(engine.previousChancellorIndex, 1);

      // With 5 players, previous President (Alice, index 0) is eligible to be nominated as Chancellor.
      // But previous Chancellor (Bob, index 1) is ineligible.
      expect(engine.isEligibleForChancellor(0), true);
      expect(engine.isEligibleForChancellor(1), false); // Cannot nominate self anyway
      expect(engine.isEligibleForChancellor(2), true);
    });

    test('Term limit rules are enforced correctly for 6 players', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve', 'Frank'];
      engine.startGame(names);

      // Complete reveal phase
      for (int i = 0; i < 6; i++) {
        engine.toggleRevealRole();
        engine.confirmAndNextRole();
      }

      // Round 1: President Alice (0) nominates Bob (1)
      engine.nominateChancellor(1);

      // Everyone votes Ja
      for (int i = 0; i < 6; i++) {
        engine.castVote(i, true);
      }
      engine.tallyVotes();

      // Legislative phase
      engine.presidentDiscardPolicy(0);
      engine.chancellorEnactPolicy(0);

      // Round 2: President rotates to Bob (1)
      expect(engine.presidentIndex, 1);
      expect(engine.previousPresidentIndex, 0);
      expect(engine.previousChancellorIndex, 1);

      // With 6 players, BOTH previous President (Alice, 0) and previous Chancellor (Bob, 1) are ineligible.
      expect(engine.isEligibleForChancellor(0), false);
      expect(engine.isEligibleForChancellor(1), false); // Nominate self
      expect(engine.isEligibleForChancellor(2), true);
    });

    test('Tallying votes fails election if majority is not Ja', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
      engine.startGame(names);

      // Complete reveal
      for (int i = 0; i < 5; i++) {
        engine.toggleRevealRole();
        engine.confirmAndNextRole();
      }

      // President Alice (0) nominates Bob (1)
      engine.nominateChancellor(1);

      // 2 Ja, 3 Nein
      engine.castVote(0, true);
      engine.castVote(1, true);
      engine.castVote(2, false);
      engine.castVote(3, false);
      engine.castVote(4, false);

      engine.tallyVotes();

      // Election fails. Tracker goes to 1. Phase goes back to nomination with next President Bob (1).
      expect(engine.electionTracker, 1);
      expect(engine.presidentIndex, 1);
      expect(engine.phase, GamePhase.electionNomination);
    });

    test('Hitler election win condition check', () {
      final names = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
      // We manually override roles to set up Hitler win condition testing
      engine.startGame(names);

      // Manually force Bob (1) to be Secret Hitler
      engine.players[1].role = Role.secretHitler;
      // Manually force Alice (0) to be Liberal
      engine.players[0].role = Role.liberal;

      // Complete reveal
      for (int i = 0; i < 5; i++) {
        engine.toggleRevealRole();
        engine.confirmAndNextRole();
      }

      // Set Fascist policies to 3
      // Enacting 3 policies manually
      // We alternate Chancellors to avoid term limits and self-nominations.
      // Iteration 0: President 0 (Alice), nominate 2 (Charlie).
      // Iteration 1: President 1 (Bob), nominate 3 (Dave).
      // Iteration 2: President 2 (Charlie), nominate 4 (Eve).
      final chancellors = [2, 3, 4];
      for (int i = 0; i < 3; i++) {
        engine.nominateChancellor(chancellors[i]);
        for (int k = 0; k < 5; k++) engine.castVote(k, true);
        engine.tallyVotes();
        // Force drawn policies to be fascist
        engine.drawnPolicies.clear();
        engine.drawnPolicies.addAll([PolicyType.fascist, PolicyType.fascist, PolicyType.fascist]);
        engine.presidentDiscardPolicy(0);
        engine.chancellorEnactPolicy(0);
      }

      expect(engine.fascistPolicies, 3);

      // Now President nominates Bob (Hitler) for Chancellor
      engine.nominateChancellor(1);

      // Everyone votes Ja
      for (int i = 0; i < 5; i++) {
        engine.castVote(i, true);
      }

      engine.tallyVotes();

      // Hitler elected Chancellor after 3 fascist policies enacted -> Fascist win
      expect(engine.winner, 'Fascists');
      expect(engine.phase, GamePhase.gameOver);
    });
  });
}
