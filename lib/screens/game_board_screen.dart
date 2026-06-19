import 'package:flutter/material.dart';
import '../logic/game_engine.dart';
import '../logic/sound_manager.dart';
import '../models/game_state.dart';
import '../widgets/board_widgets.dart';

class GameBoardScreen extends StatefulWidget {
  final GameEngine engine;
  final VoidCallback onQuit;

  const GameBoardScreen({
    Key? key,
    required this.engine,
    required this.onQuit,
  }) : super(key: key);

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  // Keeps track of the selected tab: 0 = Board, 1 = Players & Logs
  int _activeTab = 0;

  // Temp map to hold votes before submitting
  final Map<int, bool> _localVotes = {};

  // For loyalty investigation private view
  bool _showingInvestigationResult = false;

  GamePhase? _lastPhase;
  int? _lastFas;
  int? _lastLib;
  bool _hasAnnouncedThirdFascistPower = false;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChange);
    _lastPhase = widget.engine.phase;
    _lastFas = widget.engine.fascistPolicies;
    _lastLib = widget.engine.liberalPolicies;
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChange);
    SoundManager.stopLoop(); // Stop loops when screen is disposed
    super.dispose();
  }

  void _onEngineChange() {
    final currentPhase = widget.engine.phase;
    final currentFas = widget.engine.fascistPolicies;
    final currentLib = widget.engine.liberalPolicies;

    // Check if a new card was placed (policies count increased)
    if (_lastFas != null && _lastLib != null) {
      if (currentFas > _lastFas! || currentLib > _lastLib!) {
        // Automatically switch to board tab (Tab 0)
        setState(() {
          _activeTab = 0;
        });
      }
    }
    _lastFas = currentFas;
    _lastLib = currentLib;

    if (currentPhase != _lastPhase) {
      _lastPhase = currentPhase;

      // Check if we need to show the 3rd fascist policy announcement
      if (currentPhase == GamePhase.executiveAction && currentFas == 3) {
        if (!_hasAnnouncedThirdFascistPower) {
          _hasAnnouncedThirdFascistPower = true;
          // Trigger the dialog after the build completes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showThirdFascistPolicyAnnouncement();
          });
        }
      } else {
        // Reset the announcement flag if we leave the phase
        _hasAnnouncedThirdFascistPower = false;
      }
    }
  }

  void _showThirdFascistPolicyAnnouncement() {
    final chancellorName = widget.engine.currentChancellor?.name ?? 'نامشخص';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF2C2523),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFD4AF37), size: 28),
                SizedBox(width: 8),
                Text(
                  'اعلامیه قدرت ویژه صدراعظم',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6DFD3),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سومین سیاست فاشیستی تصویب شد!',
                  style: TextStyle(
                    color: Color(0xFFC92A2A),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'صدراعظم اکنون این قدرت ویژه را دارد که وفاداری حزبی یکی از بازیکنان را بررسی کند.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'صدراعظم فعلی: $chancellorName',
                        style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9E2A2B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('متوجه شدم'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        final phase = widget.engine.phase;

        if (phase == GamePhase.gameOver) {
          return _buildGameOverScreen();
        }

        return Scaffold(
          backgroundColor: const Color(0xFF1B1816),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2C2523),
            title: const Text(
              'SECRET HITLER',
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Color(0xFF9E2A2B)),
                onPressed: () {
                  _showQuitConfirmation();
                },
              ),
            ],
          ),
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/wood_table_background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                // Tab Selector
                _buildTabSelector(),

                // Core content based on active tab
                Expanded(
                  child: _activeTab == 0
                      ? _buildBoardTab()
                      : _buildPlayersAndLogsTab(),
                ),

                // Dynamic Action Sheet at the bottom
                _buildActionPanel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: const Color(0xFF2C2523),
      child: Row(
        children: [
          _buildTabButton(0, 'GAME BOARD', Icons.dashboard),
          _buildTabButton(1, 'PLAYERS & LOGS', Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final bool isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFD4AF37) : Colors.transparent,
                width: 3.0,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? const Color(0xFFD4AF37) : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          PolicyTrackWidget(
            type: PolicyType.liberal,
            count: widget.engine.liberalPolicies,
            totalSlots: 5,
            playerCount: widget.engine.players.length,
          ),
          PolicyTrackWidget(
            type: PolicyType.fascist,
            count: widget.engine.fascistPolicies,
            totalSlots: 6,
            playerCount: widget.engine.players.length,
          ),
          ElectionTrackerWidget(count: widget.engine.electionTracker),
          _buildLastElectionResultWidget(),
          const SizedBox(height: 16),
          // Info stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('DECK', '${widget.engine.deckCount} cards', Icons.style),
                _buildStatBadge('DISCARD', '${widget.engine.discardCount} cards', Icons.delete_outline),
                _buildStatBadge('ALIVE', '${widget.engine.alivePlayersCount}/${widget.engine.players.length}', Icons.favorite_border),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLastElectionResultWidget() {
    final lastResult = widget.engine.lastElectionResult;
    if (lastResult == null) return const SizedBox.shrink();

    final nomineeName = lastResult['nomineeName'] ?? 'نامشخص';
    final passed = lastResult['passed'] == true;
    final Map<String, bool> playerVotes = Map<String, bool>.from(lastResult['votes'] ?? {});

    if (playerVotes.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6251E1C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: passed ? const Color(0xFF1D4426).withOpacity(0.5) : const Color(0xFF9E2A2B).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'آخرین نتیجه انتخابات',
                    style: TextStyle(
                      fontFamily: 'serif',
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نامزد صدراعظمی: $nomineeName',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: passed ? const Color(0xFF112E18) : const Color(0xFF5C1A1B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: passed ? const Color(0xFF2B9E49) : const Color(0xFF9E2A2B),
                    width: 1,
                  ),
                ),
                child: Text(
                  passed ? 'تایید شد (موافق)' : 'رد شد (مخالف)',
                  style: TextStyle(
                    color: passed ? const Color(0xFF8CE99A) : const Color(0xFFFF847C),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: playerVotes.entries.map((entry) {
                final name = entry.key;
                final vote = entry.value == true;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: vote ? const Color(0xFF112E18).withOpacity(0.3) : const Color(0xFF5C1A1B).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: vote ? const Color(0xFF2B9E49).withOpacity(0.4) : const Color(0xFF9E2A2B).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        vote ? Icons.check_circle_outline : Icons.cancel_outlined,
                        color: vote ? const Color(0xFF8CE99A) : const Color(0xFFFF847C),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersAndLogsTab() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PLAYERS LIST',
            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: widget.engine.players.length,
              itemBuilder: (context, index) {
                final player = widget.engine.players[index];
                final bool isPresident = index == widget.engine.presidentIndex;
                final bool isChancellor = index == widget.engine.chancellorIndex;
                final bool isNominatedChancellor = index == widget.engine.nominatedChancellorIndex;
                final bool isEligible = widget.engine.isEligibleForChancellor(index);

                return PlayerSlotWidget(
                  player: player,
                  isPresident: isPresident,
                  isChancellor: isChancellor,
                  isNominatedChancellor: isNominatedChancellor,
                  isEligible: isEligible,
                  onTap: () {
                    _onPlayerTapped(index);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'GAME LOGS (NEWEST FIRST)',
            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: widget.engine.logs.length,
                itemBuilder: (context, index) {
                  final log = widget.engine.logs[widget.engine.logs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      log,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Handle player tapping depending on phase
  void _onPlayerTapped(int index) {
    final phase = widget.engine.phase;

    if (phase == GamePhase.electionNomination) {
      if (widget.engine.isEligibleForChancellor(index)) {
        widget.engine.nominateChancellor(index);
      }
    } else if (phase == GamePhase.executiveAction) {
      final power = widget.engine.activePower;
      if (index == widget.engine.powerExecutorIndex || !widget.engine.players[index].isAlive) return;

      if (power == ExecutivePower.investigateLoyalty) {
        widget.engine.executeInvestigateLoyalty(index);
        setState(() {
          _showingInvestigationResult = true;
        });
      } else if (power == ExecutivePower.callSpecialElection) {
        widget.engine.executeCallSpecialElection(index);
      } else if (power == ExecutivePower.execution) {
        _showExecutionConfirmation(index);
      }
    }
  }

  Widget _buildActionPanel() {
    final phase = widget.engine.phase;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF2C2523),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, -3),
          )
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionHeader(phase),
          const SizedBox(height: 12),
          _buildActionBody(phase),
        ],
      ),
    );
  }

  Widget _buildActionHeader(GamePhase phase) {
    String title = '';
    String subtitle = '';

    switch (phase) {
      case GamePhase.electionNomination:
        title = 'CHANCELLOR ELECTION';
        subtitle = 'President ${widget.engine.currentPresident.name}, nominate an eligible Chancellor candidate (tap them in the Player list).';
        break;
      case GamePhase.electionVoting:
        title = 'CAST VOTES';
        subtitle = 'Record votes for Chancellor candidate ${widget.engine.nominatedChancellor!.name}.';
        break;
      case GamePhase.legislativePresident:
        title = 'LEGISLATIVE SESSION';
        subtitle = 'President ${widget.engine.currentPresident.name}, discard 1 policy to pass remaining 2 to the Chancellor.';
        break;
      case GamePhase.legislativeChancellor:
        title = 'LEGISLATIVE SESSION';
        subtitle = 'Chancellor ${widget.engine.currentChancellor!.name}, choose 1 policy to enact. The other card will be discarded.';
        break;
      case GamePhase.executiveAction:
        final executorTitle = widget.engine.fascistPolicies == 3 ? 'CHANCELLOR' : 'PRESIDENT';
        title = '$executorTitle POWER UNLOCKED';
        subtitle = _getPowerSubtitle(executorTitle);
        break;
      default:
        title = 'GAME PHASE';
        subtitle = '';
    }

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getPowerSubtitle(String executorTitle) {
    final power = widget.engine.activePower;
    switch (power) {
      case ExecutivePower.investigateLoyalty:
        return 'Investigate Loyalty: $executorTitle ${widget.engine.powerExecutorName}, select an alive player to inspect their party membership card.';
      case ExecutivePower.policyPeek:
        return 'Policy Peek: $executorTitle ${widget.engine.powerExecutorName}, view the top 3 cards in the policy deck.';
      case ExecutivePower.callSpecialElection:
        return 'Special Election: $executorTitle ${widget.engine.powerExecutorName}, select an alive player to take the next Presidency.';
      case ExecutivePower.execution:
        return 'Execution: $executorTitle ${widget.engine.powerExecutorName}, select an alive player to eliminate from the game.';
      default:
        return '';
    }
  }

  Widget _buildActionBody(GamePhase phase) {
    switch (phase) {
      case GamePhase.electionNomination:
        return ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _activeTab = 1; // Direct them to the players tab
            });
          },
          icon: const Icon(Icons.people),
          label: const Text('VIEW ELIGIBLE PLAYERS'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
          ),
        );

      case GamePhase.electionVoting:
        return _buildVotingPanel();

      case GamePhase.legislativePresident:
        return _buildLegislativeCards(isPresident: true);

      case GamePhase.legislativeChancellor:
        return _buildLegislativeCards(isPresident: false);

      case GamePhase.executiveAction:
        return _buildExecutivePowerPanel();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVotingPanel() {
    final alivePlayers = widget.engine.players.where((p) => p.isAlive).toList();

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            _showVoteRecordDialog(context, alivePlayers);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9E2A2B),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('RECORD VOTES'),
        ),
      ],
    );
  }

  void _showVoteRecordDialog(BuildContext context, List<Player> alivePlayers) {
    // Populate local votes
    for (var player in alivePlayers) {
      _localVotes.putIfAbsent(player.id, () => true); // default Ja
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2523),
              title: const Text(
                'Record Player Votes',
                style: TextStyle(color: Color(0xFFE6DFD3), fontFamily: 'serif'),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: alivePlayers.length,
                  itemBuilder: (context, index) {
                    final player = alivePlayers[index];
                    final bool isJa = _localVotes[player.id] ?? true;

                    return ListTile(
                      title: Text(player.name, style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ChoiceChip(
                            label: const Text('Ja'),
                            selected: isJa,
                            selectedColor: const Color(0xFF438A5E),
                            labelStyle: TextStyle(color: isJa ? Colors.black : Colors.white),
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  _localVotes[player.id] = true;
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Nein'),
                            selected: !isJa,
                            selectedColor: const Color(0xFF9E2A2B),
                            labelStyle: TextStyle(color: !isJa ? Colors.white : Colors.white60),
                            onSelected: (selected) {
                              if (selected) {
                                setDialogState(() {
                                  _localVotes[player.id] = false;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Copy local votes to engine
                    _localVotes.forEach((playerIdx, vote) {
                      widget.engine.castVote(playerIdx, vote);
                    });
                    widget.engine.tallyVotes();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                  child: const Text('Submit Votes', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLegislativeCards({required bool isPresident}) {
    final policies = widget.engine.drawnPolicies;

    return Column(
      children: [
        Text(
          isPresident ? 'CLICK A CARD TO DISCARD IT' : 'CLICK A CARD TO ENACT IT',
          style: const TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(policies.length, (index) {
            final policy = policies[index];
            final bool isLiberal = policy == PolicyType.liberal;

            return GestureDetector(
              onTap: () {
                if (isPresident) {
                  widget.engine.presidentDiscardPolicy(index);
                } else {
                  widget.engine.chancellorEnactPolicy(index);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: isLiberal ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFE05252),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLiberal ? Icons.verified_user : Icons.gavel,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isLiberal ? 'LIBERAL' : 'FASCIST',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildExecutivePowerPanel() {
    final power = widget.engine.activePower;

    if (power == ExecutivePower.policyPeek) {
      final peeked = widget.engine.drawnPolicies;

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(peeked.length, (index) {
              final policy = peeked[index];
              final bool isLiberal = policy == PolicyType.liberal;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                width: 70,
                height: 100,
                decoration: BoxDecoration(
                  color: isLiberal ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFE05252),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  isLiberal ? 'LIBERAL' : 'FASCIST',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              widget.engine.completePolicyPeek();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E2A27),
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('CONFIRM & CLOSE PEEK'),
          ),
        ],
      );
    }

    if (power == ExecutivePower.investigateLoyalty && _showingInvestigationResult) {
      final target = widget.engine.players[widget.engine.investigatedPlayerIndex];
      final party = widget.engine.investigatedParty;

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  'Loyalty investigation result for ${target.name}:',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  party == 'Liberal' ? 'MEMBER OF LIBERAL PARTY' : 'MEMBER OF FASCIST PARTY',
                  style: TextStyle(
                    color: party == 'Liberal' ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showingInvestigationResult = false;
              });
              widget.engine.completeInvestigateLoyalty();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E2A27),
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('CLOSE RESULT'),
          ),
        ],
      );
    }

    // Default button prompting them to use players tab
    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _activeTab = 1;
        });
      },
      icon: const Icon(Icons.touch_app),
      label: const Text('SELECT TARGET PLAYER'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white12,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showExecutionConfirmation(int index) {
    final target = widget.engine.players[index];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2523),
          title: const Text('Confirm Execution', style: TextStyle(color: Color(0xFF9E2A2B), fontFamily: 'serif')),
          content: Text(
            'Are you sure you want to execute ${target.name}? This action is permanent and cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.engine.executeExecution(index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
              child: const Text('Execute Player', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameOverScreen() {
    final isLiberalWin = widget.engine.winner == 'Liberals';

    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                isLiberalWin ? Icons.verified_user : Icons.dangerous,
                size: 100,
                color: isLiberalWin ? const Color(0xFF75B2FF) : const Color(0xFFE05252),
              ),
              const SizedBox(height: 24),
              Text(
                '${widget.engine.winner!.toUpperCase()} WIN!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLiberalWin ? const Color(0xFF75B2FF) : const Color(0xFFE05252),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  widget.engine.winReason ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'ROLE REVEAL:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 4,
                child: ListView.builder(
                  itemCount: widget.engine.players.length,
                  itemBuilder: (context, index) {
                    final player = widget.engine.players[index];
                    final bool isLib = player.role == Role.liberal;

                    return ListTile(
                      title: Text(
                        player.name,
                        style: TextStyle(
                          color: player.isAlive ? Colors.white : Colors.white30,
                          decoration: player.isAlive ? TextDecoration.none : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        player.role!.name,
                        style: TextStyle(
                          color: isLib ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        player.isAlive ? 'ALIVE' : 'EXECUTED',
                        style: TextStyle(
                          color: player.isAlive ? Colors.green : Colors.red,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: widget.onQuit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9E2A2B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('BACK TO MENU', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2523),
          title: const Text('Quit Game?', style: TextStyle(color: Color(0xFFE6DFD3), fontFamily: 'serif')),
          content: const Text(
            'Are you sure you want to quit this game? Progress will be lost.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onQuit();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
              child: const Text('Quit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
