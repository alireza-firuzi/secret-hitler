import 'dart:async';
import 'package:flutter/material.dart';
import '../logic/online_game_engine.dart';
import '../logic/sound_manager.dart';
import '../models/game_state.dart';
import '../widgets/board_widgets.dart';
import 'lie_detector_screen.dart';

class OnlineGameBoardScreen extends StatefulWidget {
  final OnlineGameEngine engine;
  final VoidCallback onQuit;

  const OnlineGameBoardScreen({
    Key? key,
    required this.engine,
    required this.onQuit,
  }) : super(key: key);

  @override
  State<OnlineGameBoardScreen> createState() => _OnlineGameBoardScreenState();
}

class _OnlineGameBoardScreenState extends State<OnlineGameBoardScreen> {
  int _activeTab = 0;
  bool _showingLoyaltyResult = false;
  bool _revealSecretCard = false;

  String? _lastPhase;
  int? _lastFas;
  int? _lastLib;
  bool _hasAnnouncedThirdFascistPower = false;
  bool _hasAnnouncedExecutionPower = false;
  String? _lastNarrationId;

  @override
  void initState() {
    super.initState();
    widget.engine.addListener(_onEngineChange);
    _lastPhase = widget.engine.phaseStr;
    _lastFas = widget.engine.fascistPolicies;
    _lastLib = widget.engine.liberalPolicies;
    _lastNarrationId = widget.engine.narrationId;
  }

  @override
  void dispose() {
    widget.engine.removeListener(_onEngineChange);
    super.dispose();
  }

