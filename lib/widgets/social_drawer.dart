import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../logic/firebase_manager.dart';
import 'avatar_helper.dart';
import 'direct_chat_dialog.dart';

class SocialDrawer extends StatefulWidget {
  const SocialDrawer({super.key});

  @override
  State<SocialDrawer> createState() => _SocialDrawerState();
}

class _SocialDrawerState extends State<SocialDrawer> {
  final TextEditingController _searchController = TextEditingController();
  int _activeTab = 0; // 0: Friends, 1: Requests
  List<dynamic> _friends = [];

  late final StreamSubscription _friendsSubscription;

  @override
  void initState() {
    super.initState();
    // Subscribe to real-time friends list updates
    _friendsSubscription = FirebaseManager.friendsStream.listen((list) {
      if (mounted) {
        setState(() {
          _friends = list;
        });
      }
    });

    // Request initial list
    FirebaseManager.getFriends();
  }

  @override
  void dispose() {
    _friendsSubscription.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _sendRequest() {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    // Clean username prefix if user typed '@'
    final cleanUsername = username.startsWith('@') ? username.substring(1) : username;

    FirebaseManager.sendFriendRequest(cleanUsername);
    _searchController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('درخواست دوستی ارسال شد.', style: TextStyle(fontFamily: 'serif')),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Separate accepted friends and pending requests
    final acceptedFriends = _friends.where((f) => f['status'] == 'accepted').toList();
    final pendingRequests = _friends.where((f) => f['status'] == 'pending').toList();

    // Sort accepted friends: online first
    acceptedFriends.sort((a, b) {
      final aOnline = a['isOnline'] == true ? 1 : 0;
      final bOnline = b['isOnline'] == true ? 1 : 0;
      return bOnline.compareTo(aOnline);
    });

    return Drawer(
      backgroundColor: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xDD1B1412),
            border: const Border(
              right: BorderSide(
                color: Color(0xFFD4AF37),
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: const [
                      Icon(Icons.people_outline_rounded, color: Color(0xFFD4AF37), size: 28),
                      SizedBox(width: 12),
                      Text(
                        'ارتباطات و دوستان',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'serif',
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),

                // Add Friend Search Input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'نام کاربری (مثلا @ali)...',
                            hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                            prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.white30, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                            ),
                          ),
                          onSubmitted: (_) => _sendRequest(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF9E2A2B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _sendRequest,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),

                // Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton(0, 'دوستان (${acceptedFriends.length})'),
                        _buildTabButton(1, 'درخواست‌ها (${pendingRequests.length})'),
                      ],
                    ),
                  ),
                ),

                // List Area
                Expanded(
                  child: _activeTab == 0
                      ? _buildFriendsList(acceptedFriends)
                      : _buildRequestsList(pendingRequests),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1)
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFD4AF37) : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
                fontFamily: 'serif',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList(List<dynamic> friends) {
    if (friends.isEmpty) {
      return const Center(
        child: Text(
          'لیست دوستان شما خالی است.',
          style: TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'serif'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final friend = friends[index];
        final isOnline = friend['isOnline'] == true;
        final avatar = friend['photoUrl'];
        final displayName = friend['displayName'] ?? '';
        final username = friend['username'] ?? '';
        final uid = friend['uid'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Row(
            children: [
              // Avatar Stack with online dot indicator
              Stack(
                children: [
                  buildAvatarCircle(avatar, radius: 24),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF9E9E9E),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1B1412), width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isOnline
                      ? const Color(0xFFD4AF37).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  foregroundColor: isOnline ? const Color(0xFFD4AF37) : Colors.white30,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => DirectChatDialog(
                      friendId: uid,
                      friendName: displayName,
                      friendAvatar: avatar,
                      isOnline: isOnline,
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsList(List<dynamic> requests) {
    if (requests.isEmpty) {
      return const Center(
        child: Text(
          'هیچ درخواست دوستی در حال انتظاری وجود ندارد.',
          style: TextStyle(color: Colors.white38, fontSize: 13, fontFamily: 'serif'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final req = requests[index];
        final isRequester = req['isRequester'] == true;
        final avatar = req['photoUrl'];
        final displayName = req['displayName'] ?? '';
        final username = req['username'] ?? '';
        final uid = req['uid'] ?? '';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Row(
            children: [
              buildAvatarCircle(avatar, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@$username',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),
              if (isRequester)
                const Text(
                  'ارسال شده',
                  style: TextStyle(fontSize: 11, color: Colors.white30, fontFamily: 'serif'),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.15),
                        foregroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        FirebaseManager.respondFriendRequest(uid, true);
                      },
                      icon: const Icon(Icons.check, size: 18),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.15),
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        FirebaseManager.respondFriendRequest(uid, false);
                      },
                      icon: const Icon(Icons.close, size: 18),
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
