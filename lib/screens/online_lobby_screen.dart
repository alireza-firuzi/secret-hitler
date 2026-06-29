import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/online_game_engine.dart';
import '../widgets/avatar_helper.dart';

class OnlineLobbyScreen extends StatelessWidget {
  final OnlineGameEngine engine;
  final VoidCallback onLeave;

  const OnlineLobbyScreen({
    Key? key,
    required this.engine,
    required this.onLeave,
  }) : super(key: key);

  void _copyInviteLink(BuildContext context) {
    // Generate URL dynamically based on current web app location (or production fallback)
    String inviteLink;
    if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
      final base = Uri.base;
      inviteLink = Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.port,
        path: base.path,
        fragment: '/?lobby=${engine.lobbyCode}',
      ).toString();
    } else {
      inviteLink = 'https://alireza-firuzi.github.io/secret-hitler/#/?lobby=${engine.lobbyCode}';
    }

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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image(
                                image: getAvatarImage(player['avatar']),
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 30),
                              ),
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
                            if (player['isDisconnected'] == true) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.withOpacity(0.6)),
                                ),
                                child: const Text(
                                  'قطع ارتباط',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
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

              const SizedBox(height: 16),

              // Settings Panel
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2523),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'نوبت صحبت پس از تایید دولت',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'مدت زمان نوبت صحبت هر بازیکن پس از تایید رای‌گیری',
                            style: TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    if (isHost)
                      DropdownButton<int>(
                        value: engine.discussionDuration,
                        dropdownColor: const Color(0xFF2C2523),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('غیرفعال')),
                          DropdownMenuItem(value: 30, child: Text('۳۰ ثانیه')),
                          DropdownMenuItem(value: 60, child: Text('۱ دقیقه')),
                          DropdownMenuItem(value: 90, child: Text('۱.۵ دقیقه')),
                          DropdownMenuItem(value: 120, child: Text('۲ دقیقه')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            engine.updateDiscussionDuration(val);
                          }
                        },
                      )
                    else
                      Text(
                        engine.discussionDuration == 0
                            ? 'غیرفعال'
                            : engine.discussionDuration == 60
                                ? '۱ دقیقه'
                                : engine.discussionDuration == 90
                                    ? '۱.۵ دقیقه'
                                    : engine.discussionDuration == 120
                                        ? '۲ دقیقه'
                                        : '${engine.discussionDuration} ثانیه',
                        style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2523),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'گوینده صوتی هوش مصنوعی',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'اعلام صوتی اتفاقات مهم بازی',
                            style: TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: engine.aiNarratorEnabled,
                      activeColor: const Color(0xFFD4AF37),
                      activeTrackColor: const Color(0xFFD4AF37).withOpacity(0.4),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.withOpacity(0.2),
                      onChanged: isHost
                          ? (val) {
                              engine.updateAiNarrator(val);
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action controls
              if (isHost) ...[
                if (playersList.length < 10) ...[
                  OutlinedButton.icon(
                    onPressed: () => engine.addMockBots(),
                    icon: const Icon(Icons.android, color: Color(0xFFD4AF37)),
                    label: const Text(
                      'افزودن ربات‌های آزمایشی',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
