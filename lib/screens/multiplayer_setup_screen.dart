import 'package:flutter/material.dart';
import 'dart:math';
import '../logic/firebase_manager.dart';

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

    setState(() {
      _isLoading = true;
    });

    final String playerId = 'user_${RandomString.generate(6)}';

    try {
      if (_isCreating) {
        final lobbyCode = await FirebaseManager.createGame(
          hostName: name,
          hostId: playerId,
        );
        widget.onEnterLobby(lobbyCode, name, playerId);
      } else {
        if (code.isEmpty) {
          _showError('لطفا کد لابی را وارد کنید.');
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final success = await FirebaseManager.joinGame(
          lobbyCode: code,
          playerName: name,
          playerId: playerId,
        );

        if (success) {
          widget.onEnterLobby(code, name, playerId);
        } else {
          _showError('لابی پیدا نشد، ظرفیت بازیکنان پر شده یا بازی در حال انجام است.');
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF9E2A2B)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeTitle = _isCreating ? 'ساخت لابی چند نفره' : 'ورود به لابی چند نفره';

    return Scaffold(
      backgroundColor: const Color(0xFF1B1816),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/wood_table_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'مرموز',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE6DFD3),
                    letterSpacing: 8,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'هیتلر',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF9E2A2B),
                    letterSpacing: 10,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 80,
                    height: 2,
                    color: const Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 8),
                Text(
                  modeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                if (!FirebaseManager.isFirebaseAvailable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9E2A2B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF9E2A2B)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFF9E2A2B), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تنظیمات فایربیس یافت نشد. در حال اجرای شبیه‌ساز محلی.',
                            style: TextStyle(color: Color(0xFFFF847C), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
  
                // Segmented controls
                Row(
                  children: [
                    Expanded(
                      child: _buildModeTab(true, 'ساخت لابی'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildModeTab(false, 'ورود به لابی'),
                    ),
                  ],
                ),
  
                const SizedBox(height: 32),
  
                // Form fields
                const Text(
                  'نام شما',
                  style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _buildInputDecoration('نام نمایشی خود را وارد کنید'),
                ),
  
                if (!_isCreating) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'کد لابی (۶ کاراکتر)',
                    style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: Colors.white, fontSize: 14, letterSpacing: 3, fontWeight: FontWeight.bold),
                    decoration: _buildInputDecoration('مانند A3F8Y2'),
                  ),
                ],
  
                const SizedBox(height: 40),
  
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9E2A2B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 8,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isCreating ? 'ایجاد اتاق' : 'ورود به اتاق',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                ),
              ],
            ),
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
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white12,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      filled: true,
      fillColor: Colors.black26,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white10),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
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
