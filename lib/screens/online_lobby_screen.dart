import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/online_game_engine.dart';

class OnlineLobbyScreen extends StatelessWidget {
  final OnlineGameEngine engine;
  final VoidCallback onLeave;

  const OnlineLobbyScreen({
    Key? key,
    required this.engine,
    required this.onLeave,
  }) : super(key: key);

  void _copyInviteLink(BuildContext context) {
    // Generate simulated URL (which will work locally in web browser)
    final inviteLink = 'http://localhost:8080/#/?lobby=${engine.lobbyCode}';
    Clipboard.setData(ClipboardData(text: inviteLink));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لینک دعوت در حافظه موقت کپی شد!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHost = engine.isHost;
    final playersList = engine.players;

    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C2523),
        title: const Text(
          'لابی چند نفره',
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app, color: Colors.white70),
          onPressed: onLeave,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lobby Code Panel
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2523),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'کد لابی',
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      engine.lobbyCode,
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w900,
                        fontSize: 36,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _copyInviteLink(context),
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('کپی لینک دعوت'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Colors.white12),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Players Count
              Row(
                children: [
                  const Text(
                    'بازیکنان وارد شده',
                    style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: playersList.length >= 5 ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: playersList.length >= 5 ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      '${playersList.length} از ۱۰ بازیکن',
                      style: TextStyle(
                        color: playersList.length >= 5 ? Colors.green : Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Joined players list
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: ListView.builder(
                    itemCount: playersList.length,
                    itemBuilder: (context, index) {
                      final player = playersList[index];
                      final isPlayerHost = player['id'] == engine.hostId;
                      final isMe = player['id'] == engine.localPlayerId;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF2C2523) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isMe ? const Color(0xFFD4AF37).withOpacity(0.4) : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Text(
                              '${index + 1}',
                              style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              player['name'],
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 8),
                              const Text(
                                '(شما)',
                                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                            const Spacer(),
                            if (isPlayerHost)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD4AF37)),
                                ),
                                child: const Text(
                                  'میزبان',
                                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action controls
              if (isHost) ...[
                ElevatedButton(
                  onPressed: playersList.length >= 5 ? () => engine.startGame() : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E2A2B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 8,
                  ),
                  child: const Text(
                    'شروع بازی',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                if (playersList.length < 5)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'برای شروع بازی حداقل به ۵ بازیکن نیاز است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'منتظر شروع بازی توسط میزبان...',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