  void _onEngineChange() {
    final currentPhase = widget.engine.phaseStr;
    final currentFas = widget.engine.fascistPolicies;
    final currentLib = widget.engine.liberalPolicies;
    final currentNarrationId = widget.engine.narrationId;
    final currentNarration = widget.engine.narration;

    // Check for new AI speech narration
    if (currentNarrationId.isNotEmpty && currentNarrationId != _lastNarrationId) {
      _lastNarrationId = currentNarrationId;
      SoundManager.playSpeech(currentNarration);
    }

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
      final oldPhase = _lastPhase;
      _lastPhase = currentPhase;

      // Show election results popup if the election phase just ended
      if (oldPhase == 'electionVoting') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showElectionResultDialog();
        });
      }

      // Check if we need to show the 3rd fascist policy announcement
      if (currentPhase == 'executiveAction' && currentFas == 3) {
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

      // Check if we need to show the execution power announcement
      if (currentPhase == 'executiveAction' && widget.engine.activePowerStr == 'execution') {
        if (!_hasAnnouncedExecutionPower) {
          _hasAnnouncedExecutionPower = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showExecutionPowerAnnouncement();
          });
        }
      } else {
        // Reset the announcement flag if we leave the phase
        _hasAnnouncedExecutionPower = false;
      }
    }
  }

  void _showElectionResultDialog() {
    final lastResult = widget.engine.lastElectionResult;
    if (lastResult == null) return;

    final nomineeName = lastResult['nomineeName'] ?? 'نامشخص';
    final passed = lastResult['passed'] == true;
    final Map<String, dynamic> rawVotes = Map<String, dynamic>.from(lastResult['votes'] ?? {});

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
              side: BorderSide(
                color: passed ? const Color(0xFF2B9E49) : const Color(0xFF9E2A2B),
                width: 2,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? const Color(0xFF2B9E49) : const Color(0xFF9E2A2B),
                  size: 28,
                ),
                const SizedBox(width: 8),
                const Text(
                  'نتیجه انتخابات صدراعظمی',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: Color(0xFFE6DFD3),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    passed
                        ? 'انتخابات برای صدراعظمی «$nomineeName» تایید شد! وی اکنون صدراعظم است.'
                        : 'انتخابات برای صدراعظمی «$nomineeName» شکست خورد.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'آرای بازیکنان:',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...rawVotes.entries.map((entry) {
                    final name = _getPlayerNameById(entry.key);
                    final vote = entry.value == true;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(name, style: const TextStyle(color: Colors.white70)),
                          Row(
                            children: [
                              Icon(
                                vote ? Icons.check : Icons.close,
                                color: vote ? const Color(0xFF8CE99A) : const Color(0xFFFF847C),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                vote ? 'موافق (Ja)' : 'مخالف (Nein)',
                                style: TextStyle(
                                  color: vote ? const Color(0xFF8CE99A) : const Color(0xFFFF847C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: passed ? const Color(0xFF2B9E49) : const Color(0xFF9E2A2B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('فهمیدم', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showThirdFascistPolicyAnnouncement() {
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
                  'اعلامیه فاز حساس بازی',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6DFD3),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
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
                    'رئیس‌جمهور فعلی اکنون این قدرت را دارد که وفاداری حزبی یکی از بازیکنان را بررسی کند.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5C1A1B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF9E2A2B).withOpacity(0.5)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Color(0xFFFF847C), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'هشدار بسیار مهم و حیاتی:',
                              style: TextStyle(color: Color(0xFFFF847C), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'از این لحظه به بعد، اگر هیتلر مخفی به عنوان صدراعظم انتخاب شود (و رای انتخابات تایید شود)، فاشیست‌ها فوراً برنده بازی خواهند شد! در انتخاب نامزدها و رای‌های خود بسیار دقت کنید.',
                          style: TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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

  void _showExecutionPowerAnnouncement() {
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
              side: const BorderSide(color: Color(0xFF9E2A2B), width: 2),
            ),
            title: const Row(
              children: [
                Icon(Icons.gavel, color: Color(0xFF9E2A2B), size: 28),
                SizedBox(width: 8),
                Text(
                  'فعال شدن قدرت ترور',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE6DFD3),
                  ),
                ),
              ],
            ),
            content: const SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'یک سیاست فاشیستی جدید تصویب شد!',
                    style: TextStyle(
                      color: Color(0xFFC92A2A),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'قدرت ترور (اعدام) فعال شد! رئیس‌جمهور اکنون باید یکی از بازیکنان را برای ترور انتخاب کند.',
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'نکته مهم: بازیکن ترور شده به طور کامل از بازی حذف می‌شود. اگر هیتلر مخفی ترور شود، لیبرال‌ها فوراً برنده بازی خواهند شد!',
                    style: TextStyle(color: Color(0xFF8CE99A), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
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

  String _translateWinner(String? winner) {
    if (winner == 'Liberals') return 'لیبرال‌ها';
    if (winner == 'Fascists') return 'فاشیست‌ها';
    return winner ?? '';
  }

  String _translateRole(String role) {
    switch (role) {
      case 'Liberal':
        return 'لیبرال';
      case 'Fascist':
        return 'فاشیست';
      case 'Secret Hitler':
        return 'هیتلر مخفی';
      default:
        return role;
    }
  }

  String _translateWinReason(String? reason) {
    if (reason == null) return '';
    if (reason.contains('elected')) {
      return 'هیتلر مخفی پس از تصویب ۳ سیاست فاشیستی به عنوان صدراعظم انتخاب شد!';
    }
    if (reason.contains('5 Liberal policies')) {
      return '۵ سیاست لیبرال تصویب شده است!';
    }
    if (reason.contains('6 Fascist policies')) {
      return '۶ سیاست فاشیستی تصویب شده است!';
    }
    if (reason.contains('executed')) {
      return 'هیتلر مخفی ترور شد!';
    }
    return reason;
  }

  String _translatePower(String power) {
    switch (power) {
      case 'investigateLoyalty':
        return 'بررسی وفاداری';
      case 'policyPeek':
        return 'مشاهده کارت‌های سیاست';
      case 'callSpecialElection':
        return 'انتخابات ویژه';
      case 'execution':
        return 'ترور';
      default:
        return power;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.engine,
      builder: (context, _) {
        if (widget.engine.isLoading) {
          return const Scaffold(
            backgroundColor: Color(0xFF1B1816),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ),
          );
        }

        if (widget.engine.phaseStr == 'gameOver') {
          return _buildGameOverScreen();
        }

        // Check if any alive players are disconnected to pause the game
        final List<dynamic> players = widget.engine.players;
        final disconnectedPlayers = players
            .where((p) => p['isDisconnected'] == true && p['isAlive'] == true)
            .map((p) => p['name'] as String)
            .toList();

        Widget content = Scaffold(
          backgroundColor: const Color(0xFF1B1816),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2C2523),
            title: Text(
              widget.engine.phaseStr == 'roleReveal' ? 'فاش‌سازی نقش‌ها' : 'بازی آنلاین',
              style: const TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
            ),
            centerTitle: true,
            actions: [
              if (widget.engine.phaseStr != 'roleReveal')
                IconButton(
                  icon: const Icon(Icons.fingerprint, color: Colors.cyan),
                  tooltip: 'دستگاه دروغ‌سنج',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LieDetectorScreen()),
                    );
                  },
                ),
              if (widget.engine.isHost && widget.engine.phaseStr != 'roleReveal')
                IconButton(
                  icon: const Icon(Icons.settings, color: Color(0xFFD4AF37)),
                  onPressed: _showDiscussionSettingsDialog,
                ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, color: Color(0xFF9E2A2B)),
                onPressed: _showQuitConfirmation,
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
            child: widget.engine.phaseStr == 'roleReveal'
                ? _buildRoleRevealView()
                : Column(
                    children: [
                      _buildTabSelector(),
                      Expanded(
                        child: _activeTab == 0
                            ? _buildBoardTab()
                            : _buildPlayersAndLogsTab(),
                      ),
                      _buildActionPanel(),
                      _buildSecretRoleAccessButton(),
                    ],
                  ),
          ),
        );

        if (disconnectedPlayers.isNotEmpty) {
          final disconnectedNamesStr = disconnectedPlayers.join('، ');
          content = Stack(
            children: [
              content,
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.85),
                    child: Center(
                      child: Card(
                        color: const Color(0xFF2C2523),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFF9E2A2B), width: 2),
                        ),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.pause_circle_filled,
                                color: Color(0xFF9E2A2B),
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'بازی متوقف شد',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  color: Color(0xFFE6DFD3),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'در انتظار اتصال مجدد بازیکن: $disconnectedNamesStr',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              const CircularProgressIndicator(
                                color: Color(0xFFD4AF37),
                                strokeWidth: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return content;
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      color: const Color(0xFF2C2523),
      child: Row(
        children: [
          _buildTabButton(0, 'صفحه بازی', Icons.dashboard),
          _buildTabButton(1, 'بازیکنان و گزارش‌ها', Icons.people_outline),
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
    final playersCount = widget.engine.players.length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          PolicyTrackWidget(
            type: PolicyType.liberal,
            count: widget.engine.liberalPolicies,
            totalSlots: 5,
            playerCount: playersCount,
          ),
          PolicyTrackWidget(
            type: PolicyType.fascist,
            count: widget.engine.fascistPolicies,
            totalSlots: 6,
            playerCount: playersCount,
          ),
          ElectionTrackerWidget(count: widget.engine.electionTracker),
          _buildLastElectionResultWidget(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('کارت‌ها', '${widget.engine.drawnPolicies.isEmpty ? "پنهان" : "?"} کارت', Icons.style),
                _buildStatBadge('زنده', '${widget.engine.alivePlayersCount} از ${playersCount}', Icons.favorite_border),
                _buildStatBadge('نام من', widget.engine.localPlayerName, Icons.account_circle_outlined),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getPlayerNameById(String id) {
    final player = widget.engine.players.firstWhere(
      (p) => p['id'] == id,
      orElse: () => null,
    );
    return player != null ? player['name'] : 'نامشخص';
  }

  Widget _buildLastElectionResultWidget() {
    final lastResult = widget.engine.lastElectionResult;
    if (lastResult == null) return const SizedBox.shrink();

    final nomineeName = lastResult['nomineeName'] ?? 'نامشخص';
    final passed = lastResult['passed'] == true;
    final Map<String, dynamic> playerVotes = Map<String, dynamic>.from(lastResult['votes'] ?? {});

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
                final playerId = entry.key;
                final vote = entry.value == true;
                final name = _getPlayerNameById(playerId);

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
    final players = widget.engine.players;

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'لیست بازیکنان',
            style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
          const SizedBox(height: 6),
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: players.length,
              itemBuilder: (context, index) {
                final playerMap = players[index];
                final String pId = playerMap['id'];

                final bool isPresident = index == widget.engine.presidentIndex;
                final bool isChancellor = index == widget.engine.chancellorIndex;
                final bool isNominatedChancellor = index == widget.engine.nominatedChancellorIndex;

                // Map database player properties back to Player model for widget compatibility
                final player = Player(
                  id: index,
                  name: playerMap['name'],
                  isAlive: playerMap['isAlive'] == true,
                  isInvestigated: playerMap['isInvestigated'] == true,
                  avatar: playerMap['avatar'] ?? 'avatar_1',
                  totalSpeakingTime: playerMap['totalSpeakingTime'] ?? 0,
                );

                // Term limit checks
                final bool isEligible = _isEligibleForChancellor(index);

                final bool isSpeaking = widget.engine.phaseStr == 'discussion' && index == widget.engine.activeDiscussionPlayerIndex;

                return PlayerSlotWidget(
                  player: player,
                  isPresident: isPresident,
                  isChancellor: isChancellor,
                  isNominatedChancellor: isNominatedChancellor,
                  isEligible: isEligible,
                  isSpeaking: isSpeaking,
                  onTap: () {
                    _onPlayerTapped(index);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'گزارش‌های بازی (جدیدترین در ابتدا)',
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

  bool _isEligibleForChancellor(int index) {
    if (widget.engine.phaseStr != 'electionNomination') return false;
    final players = widget.engine.players;
    final player = players[index];

    if (player['isAlive'] != true) return false;
    if (index == widget.engine.presidentIndex) return false; // Self nomination

    final aliveCount = widget.engine.alivePlayersCount;
    if (aliveCount == 5) {
      return index != widget.engine.previousChancellorIndex;
    } else {
      return index != widget.engine.previousChancellorIndex && index != widget.engine.previousPresidentIndex;
    }
  }

  void _onPlayerTapped(int index) {
    final phase = widget.engine.phaseStr;

    if (phase == 'electionNomination' && widget.engine.isMyTurnPresident) {
      if (_isEligibleForChancellor(index)) {
        widget.engine.nominateChancellor(index);
      }
    } else if (phase == 'executiveAction' && widget.engine.isMyTurnToExecutePower) {
      final power = widget.engine.activePowerStr;
      final target = widget.engine.players[index];
      if (index == widget.engine.powerExecutorIndex || target['isAlive'] != true) return;

      if (power == 'investigateLoyalty') {
        if (widget.engine.investigatedPlayerIndex != -1) return;
        widget.engine.executeInvestigateLoyalty(index);
        setState(() {
          _showingLoyaltyResult = true;
        });
      } else if (power == 'callSpecialElection') {
        widget.engine.executeCallSpecialElection(index);
      } else if (power == 'execution') {
        _showExecutionConfirmation(index);
      }
    }
  }

  Widget _buildRoleRevealView() {
    final role = widget.engine.myRoleName;
    final party = widget.engine.myPartyName;
    final info = widget.engine.myTeammateInfo;
    final bool isLib = party == 'Liberal';

    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'تنظیمات محرمانه',
            style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _revealSecretCard
                  ? _buildIdentityCardReveal(role, party, info, isLib)
                  : _buildEnvelopeCoverReveal(),
            ),
          ),

          const SizedBox(height: 24),
          if (widget.engine.isHost)
            ElevatedButton(
              onPressed: () {
                widget.engine.confirmRoleReveal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9E2A2B),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 8,
              ),
              child: const Text('رفتن به انتخابات', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'منتظر شروع انتخابات توسط میزبان...',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnvelopeCoverReveal() {
    return Container(
      key: const ValueKey('envelope_cover_reveal'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              // Silent
              setState(() {
                _revealSecretCard = true;
              });
            },
            child: _buildWaxSealReveal(),
          ),
          const SizedBox(height: 24),
          Text(
            widget.engine.localPlayerName,
            style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'serif'),
          ),
          const SizedBox(height: 10),
          const Text(
            'روی مهر موم کلیک کنید تا کارت نقش مخفی خود را باز کنید.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildWaxSealReveal() {
    return Image.asset(
      'assets/images/wax_seal.png',
      width: 100,
      height: 100,
      fit: BoxFit.contain,
    );
  }

  Widget _buildIdentityCardReveal(String role, String party, String info, bool isLib) {
    final Color cardColor = isLib ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D);
    final Color accentColor = isLib ? const Color(0xFF75B2FF) : const Color(0xFFE05252);

    return Container(
      key: const ValueKey('identity_card_reveal'),
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor, width: 2),
        boxShadow: [
          BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 1)
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const Text('نقش مخفی شما', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    _translateRole(role),
                    style: TextStyle(
                      color: isLib ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
                      fontFamily: 'serif',
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'حزب: ${_translateRole(party)}',
                      style: TextStyle(
                        color: isLib ? Colors.blue.shade100 : Colors.red.shade100,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      isLib
                          ? 'assets/images/liberal_role.png'
                          : (role == 'Secret Hitler' ? 'assets/images/hitler_role.png' : 'assets/images/fascist_role.png'),
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isLib
                        ? 'هدف: تصویب ۵ سیاست لیبرال یا ترور هیتلر مخفی. با بقیه لیبرال‌ها همکاری کنید.'
                        : 'هدف: تصویب ۶ سیاست فاشیستی یا انتخاب هیتلر مخفی به عنوان صدراعظم پس از تصویب ۳ سیاست فاشیستی.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                  ),
                  if (info.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        info,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10, fontWeight: FontWeight.bold, height: 1.3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _revealSecretCard = false;
              });
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 38),
            ),
            child: const Text('پنهان کردن کارت', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    final phase = widget.engine.phaseStr;
    final isPres = widget.engine.isMyTurnPresident;
    final isChan = widget.engine.isMyTurnChancellor;

    final isDiscussion = phase == 'discussion';
    final speakerIndex = isDiscussion ? widget.engine.activeDiscussionPlayerIndex : -1;
    final isMyDiscussionTurn = isDiscussion &&
        speakerIndex != -1 &&
        speakerIndex < widget.engine.players.length &&
        widget.engine.players[speakerIndex]['id'] == widget.engine.localPlayerId;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2523),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: isMyDiscussionTurn
            ? const Border(
                top: BorderSide(color: Color(0xFFD4AF37), width: 2),
                left: BorderSide(color: Color(0xFFD4AF37), width: 2),
                right: BorderSide(color: Color(0xFFD4AF37), width: 2),
              )
            : null,
        boxShadow: [
          if (isMyDiscussionTurn)
            BoxShadow(
              color: const Color(0xFFD4AF37).withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 3,
              offset: const Offset(0, -3),
            )
          else
            const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -3))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionHeader(phase, isPres, isChan),
          const SizedBox(height: 10),
          _buildActionBody(phase, isPres, isChan),
        ],
      ),
    );
  }

  Widget _buildActionHeader(String phase, bool isPres, bool isChan) {
    String title = '';
    String subtitle = '';

    final currentPresName = widget.engine.players.isNotEmpty && widget.engine.presidentIndex < widget.engine.players.length
        ? widget.engine.players[widget.engine.presidentIndex]['name']
        : '';
    final currentChanName = widget.engine.chancellorIndex != -1 && widget.engine.chancellorIndex < widget.engine.players.length
        ? widget.engine.players[widget.engine.chancellorIndex]['name']
        : '';

    switch (phase) {
      case 'electionNomination':
        title = 'انتخابات صدراعظم';
        subtitle = isPres
            ? 'شما رئیس‌جمهور هستید! یک نامزد واجد شرایط برای صدراعظمی معرفی کنید (از لیست بازیکنان روی نام او ضربه بزنید).'
            : 'رئیس‌جمهور $currentPresName در حال نامزد کردن صدراعظم است...';
        break;
      case 'electionVoting':
        title = 'رای‌گیری لابی';
        final nomineeName = widget.engine.nominatedChancellorIndex != -1
            ? widget.engine.players[widget.engine.nominatedChancellorIndex]['name']
            : '';
        final hasVoted = widget.engine.votes.containsKey(widget.engine.localPlayerId);

        subtitle = hasVoted
            ? 'رای ثبت شد. منتظر سایر بازیکنان... (${widget.engine.votes.length} از ${widget.engine.alivePlayersCount})'
            : 'رای موافق (Ja) یا مخالف (Nein) بدهید به نامزد صدراعظمی: $nomineeName';
        break;
      case 'legislativePresident':
        title = 'جلسه قانون‌گذاری';
        subtitle = isPres
            ? 'شما رئیس‌جمهور هستید! ۱ کارت سیاست را بسوزانید.'
            : 'رئیس‌جمهور $currentPresName در حال انتخاب یک کارت برای سوزاندن است...';
        break;
      case 'legislativeChancellor':
        title = 'جلسه قانون‌گذاری';
        subtitle = isChan
            ? 'شما صدراعظم هستید! ۱ کارت سیاست را تصویب کنید.'
            : 'صدراعظم $currentChanName در حال انتخاب یک کارت برای تصویب است...';
        break;
      case 'executiveAction':
        final executorTitle = widget.engine.fascistPolicies == 3 ? 'صدراعظم' : 'رئیس‌جمهور';
        title = 'قدرت $executorTitle فعال شد';
        final executorName = widget.engine.powerExecutorIndex != -1 && widget.engine.powerExecutorIndex < widget.engine.players.length
            ? widget.engine.players[widget.engine.powerExecutorIndex]['name']
            : '';
        final isExecutor = widget.engine.isMyTurnToExecutePower;
        subtitle = isExecutor
            ? _getPowerSubtitle(widget.engine.activePowerStr)
            : '$executorTitle $executorName در حال اجرای قدرت است: ${_translatePower(widget.engine.activePowerStr)}...';
        break;
      case 'discussion':
        final speakerIndex = widget.engine.activeDiscussionPlayerIndex;
        final speaker = speakerIndex != -1 && speakerIndex < widget.engine.players.length
            ? widget.engine.players[speakerIndex]
            : null;
        final isMyTurn = speaker != null && speaker['id'] == widget.engine.localPlayerId;
        final isTimerStarted = widget.engine.discussionEndTime > 0;
        
        if (isMyTurn) {
          title = '🚨 نوبت صحبت شماست 🚨';
          subtitle = isTimerStarted
              ? 'زمان صحبت شما شروع شده است! شروع به صحبت کنید.'
              : 'نوبت شماست! برای شروع تایمر، دکمه «شروع صحبت» را در پایین صفحه فشار دهید.';
        } else {
          title = 'نوبت صحبت بازیکنان';
          subtitle = isTimerStarted
              ? 'در حال حاضر، نوبت صحبت بازیکن ${speaker?['name'] ?? ''} است.'
              : 'منتظر شروع صحبت بازیکن ${speaker?['name'] ?? ''}...';
        }
        break;
      default:
        title = 'وضعیت آنلاین';
        subtitle = '';
    }

    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getPowerSubtitle(String power) {
    switch (power) {
      case 'investigateLoyalty':
        return 'بررسی وفاداری: روی یک بازیکن زنده از لیست ضربه بزنید تا حزب او را بررسی کنید.';
      case 'policyPeek':
        return 'مشاهده کارت‌های سیاست: روی دکمه ضربه بزنید تا ۳ کارت بالای دسته کارت‌ها را ببینید.';
      case 'callSpecialElection':
        return 'انتخابات ویژه: روی یک بازیکن زنده ضربه بزنید تا نامزد بعدی ریاست‌جمهوری شود.';
      case 'execution':
        return 'ترور: روی یک بازیکن زنده ضربه بزنید تا او را ترور کنید.';
      default:
        return '';
    }
  }

  Widget _buildActionBody(String phase, bool isPres, bool isChan) {
    if (phase == 'electionNomination') {
      return isPres
          ? ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _activeTab = 1;
                });
              },
              icon: const Icon(Icons.people),
              label: const Text('انتخاب صدراعظم از لیست'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
            )
          : const SizedBox.shrink();
    }

    if (phase == 'electionVoting') {
      final nominee = widget.engine.nominatedChancellorIndex != -1 && widget.engine.nominatedChancellorIndex < widget.engine.players.length
          ? widget.engine.players[widget.engine.nominatedChancellorIndex]
          : null;
      final hasVoted = widget.engine.votes.containsKey(widget.engine.localPlayerId);
      final showButtons = !hasVoted && widget.engine.amIAlive;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nominee != null) ...[
            _buildNomineeCard(
              name: nominee['name'],
              avatar: nominee['avatar'] ?? 'avatar_1',
            ),
            const SizedBox(height: 16),
          ],
          if (showButtons)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => widget.engine.castVote(true),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF438A5E)),
                  child: const Text('موافق (JA)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: () => widget.engine.castVote(false),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
                  child: const Text('مخالف (NEIN)', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
        ],
      );
    }

    if (phase == 'legislativePresident' && isPres) {
      return _buildLegislativeCards(isPresident: true);
    }

    if (phase == 'legislativeChancellor' && isChan) {
      return _buildLegislativeCards(isPresident: false);
    }

    if (phase == 'executiveAction' && widget.engine.isMyTurnToExecutePower) {
      return _buildExecutivePowerPanel();
    }

    if (phase == 'discussion') {
      final speakerIndex = widget.engine.activeDiscussionPlayerIndex;
      if (speakerIndex == -1 || speakerIndex >= widget.engine.players.length) {
        return const SizedBox.shrink();
      }
      final speaker = widget.engine.players[speakerIndex];
      final isMyTurn = speaker['id'] == widget.engine.localPlayerId;
      final canIControl = widget.engine.canIControlDiscussion;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1A19),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white10,
                width: isMyTurn ? 1.5 : 1,
              ),
              boxShadow: [
                if (isMyTurn)
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/${speaker['avatar'] ?? 'avatar_1'}.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 40),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        speaker['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isMyTurn ? 'نوبت صحبت شماست' : 'در حال صحبت...',
                        style: TextStyle(
                          color: isMyTurn ? const Color(0xFFD4AF37) : Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DiscussionTimerWidget(
            endTimeMs: widget.engine.discussionEndTime,
            durationSeconds: widget.engine.discussionDuration,
            onTimeExpired: () {
              SoundManager.play(SoundEvent.vetoSucceeds);
            },
          ),
          const SizedBox(height: 16),
          if (widget.engine.discussionEndTime == 0) ...[
            if (isMyTurn) ...[
              ElevatedButton.icon(
                onPressed: () => widget.engine.startDiscussionTimer(),
                icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                label: const Text('شروع صحبت', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF438A5E),
                  minimumSize: const Size(180, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => widget.engine.nextDiscussionTurn(),
                child: const Text('رد کردن نوبت من', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ] else ...[
              Text(
                'منتظر شروع صحبت بازیکن ${speaker['name']}...',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              if (widget.engine.isHost) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => widget.engine.nextDiscussionTurn(),
                  icon: const Icon(Icons.skip_next, size: 18),
                  label: const Text('نفر بعدی (میزبان)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E2A2B),
                    minimumSize: const Size(180, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          ] else ...[
            if (canIControl) ...[
              ElevatedButton.icon(
                onPressed: () => widget.engine.nextDiscussionTurn(),
                icon: const Icon(Icons.skip_next, size: 18),
                label: Text(isMyTurn ? 'پایان نوبت من' : 'نفر بعدی'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isMyTurn ? const Color(0xFF438A5E) : const Color(0xFF9E2A2B),
                  minimumSize: const Size(180, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ] else ...[
              const Text(
                'منتظر پایان صحبت یا اتمام زمان...',
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNomineeCard({required String name, required String avatar}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1A19),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF75B2FF).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF75B2FF).withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Image.asset(
              'assets/images/$avatar.png',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 50),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'نامزد صدراعظم',
                style: TextStyle(
                  color: Color(0xFF75B2FF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegislativeCards({required bool isPresident}) {
    final policies = widget.engine.drawnPolicies;

    return Column(
      children: [
        Text(
          isPresident ? 'برای سوزاندن، روی کارت ضربه بزنید' : 'برای تصویب، روی کارت ضربه بزنید',
          style: const TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(policies.length, (index) {
            final String policy = policies[index];
            final bool isLiberal = policy == 'liberal';

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
                width: 84,
                height: 120,
                decoration: BoxDecoration(
                  color: isLiberal ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFE05252),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLiberal ? Icons.verified_user : Icons.gavel,
                      size: 28,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLiberal ? 'لیبرال' : 'فاشیست',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
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
    final power = widget.engine.activePowerStr;

    if (power == 'policyPeek') {
      final peeked = widget.engine.drawnPolicies;

      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(peeked.length, (index) {
              final policy = peeked[index];
              final bool isLiberal = policy == 'liberal';
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
                  isLiberal ? 'لیبرال' : 'فاشیست',
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
            child: const Text('تایید و بستن مشاهده'),
          ),
        ],
      );
    }

    if (power == 'investigateLoyalty' && _showingLoyaltyResult) {
      final targetIdx = widget.engine.investigatedPlayerIndex;
      if (targetIdx < 0 || targetIdx >= widget.engine.players.length) {
        return const SizedBox.shrink();
      }
      final target = widget.engine.players[targetIdx];
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
                  'نتیجه بررسی وفاداری برای ${target['name']}:',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  party == 'Liberal' ? 'عضو حزب لیبرال' : 'عضو حزب فاشیست',
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
                _showingLoyaltyResult = false;
              });
              widget.engine.completeInvestigateLoyalty();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E2A27),
              side: const BorderSide(color: Colors.white24),
            ),
            child: const Text('بستن نتیجه'),
          ),
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: () {
        setState(() {
          _activeTab = 1;
        });
      },
      icon: const Icon(Icons.touch_app),
      label: const Text('انتخاب بازیکن هدف از لیست'),
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
    );
  }

  void _showExecutionConfirmation(int index) {
    final target = widget.engine.players[index];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2523),
          title: const Text('تایید ترور', style: TextStyle(color: Color(0xFF9E2A2B), fontFamily: 'serif')),
          content: Text(
            'آیا مطمئن هستید که می‌خواهید ${target['name']} را ترور کنید؟ این اقدام دائمی است و قابل بازگشت نیست.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.engine.executeExecution(index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
              child: const Text('ترور بازیکن', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecretRoleAccessButton() {
    return Container(
      padding: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      color: const Color(0xFF2C2523),
      child: OutlinedButton.icon(
        onPressed: _showSecretRoleBottomSheet,
        icon: const Icon(Icons.security, size: 16),
        label: const Text('مشاهده کارت هویت مخفی من'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD4AF37),
          side: const BorderSide(color: Color(0xFFD4AF37)),
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  void _showSecretRoleBottomSheet() {
    final role = widget.engine.myRoleName;
    final party = widget.engine.myPartyName;
    final info = widget.engine.myTeammateInfo;
    final bool isLib = party == 'Liberal';

    showModalBottomSheet(
      context: context,
      backgroundColor: isLib ? const Color(0xFF1E3D59) : const Color(0xFF5C1D1D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) {
        bool isRevealed = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: GestureDetector(
                onPanDown: (_) {
                  setState(() { isRevealed = true; });
                },
                onPanEnd: (_) => setState(() { isRevealed = false; }),
                onPanCancel: () => setState(() { isRevealed = false; }),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return ScaleTransition(
                          scale: animation,
                          child: FadeTransition(opacity: animation, child: child),
                        );
                      },
                      child: !isRevealed
                          ? _buildBlurredRoleCover(isLib)
                          : Column(
                              key: const ValueKey('revealed_role'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'هویت محرمانه',
                                  style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _translateRole(role),
                                  style: TextStyle(
                                    color: isLib ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
                                    fontFamily: 'serif',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'حزب مربوطه: ${_translateRole(party)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    isLib
                                        ? 'assets/images/liberal_role.png'
                                        : (role == 'Secret Hitler' ? 'assets/images/hitler_role.png' : 'assets/images/fascist_role.png'),
                                    height: 110,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  isLib
                                      ? 'هدف: تصویب ۵ سیاست لیبرال یا ترور هیتلر مخفی. با بقیه لیبرال‌ها همکاری کنید.'
                                      : 'هدف: تصویب ۶ سیاست فاشیستی یا انتخاب هیتلر مخفی به عنوان صدراعظم پس از تصویب ۳ سیاست فاشیستی.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                                ),
                                if (info.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text(
                                      info,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.bold, height: 1.4),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white12,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 44),
                                  ),
                                  child: const Text('بستن نمای خصوصی'),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlurredRoleCover(bool isLib) {
    return Column(
      key: const ValueKey('blurred_role'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 40),
        const Icon(Icons.lock_outline, size: 64, color: Colors.white54),
        const SizedBox(height: 24),
        const Text(
          'محرمانه',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 28,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'برای مشاهده هویت مخفی خود، انگشتتان را روی این صفحه نگه دارید. این قابلیت از دیده شدن نقش شما توسط دیگران جلوگیری می‌کند.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 44),
          ),
          child: const Text('بستن نمای خصوصی'),
        ),
      ],
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
                'پیروزی ${_translateWinner(widget.engine.winner)}!',
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
                  _translateWinReason(widget.engine.winReason),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
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
                child: const Text('بازگشت به منو', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDiscussionSettingsDialog() {
    int tempDuration = widget.engine.discussionDuration;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF2C2523),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                ),
                title: const Text(
                  'تنظیمات زمان صحبت',
                  style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'serif', fontWeight: FontWeight.bold),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'مدت زمان نوبت صحبت هر بازیکن پس از تایید هر دولت را انتخاب کنید:',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: tempDuration,
                          dropdownColor: const Color(0xFF2C2523),
                          style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('غیرفعال')),
                            DropdownMenuItem(value: 30, child: Text('۳۰ ثانیه')),
                            DropdownMenuItem(value: 60, child: Text('۱ دقیقه')),
                            DropdownMenuItem(value: 90, child: Text('۱.۵ دقیقه')),
                            DropdownMenuItem(value: 120, child: Text('۲ دقیقه')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                tempDuration = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      widget.engine.updateDiscussionDuration(tempDuration);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تنظیمات زمان صحبت با موفقیت به‌روزرسانی شد.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF438A5E)),
                    child: const Text('ذخیره', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQuitConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2523),
          title: const Text('خروج از بازی؟', style: TextStyle(color: Color(0xFFE6DFD3), fontFamily: 'serif')),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید از بازی خارج شوید؟ تمام پیشرفت شما از دست خواهد رفت.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onQuit();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9E2A2B)),
              child: const Text('خروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

class DiscussionTimerWidget extends StatefulWidget {
  final int endTimeMs;
  final int durationSeconds;
  final VoidCallback onTimeExpired;

  const DiscussionTimerWidget({
    Key? key,
    required this.endTimeMs,
    required this.durationSeconds,
    required this.onTimeExpired,
  }) : super(key: key);

  @override
  State<DiscussionTimerWidget> createState() => _DiscussionTimerWidgetState();
}

class _DiscussionTimerWidgetState extends State<DiscussionTimerWidget> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant DiscussionTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endTimeMs != widget.endTimeMs || oldWidget.durationSeconds != widget.durationSeconds) {
      _timer?.cancel();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateSeconds();
    if (widget.endTimeMs > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        _updateSeconds();
      });
    }
  }

  void _updateSeconds() {
    if (widget.endTimeMs == 0) {
      setState(() {
        _secondsLeft = widget.durationSeconds;
        _timer?.cancel();
      });
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = widget.endTimeMs - now;
    setState(() {
      _secondsLeft = (diff / 1000).round();
      if (_secondsLeft <= 0) {
        _secondsLeft = 0;
        _timer?.cancel();
        widget.onTimeExpired();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isNotStarted = widget.endTimeMs == 0;
    final bool isLowTime = !isNotStarted && _secondsLeft <= 10;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isNotStarted
            ? Colors.white.withOpacity(0.03)
            : isLowTime
                ? const Color(0xFF9E2A2B).withOpacity(0.15)
                : Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNotStarted
              ? Colors.white24
              : isLowTime
                  ? const Color(0xFF9E2A2B)
                  : const Color(0xFFD4AF37).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNotStarted
                ? Icons.timer_outlined
                : Icons.alarm,
            color: isNotStarted
                ? Colors.white30
                : isLowTime
                    ? const Color(0xFF9E2A2B)
                    : const Color(0xFFD4AF37),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isNotStarted
                ? 'آماده شروع: $_secondsLeft ثانیه'
                : '$_secondsLeft ثانیه باقی‌مانده',
            style: TextStyle(
              color: isNotStarted
                  ? Colors.white54
                  : isLowTime
                      ? const Color(0xFF9E2A2B)
                      : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
