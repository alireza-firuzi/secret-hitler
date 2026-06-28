import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../logic/firebase_manager.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  String _selectedAvatar = 'avatar_1';

  final List<String> _funnyPersianNames = [
    'کارآگاه علوی',
    'رئیس‌جمهور موقت',
    'مستشارالدوله',
    'صدراعظم کبیر',
    'ژنرال طوفان',
    'سایه پنهان',
    'مرد خاکستری',
    'لیبرال خسته',
    'فاشیست مخفی',
    'شاهد عینی'
  ];

  @override
  void initState() {
    super.initState();
    // Prefill with a random fun Persian name
    final rand = Random();
    _usernameController.text = _funnyPersianNames[rand.nextInt(_funnyPersianNames.length)];
    _selectedAvatar = 'avatar_${rand.nextInt(12) + 1}';
  }

  Future<void> _handleMockLogin(String provider) async {
    // Show a dialog to let them customize their profile name and avatar
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF2C2523),
                title: Text(
                  'تنظیمات پروفایل ($provider)',
                  style: const TextStyle(
                    fontFamily: 'serif',
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar selector
                      const Text(
                        'انتخاب آواتار:',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 70,
                        width: 300,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final avatarName = 'avatar_${index + 1}';
                            final isSelected = _selectedAvatar == avatarName;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  _selectedAvatar = avatarName;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF151211),
                                  backgroundImage: AssetImage('assets/images/$avatarName.png'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Username input
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'نام کاربری',
                          labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
                          filled: true,
                          fillColor: Colors.black26,
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.white24),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      if (_usernameController.text.trim().isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('ورود و ثبت', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _usernameController.text.trim();
      // Generate a mock unique UID based on provider and name
      final mockUid = '${provider.toLowerCase()}_${name.hashCode.abs()}_${Random().nextInt(900) + 100}';
      
      final profile = await FirebaseManager.loginUser(
        uid: mockUid,
        displayName: name,
        email: '${mockUid}@secrethitler.ir',
        photoUrl: _selectedAvatar,
      );

      if (profile != null) {
        widget.onLoginSuccess();
      } else {
        _showError('خطا در برقراری ارتباط با سرور.');
      }
    } catch (e) {
      _showError('اتصال برقرار نشد.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        final name = user.displayName ?? _usernameController.text.trim();
        final email = user.email ?? '';
        final uid = user.uid;
        
        final profile = await FirebaseManager.loginUser(
          uid: uid,
          displayName: name,
          email: email,
          photoUrl: _selectedAvatar,
        );

        if (profile != null) {
          widget.onLoginSuccess();
        } else {
          _showError('خطا در ثبت پروفایل در دیتابیس سرور.');
        }
      }
    } catch (e) {
      debugPrint("Google Login Error: $e");
      _showError('پیکربندی فایربیس یافت نشد. ورود شبیه‌سازی شده فعال شد.');
      await _handleMockLogin('Google');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAppleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final appleProvider = OAuthProvider("apple.com");
        userCredential = await FirebaseAuth.instance.signInWithPopup(appleProvider);
      } else {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final OAuthProvider oAuthProvider = OAuthProvider("apple.com");
        final credential = oAuthProvider.credential(
          idToken: appleCredential.identityToken,
          rawNonce: null,
        );
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final user = userCredential.user;
      if (user != null) {
        final name = user.displayName ?? _usernameController.text.trim();
        final email = user.email ?? '';
        final uid = user.uid;
        
        final profile = await FirebaseManager.loginUser(
          uid: uid,
          displayName: name,
          email: email,
          photoUrl: _selectedAvatar,
        );

        if (profile != null) {
          widget.onLoginSuccess();
        } else {
          _showError('خطا در ثبت پروفایل در دیتابیس سرور.');
        }
      }
    } catch (e) {
      debugPrint("Apple Login Error: $e");
      _showError('ورود با اپل در این محیط پشتیبانی نمی‌شود. ورود شبیه‌سازی شده فعال شد.');
      await _handleMockLogin('Apple');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(message, style: const TextStyle(fontFamily: 'serif')),
        ),
        backgroundColor: const Color(0xFF9E2A2B),
      ),
    );
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
              Container(color: Colors.black.withOpacity(0.6)), // Dark overlay
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Container(
                      padding: const EdgeInsets.all(32),
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
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wax Seal decoration
                          Image.asset(
                            'assets/images/wax_seal.png',
                            width: 100,
                            height: 100,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'راز هیتلر',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC92A2A),
                              letterSpacing: 4,
                            ),
                          ),
                          const Text(
                            'سیستم پروفایل و آمار بازیکنان',
                            style: TextStyle(
                              fontFamily: 'serif',
                              fontSize: 14,
                              color: Color(0xFFD4AF37),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 30),

                          if (_isLoading)
                            const CircularProgressIndicator(color: Color(0xFFD4AF37))
                          else ...[
                             _buildSocialButton(
                              label: 'ورود با اکانت گوگل',
                              icon: Icons.g_mobiledata,
                              color: const Color(0xFFDB4437),
                              onPressed: _handleGoogleLogin,
                            ),
                            const SizedBox(height: 16),
                            // Apple Login Button
                            _buildSocialButton(
                              label: 'ورود با اکانت اپل',
                              icon: Icons.apple,
                              color: Colors.black87,
                              onPressed: _handleAppleLogin,
                            ),
                            const SizedBox(height: 24),
                            // Guest Login Button
                            TextButton.icon(
                              onPressed: () {
                                final rand = Random();
                                final guestId = 'guest_${rand.nextInt(900000) + 100000}';
                                FirebaseManager.currentUserProfile = {
                                  'uid': guestId,
                                  'displayName': 'کاربر مهمان',
                                  'photoUrl': 'avatar_${rand.nextInt(12) + 1}',
                                  'stats': {
                                    'gamesPlayed': 0,
                                    'wins': 0,
                                    'losses': 0,
                                    'roles': {'Liberal': 0, 'Fascist': 0, 'Secret Hitler': 0}
                                  }
                                };
                                widget.onLoginSuccess();
                              },
                              icon: const Icon(Icons.person_outline, color: Colors.white54),
                              label: const Text(
                                'ورود به عنوان مهمان (بدون ثبت آمار)',
                                style: TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10, width: 1),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
