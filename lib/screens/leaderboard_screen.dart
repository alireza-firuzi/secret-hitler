import 'package:flutter/material.dart';
import '../logic/firebase_manager.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  List<dynamic> _leaderboard = [];

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final list = await FirebaseManager.getLeaderboard();
      if (mounted) {
        setState(() {
          _leaderboard = list ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF151211),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/wood_table_background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              Container(color: Colors.black.withOpacity(0.65)), // Dark overlay
              Column(
                children: [
                  const SizedBox(height: 50),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFD4AF37)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'جدول رده‌بندی',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE6DFD3),
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37)),
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                          });
                          _fetchLeaderboard();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Content
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                        : _leaderboard.isEmpty
                            ? _buildEmptyState()
                            : _buildLeaderboardList(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events_outlined, size: 80, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            'داده‌ای در جدول رده‌بندی ثبت نشده است.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'بازی‌های ثبت شده برای بروزرسانی لیدربورد استفاده خواهند شد.',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: _leaderboard.length,
      itemBuilder: (context, index) {
        final player = _leaderboard[index];
        final String name = player['displayName'] ?? 'کاربر ناشناس';
        final String avatar = player['photoUrl'] ?? 'avatar_1';
        final int wins = player['wins'] ?? 0;
        final int totalGames = player['gamesPlayed'] ?? 0;
        final rank = index + 1;

        Color rankColor = Colors.white54;
        double rankSize = 18;
        if (rank == 1) {
          rankColor = const Color(0xFFD4AF37); // Gold
          rankSize = 24;
        } else if (rank == 2) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          rankSize = 21;
        } else if (rank == 3) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          rankSize = 19;
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: rank == 1 ? const Color(0x33D4AF37) : const Color(0xE6251E1C),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rank == 1
                  ? const Color(0xFFD4AF37)
                  : const Color(0xFFD4AF37).withOpacity(0.15),
              width: rank == 1 ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 36,
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontSize: rankSize,
                    fontWeight: FontWeight.bold,
                    color: rankColor,
                    fontFamily: 'serif',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),

              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF151211),
                backgroundImage: AssetImage('assets/images/$avatar.png'),
              ),
              const SizedBox(width: 16),

              // Name
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              // Stats / Wins
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$wins برد',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  Text(
                    'از $totalGames بازی',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white30,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
