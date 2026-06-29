import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../logic/firebase_manager.dart';
import 'avatar_helper.dart';

class DirectChatDialog extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatar;
  final bool isOnline;

  const DirectChatDialog({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
    required this.isOnline,
  });

  @override
  State<DirectChatDialog> createState() => _DirectChatDialogState();
}

class _DirectChatDialogState extends State<DirectChatDialog> {
  final List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  late final StreamSubscription _msgSubscription;

  @override
  void initState() {
    super.initState();
    _loadHistory();

    // Subscribe to incoming messages
    _msgSubscription = FirebaseManager.directMessageStream.listen((msg) {
      final senderId = msg['senderId'];
      final receiverId = msg['receiverId'];
      final myId = FirebaseManager.currentUserProfile?['uid'] ?? '';

      // Check if message belongs to this conversation
      final isRelevant = (senderId == widget.friendId && receiverId == myId) ||
          (senderId == myId && receiverId == widget.friendId);

      if (isRelevant) {
        if (mounted) {
          setState(() {
            _messages.add(msg);
          });
          _scrollToBottom();
        }
      }
    });
  }

  @override
  void dispose() {
    _msgSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await FirebaseManager.getDirectMessages(widget.friendId);
    if (mounted) {
      setState(() {
        _messages.addAll(history);
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    FirebaseManager.sendDirectMessage(widget.friendId, text);
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseManager.currentUserProfile?['uid'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xEC1E1715),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Chat Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
                      ),
                      child: Row(
                        children: [
                          buildAvatarCircle(widget.friendAvatar, radius: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.friendName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: widget.isOnline
                                            ? const Color(0xFF4CAF50)
                                            : const Color(0xFF9E9E9E),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.isOnline ? 'آنلاین' : 'آفلاین',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.isOnline ? const Color(0xFF4CAF50) : Colors.white30,
                                        fontFamily: 'serif',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                    // Chat Messages List
                    Expanded(
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                final isMe = msg['senderId'] == myId;
                                final text = msg['message'] ?? '';
                                final timeStr = _formatTime(msg['timestamp']);

                                return _buildMessageBubble(text, isMe, timeStr);
                              },
                            ),
                    ),

                    // Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'پیام خود را بنویسید...',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.2)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                                ),
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                              shape: const CircleBorder(),
                            ),
                            onPressed: _sendMessage,
                            icon: const Icon(Icons.send_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFFD4AF37).withOpacity(0.85)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 16),
              ),
              border: Border.all(
                color: isMe
                    ? const Color(0xFFD4AF37).withOpacity(0.5)
                    : Colors.white.withOpacity(0.05),
                width: 1,
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 14,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              time,
              style: const TextStyle(fontSize: 10, color: Colors.white30),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = DateTime.fromMillisecondsSinceEpoch(ts as int);
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}
