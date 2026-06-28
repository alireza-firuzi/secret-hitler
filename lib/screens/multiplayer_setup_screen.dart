import 'package:flutter/material.dart';
import 'dart:math';
import '../logic/firebase_manager.dart';
import 'tutorial_screen.dart';
import 'profile_screen.dart';
import 'leaderboard_screen.dart';

class MultiplayerSetupScreen extends StatefulWidget {
  final Function(String lobbyCode, String playerName, String playerId) onEnterLobby;
  final VoidCallback onBack;

  const MultiplayerSetupScreen({
    Key? key,
    required this.onEnterLobby,
    required this.onBack,
  }) : super(key: key);

  @override
  State<MultiplayerSetupScreen> createState() => _MultiplayerSetupScreenState();
}

class _SetupFormState {
  final String title;
  final bool isJoin;
  _SetupFormState({required this.title, required this.isJoin});
}

class _MultiplayerSetupScreenState extends State<MultiplayerSetupScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Player 1');
  final TextEditingController _codeController = TextEditingController();
  bool _isCreating = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (FirebaseManager.currentUserProfile != null) {
      _nameController.text = FirebaseManager.currentUserProfile!['displayName'] ?? '';
    }
    _checkLobbyCodeFromUrl();
  }

  void _checkLobbyCodeFromUrl() {
    String? lobbyCode;
    if (Uri.base.queryParameters.containsKey('lobby')) {
      lobbyCode = Uri.base.queryParameters['lobby'];
    } else if (Uri.base.fragment.contains('lobby=')) {
      try {
        String fragment = Uri.base.fragment;
        if (fragment.startsWith('/')) {
          fragment = fragment.substring(1);
        }
        final fragmentUri = Uri.parse(fragment);
        lobbyCode = fragmentUri.queryParameters['lobby'];
      } catch (_) {}
    }

    if (lobbyCode != null && lobbyCode.isNotEmpty) {
      _codeController.text = lobbyCode.toUpperCase();
      _isCreating = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim().toUpperCase();

    if (name.isEmpty) {
      _showError('لطفا نام خود را وارد کنید.');
      return;
    }

    if (!_isCreating && code.isEmpty) {
      _showError('لطفا کد لابی را وارد کنید.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<String> takenAvatars = [];
      if (!_isCreating) {
        final fetchedTaken = await FirebaseManager.checkLobby(lobbyCode: code);
        if (fetchedTaken == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        takenAvatars = fetchedTaken;
      }

      setState(() {
        _isLoading = false;
      });

      final selectedAvatar = await _showAvatarSelectionDialog(takenAvatars);
      if (selectedAvatar == null) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final String playerId = FirebaseManager.currentUserProfile?['uid'] ?? 'user_${RandomString.generate(6)}';

      if (_isCreating) {
        final lobbyCode = await FirebaseManager.createGame(
          hostName: name,
          hostId: playerId,
          avatar: selectedAvatar,
        );
        widget.onEnterLobby(lobbyCode, name, playerId);
      } else {
        final errorMsg = await FirebaseManager.joinGame(
          lobbyCode: code,
          playerName: name,
          playerId: playerId,
          avatar: selectedAvatar,
        );

        if (errorMsg == null) {
          widget.onEnterLobby(code, name, playerId);
        } else {
          _showError(errorMsg);
        }
      }
    } catch (e) {
      _showError('خطایی در اتصال رخ داد.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _showAvatarSelectionDialog(List<String> takenAvatars) {
    String currentSelected = FirebaseManager.currentUserProfile?['photoUrl'] ?? 'avatar_1';
    if (takenAvatars.contains(currentSelected)) {
      for (int i = 1; i <= 12; i++) {
        final name = 'avatar_$i';
        if (!takenAvatars.contains(name)) {
          currentSelected = name;
          break;
        }
      }
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: const Color(0xFF1C1917),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  width: min(MediaQuery.of(context).size.width * 0.9, 450),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'انتخاب آواتار',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'لطفاً آواتار خود را انتخاب کنید. آواتارها باید یکتا باشند.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final avatarName = 'avatar_${index + 1}';
                            final isTaken = takenAvatars.contains(avatarName);
                            final isSelected = currentSelected == avatarName;

                            return GestureDetector(
                              onTap: isTaken
                                  ? null
                                  : () {
                                      setState(() {
                                        currentSelected = avatarName;
                                      });
                                    },
                              child: Stack(
                                children: [
                                  Opacity(
                                    opacity: isTaken ? 0.35 : 1.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFFD4AF37)
                                              : (isTaken ? Colors.red.withOpacity(0.3) : Colors.white10),
                                          width: isSelected ? 2.5 : 1,
                                        ),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFD4AF37).withOpacity(0.3),
                                                  blurRadius: 6,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          'assets/images/$avatarName.png',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isTaken)
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                                          ),
                                          child: const Text(
                                            'گرفته شده',
                                            style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: const Text('انصراف', style: TextStyle(color: Colors.white30)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(currentSelected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF9E2A2B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('تایید و ورود'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF9E2A2B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeTitle = _isCreating ? 'ساخت لابی چند نفره' : 'ورود به لابی چند نفره';

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
              // Dark overlay to focus on the center card
              Container(
                color: Colors.black.withOpacity(0.55),
              ),
              Positioned(
                top: 50,
                left: 20,
                child: Row(
                  children: [
                    // Profile button
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ).then((_) {
                          // Update UI in case username or avatar changed
                          if (mounted) {
                            setState(() {
                              if (FirebaseManager.currentUserProfile != null) {
                                _nameController.text = FirebaseManager.currentUserProfile!['displayName'] ?? '';
                              }
                            });
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE6251E1C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: const Color(0xFF151211),
                              backgroundImage: AssetImage(
                                'assets/images/${FirebaseManager.currentUserProfile?['photoUrl'] ?? 'avatar_1'}.png',
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'پروفایل من',
                              style: TextStyle(
                                color: Color(0xFFE6DFD3),
                                fontFamily: 'serif',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Leaderboard button
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE6251E1C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.emoji_events, color: Color(0xFFD4AF37), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'لیدربورد',
                              style: TextStyle(
                                color: Color(0xFFE6DFD3),
                                fontFamily: 'serif',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tutorial button
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TutorialScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xE6251E1C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5), width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.help_outline, color: Color(0xFFD4AF37), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'آموزش بازی',
                              style: TextStyle(
                                color: Color(0xFFE6DFD3),
                                fontFamily: 'serif',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 50,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Color(0xFFD4AF37), size: 28),
                  onPressed: widget.onBack,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xE6251E1C),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.4),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withOpacity(0.08),
                            blurRadius: 40,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top stylized emblem/wax seal mockup
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2C2523),
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD4AF37).withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.security,
                                      color: Color(0xFFD4AF37),
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Stylized Title
                              const Text(
                                'راز',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE6DFD3),
                                  letterSpacing: 4,
                                  height: 1.0,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'هیتلر',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFC92A2A),
                                  letterSpacing: 6,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      offset: Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              
                              // Golden Diamond Divider
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 50, height: 1, color: const Color(0xFFD4AF37).withOpacity(0.5)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star, size: 10, color: Color(0xFFD4AF37)),
                                  const SizedBox(width: 8),
                                  Container(width: 50, height: 1, color: const Color(0xFFD4AF37).withOpacity(0.5)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'بازی آنلاین',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontFamily: 'serif',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              
                              // Segmented controls (Tabs)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white10),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildModeTab(true, 'ساخت لابی'),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: _buildModeTab(false, 'ورود به لابی'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),
                              
                              if (!FirebaseManager.isFirebaseAvailable)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF9E2A2B).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF9E2A2B).withOpacity(0.5)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.cloud_off, color: Color(0xFFFF847C), size: 16),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'تنظیمات سرور یافت نشد. در حال اجرای شبیه‌ساز محلی.',
                                          style: TextStyle(color: Color(0xFFFF847C), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                              // Form inputs
                              const Text(
                                'نام شما',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: _buildInputDecoration('نام نمایشی خود را وارد کنید', Icons.person_outline),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              if (!_isCreating) ...[
                                const SizedBox(height: 20),
                                const Text(
                                  'کد لابی (۶ کاراکتر)',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _codeController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontSize: 14, 
                                    letterSpacing: 4, 
                                    fontWeight: FontWeight.bold
                                  ),
                                  decoration: _buildInputDecoration('مانند A3F8Y2', Icons.vpn_key_outlined),
                                ),
                              ],
                              
                              const SizedBox(height: 36),
                              
                              // Submit button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9E2A2B),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 54),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 8,
                                  shadowColor: const Color(0xFF9E2A2B).withOpacity(0.5),
                                ).copyWith(
                                  backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                                    if (states.contains(MaterialState.disabled)) {
                                      return const Color(0xFF9E2A2B).withOpacity(0.5);
                                    }
                                    return const Color(0xFF9E2A2B); // Default deep red
                                  }),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        _isCreating ? 'ایجاد اتاق بازی' : 'ورود به بازی',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                                      ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(bool createMode, String label) {
    final bool isSelected = _isCreating == createMode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isCreating = createMode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.black38,
      prefixIcon: Icon(icon, color: const Color(0xFFD4AF37).withOpacity(0.7), size: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
    );
  }
}

class RandomString {
  static String generate(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }
}
