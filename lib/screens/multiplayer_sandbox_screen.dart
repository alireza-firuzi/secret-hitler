import 'dart:math';
import 'package:flutter/material.dart';
import '../logic/firebase_manager.dart';
import '../logic/online_game_engine.dart';
import 'online_lobby_screen.dart';
import 'online_game_board_screen.dart';

class MultiplayerSandboxScreen extends StatefulWidget {
  final String lobbyCode;
  final String initialPlayerName;
  final String initialPlayerId;
  final VoidCallback onLeave;

  const MultiplayerSandboxScreen({
    Key? key,
    required this.lobbyCode,
    required this.initialPlayerName,
    required this.initialPlayerId,
    required this.onLeave,
  }) : super(key: key);

  @override
  State<MultiplayerSandboxScreen> createState() => _MultiplayerSandboxScreenState();
}

class _MultiplayerSandboxScreenState extends State<MultiplayerSandboxScreen> {
  // Local list of players in this sandbox session
  final List<Map<String, String>> _virtualPlayers = [];
  int _activePlayerIndex = 0;

  // Track the active OnlineGameEngine instance for each player
  final Map<String, OnlineGameEngine> _engines = {};

  @override
  void initState() {
    super.initState();
    // Add initial host player
    _virtualPlayers.add({
      'id': widget.initialPlayerId,
      'name': widget.initialPlayerName,
    });
    _prepopulatePlayers();
  }

  // Prepopulate with 4 extra players to reach the minimum 5 players needed for Secret Hitler
  Future<void> _prepopulatePlayers() async {
    final defaultNames = ['Bob', 'Charlie', 'Dave', 'Eve'];
    for (var name in defaultNames) {
      final id = 'user_${name.toLowerCase()}';
      _virtualPlayers.add({'id': id, 'name': name});
      await FirebaseManager.joinGame(
        lobbyCode: widget.lobbyCode,
        playerName: name,
        playerId: id,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    for (var engine in _engines.values) {
      engine.dispose();
    }
    super.dispose();
  }

  Future<void> _addVirtualPlayer() async {
    if (_virtualPlayers.length >= 10) return;

    final List<String> names = ['Frank', 'Grace', 'Heidi', 'Ivan', 'Judy'];
    final existingNames = _virtualPlayers.map((p) => p['name']!).toList();
    final String nextName = names.firstWhere((n) => !existingNames.contains(n), orElse: () => 'Player ${_virtualPlayers.length + 1}');

    final String id = 'user_${nextName.toLowerCase().replaceAll(' ', '_')}';
    
    setState(() {
      _virtualPlayers.add({'id': id, 'name': nextName});
    });

    await FirebaseManager.joinGame(
      lobbyCode: widget.lobbyCode,
      playerName: nextName,
      playerId: id,
    );
  }

  OnlineGameEngine _getEngine(Map<String, String> player) {
    final id = player['id']!;
    return _engines.putIfAbsent(
      id,
      () => OnlineGameEngine(
        lobbyCode: widget.lobbyCode,
        localPlayerId: id,
        localPlayerName: player['name']!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activePlayer = _virtualPlayers[_activePlayerIndex];
    final activeEngine = _getEngine(activePlayer);

    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: Column(
        children: [
          // Top Sandbox Control Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0E0D),
              border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1.5)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.developer_mode, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'MULTIPLAYER TEST SANDBOX',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const Spacer(),
                      // Add virtual player button
                      if (_virtualPlayers.length < 10)
                        TextButton.icon(
                          onPressed: _addVirtualPlayer,
                          icon: const Icon(Icons.person_add, size: 14, color: Color(0xFF75B2FF)),
                          label: const Text('ADD PLAYER', style: TextStyle(fontSize: 10, color: Color(0xFF75B2FF))),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Player Switcher Tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(_virtualPlayers.length, (index) {
                        final player = _virtualPlayers[index];
                        final bool isActive = _activePlayerIndex == index;
                        final bool isHost = index == 0;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _activePlayerIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActive ? const Color(0xFFFFD700) : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  player['name']!,
                                  style: TextStyle(
                                    color: isActive ? Colors.black : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isHost) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(Host)',
                                    style: TextStyle(
                                      color: isActive ? Colors.black54 : Colors.white30,
                                      fontSize: 8,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active Player Device Viewport
          Expanded(
            child: ListenableBuilder(
              listenable: activeEngine,
              builder: (context, _) {
                switch (activeEngine.status) {
                  case 'lobby':
                    return OnlineLobbyScreen(
                      engine: activeEngine,
                      onLeave: widget.onLeave,
                    );
                  case 'playing':
                    return OnlineGameBoardScreen(
                      engine: activeEngine,
                      onQuit: widget.onLeave,
                    );
                  default:
                    return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
