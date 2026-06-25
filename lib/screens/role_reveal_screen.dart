import 'package:flutter/material.dart';
import '../logic/game_engine.dart';
import '../models/game_state.dart';

class RoleRevealScreen extends StatelessWidget {
  final GameEngine engine;

  const RoleRevealScreen({Key? key, required this.engine}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int playerIndex = engine.revealPlayerIndex;
    final Player player = engine.players[playerIndex];
    final bool isRevealed = engine.roleCardRevealed;

    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/wood_table_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                // Progress indicator
                Row(
                  children: [
                    Text(
                      'REVEAL PHASE: ${playerIndex + 1}/${engine.players.length}',
                      style: const TextStyle(
                        color: Colors.white30,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (playerIndex + 1) / engine.players.length,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
  
                // The Envelope/Card Container
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: isRevealed
                      ? _buildIdentityCard(context, player)
                      : _buildEnvelopeCover(context, player),
                ),
  
                const Spacer(),
  
                // Action button
                if (isRevealed)
                  ElevatedButton(
                    onPressed: () {
                      engine.confirmAndNextRole();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E2A27),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'CONFIRM & NEXT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cover representation
  Widget _buildEnvelopeCover(BuildContext context, Player player) {
    return Container(
      key: const ValueKey('envelope_cover'),
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onPanDown: (_) {
              if (!engine.roleCardRevealed) {
                engine.toggleRevealRole();
              }
            },
            onPanEnd: (_) {
              if (engine.roleCardRevealed) {
                engine.toggleRevealRole();
              }
            },
            onPanCancel: () {
              if (engine.roleCardRevealed) {
                engine.toggleRevealRole();
              }
            },
            child: _buildWaxSeal(),
          ),
          const SizedBox(height: 20),
          const Text(
            'CONFIDENTIAL',
            style: TextStyle(
              color: Color(0xFF9E2A2B),
              fontFamily: 'serif',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pass the device to',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Hold the wax seal to break open your secret file. Release to hide.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaxSeal() {
    return Image.asset(
      'assets/images/wax_seal.png',
      width: 100,
      height: 100,
      fit: BoxFit.contain,
    );
  }

  // Inside revealed card representation
  Widget _buildIdentityCard(BuildContext context, Player player) {
    final role = player.role!;
    final bool isLiberal = role == Role.liberal;
    final bool isHitler = role == Role.secretHitler;

    final Color cardColor = isLiberal ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D);
    final Color accentColor = isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFE05252);
    final String roleName = role.name.toUpperCase();
    final String partyName = role.partyName.toUpperCase();

    // Determine description and teammates information
    String instructions = '';
    String teammateInfo = '';

    if (isLiberal) {
      instructions =
          'Your objective is to enact 5 Liberal Policies or find and execute Secret Hitler. Work with other players to identify the Fascist threat.';
    } else if (role == Role.fascist) {
      instructions =
          'Your objective is to enact 6 Fascist Policies or elect Secret Hitler as Chancellor after 3 Fascist policies are enacted.';

      final otherFascists = engine.players
          .where((p) => p.role == Role.fascist && p.id != player.id)
          .map((p) => p.name)
          .toList();
      final hitlerPlayer = engine.players.firstWhere((p) => p.role == Role.secretHitler);

      if (engine.players.length <= 6) {
        teammateInfo = 'SECRET HITLER: ${hitlerPlayer.name}';
      } else {
        final fascistsStr = otherFascists.isEmpty ? 'None' : otherFascists.join(', ');
        teammateInfo = 'OTHER FASCISTS: $fascistsStr\nSECRET HITLER: ${hitlerPlayer.name}';
      }
    } else if (isHitler) {
      if (engine.players.length <= 6) {
        // In 5-6 player games, Hitler knows who the fascist is
        final fascistPlayer = engine.players.firstWhere((p) => p.role == Role.fascist);
        instructions = 'You are Secret Hitler. Your objective is to be elected Chancellor after 3 Fascist policies are enacted.';
        teammateInfo = 'YOUR FASCIST ASSISTANT: ${fascistPlayer.name}';
      } else {
        // In larger games, Hitler does not know who the fascists are
        instructions = 'You are Secret Hitler. You DO NOT know who your fascists are! Try to get elected Chancellor or coordinate secretly.';
        teammateInfo = 'FASCISTS: You do not know who the Fascists are.';
      }
    }

    return Container(
      key: const ValueKey('identity_card'),
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.3),
            blurRadius: 16,
            spreadRadius: 2,
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isHitler ? 'SECRET IDENTITY' : 'SECRET ROLE',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            roleName,
            style: TextStyle(
              color: isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
              fontFamily: 'serif',
              fontWeight: FontWeight.w900,
              fontSize: 34,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'PARTY: $partyName',
              style: TextStyle(
                color: isLiberal ? Colors.blue.shade100 : Colors.red.shade100,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              isLiberal
                  ? 'assets/images/liberal_role.png'
                  : (isHitler ? 'assets/images/hitler_role.png' : 'assets/images/fascist_role.png'),
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              instructions,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          if (teammateInfo.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                teammateInfo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
