import 'package:flutter/material.dart';
import '../models/game_state.dart';

class PolicyTrackWidget extends StatelessWidget {
  final PolicyType type;
  final int count;
  final int totalSlots;
  final int playerCount;

  const PolicyTrackWidget({
    Key? key,
    required this.type,
    required this.count,
    required this.totalSlots,
    required this.playerCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isLiberal = type == PolicyType.liberal;
    
    // Premium board styling
    final trackGradient = isLiberal
        ? const LinearGradient(
            colors: [Color(0xFF112E18), Color(0xFF1D4426)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF331111), Color(0xFF541D1D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final borderColor = isLiberal ? const Color(0xFF388E3C) : const Color(0xFF9E2A2B);
    final String trackTitle = isLiberal ? "صفحه سیاست‌های لیبرال" : "صفحه سیاست‌های فاشیستی";
    final activeColor = isLiberal ? const Color(0xFF2E7D32) : const Color(0xFF8A1F1F);
    final stampColor = isLiberal ? const Color(0xFF81C784) : const Color(0xFFFF847C);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: trackGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Elegant Header with gold details
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 20, height: 1, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Text(
                trackTitle,
                style: TextStyle(
                  color: isLiberal ? const Color(0xFF75B2FF) : const Color(0xFFFF847C),
                  fontFamily: 'serif',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(width: 8),
              Container(width: 20, height: 1, color: const Color(0xFFD4AF37)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Cards Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth = (constraints.maxWidth - (totalSlots - 1) * 8) / totalSlots;
              final double cardHeight = cardWidth * 1.45;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSlots, (index) {
                  final bool isEnacted = index < count;
                  final String power = _getPowerLabelForSlot(index + 1);
                  final IconData? powerIcon = _getPowerIcon(power);

                  return Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: isEnacted ? activeColor : Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isEnacted
                            ? const Color(0xFFD4AF37)
                            : borderColor.withOpacity(0.3),
                        width: isEnacted ? 2 : 1.5,
                      ),
                      boxShadow: isEnacted
                          ? [
                              BoxShadow(
                                color: activeColor.withOpacity(0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Card Content
                        if (isEnacted)
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isLiberal ? Icons.verified_user : Icons.gavel,
                                size: cardWidth * 0.45,
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isLiberal ? 'لیبرال' : 'فاشیست',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          // Empty Slot Placeholder with power indicators
                          if (powerIcon != null)
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  powerIcon,
                                  size: cardWidth * 0.35,
                                  color: stampColor.withOpacity(0.4),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1.0),
                                  child: Text(
                                    power,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 6,
                                      color: stampColor.withOpacity(0.5),
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: borderColor.withOpacity(0.2),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData? _getPowerIcon(String power) {
    switch (power) {
      case 'بررسی وفاداری':
        return Icons.remove_red_eye_outlined;
      case 'مشاهده مخفی':
        return Icons.visibility_outlined;
      case 'انتخابات ویژه':
        return Icons.stars_outlined;
      case 'ترور':
        return Icons.dangerous_outlined;
      case 'پیروزی':
        return Icons.emoji_events_outlined;
      default:
        return null;
    }
  }

  String _getPowerLabelForSlot(int slot) {
    if (type == PolicyType.liberal) return '';
    // Fascist Track Powers depend on player count:
    if (slot == 1) {
      return playerCount >= 9 ? 'بررسی وفاداری' : '';
    } else if (slot == 2) {
      return playerCount >= 7 ? 'بررسی وفاداری' : '';
    } else if (slot == 3) {
      return playerCount <= 6 ? 'مشاهده مخفی' : 'انتخابات ویژه';
    } else if (slot == 4) {
      return 'ترور';
    } else if (slot == 5) {
      return 'ترور';
    } else if (slot == 6) {
      return 'پیروزی';
    }
    return '';
  }
}

class ElectionTrackerWidget extends StatelessWidget {
  final int count;

  const ElectionTrackerWidget({
    Key? key,
    required this.count,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ردیاب انتخابات',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Row(
            children: List.generate(3, (index) {
              final bool isActive = index < count;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? const Color(0xFFD4AF37)
                      : Colors.transparent,
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFFFD700)
                        : Colors.white38,
                    width: 2,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.black : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class PlayerSlotWidget extends StatelessWidget {
  final Player player;
  final bool isPresident;
  final bool isChancellor;
  final bool isNominatedChancellor;
  final bool isEligible;
  final VoidCallback? onTap;

  const PlayerSlotWidget({
    Key? key,
    required this.player,
    required this.isPresident,
    required this.isChancellor,
    required this.isNominatedChancellor,
    required this.isEligible,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color cardBgColor = const Color(0xFF2C2523);
    Color borderColor = Colors.white10;

    if (!player.isAlive) {
      cardBgColor = Colors.black45;
    } else if (isPresident) {
      cardBgColor = const Color(0xFF4A3E3B);
      borderColor = const Color(0xFFD4AF37);
    } else if (isChancellor) {
      cardBgColor = const Color(0xFF3B404A);
      borderColor = const Color(0xFF75B2FF);
    } else if (isNominatedChancellor) {
      cardBgColor = const Color(0xFF3B404A).withOpacity(0.5);
      borderColor = const Color(0xFF75B2FF).withOpacity(0.5);
    } else if (isEligible && onTap != null) {
      borderColor = Colors.white30;
    }

    return GestureDetector(
      onTap: player.isAlive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: (isPresident || isChancellor)
              ? [
                  BoxShadow(
                    color: (isPresident
                            ? const Color(0xFFD4AF37)
                            : const Color(0xFF75B2FF))
                        .withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Opacity(
              opacity: player.isAlive ? 1.0 : 0.4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.asset(
                  'assets/images/${player.avatar}.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white24, size: 44),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      color: player.isAlive ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: player.isAlive
                          ? TextDecoration.none
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  if (player.isInvestigated)
                    const Text(
                      'بررسی وفاداری شده',
                      style: TextStyle(
                        color: Colors.white30,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Badges
            if (!player.isAlive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: const Text(
                  'کشته شده',
                  style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              )
            else ...[
              if (isPresident)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: const Text(
                    'رئیس‌جمهور',
                    style: TextStyle(color: Color(0xFFFFD700), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isChancellor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF75B2FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF75B2FF)),
                  ),
                  child: const Text(
                    'صدراعظم',
                    style: TextStyle(color: Color(0xFF75B2FF), fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              if (isNominatedChancellor)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueGrey),
                  ),
                  child: const Text(
                    'نامزد',
                    style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              if (!isPresident && !isChancellor && !isNominatedChancellor && !isEligible)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Text(
                    'محدودیت دوره',
                    style: TextStyle(color: Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
