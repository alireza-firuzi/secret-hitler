import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
          final isSetupOk = await _checkAndPromptSetup();
          if (isSetupOk) {
            widget.onLoginSuccess();
          }
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

  Future<void> _handlePhoneLogin() async {
    final phoneController = TextEditingController();
    
    // 1. Show Phone Number Dialog
    final phone = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1917),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text('ورود با شماره موبایل', style: TextStyle(color: Colors.white, fontSize: 16)),
            content: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'مثال: 09123456789',
                hintStyle: TextStyle(color: Colors.white24),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                  final txt = phoneController.text.trim();
                  if (txt.isNotEmpty) {
                    Navigator.pop(context, txt);
                  }
                },
                child: const Text('ارسال کد', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );

    if (phone == null || phone.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final devCode = await FirebaseManager.sendOtp(phone);
    
    setState(() {
      _isLoading = false;
    });

    if (devCode == null) {
      _showError('خطا در ارسال کد به شماره موبایل شما.');
      return;
    }

    final codeController = TextEditingController();
    
    // 2. Show Verification Code Dialog
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1C1917),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text('کد تایید پیامک شد', style: TextStyle(color: Colors.white, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'کد به شماره $phone ارسال شد.',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  'کد تایید (تست): $devCode',
                  style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 6),
                  decoration: const InputDecoration(
                    hintText: '******',
                    hintStyle: TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: () {
                  final code = codeController.text.trim();
                  if (code.length == 6) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('تایید و ورود', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        );
      },
    );

    if (verified != true) return;

    setState(() {
      _isLoading = true;
    });

    final success = await FirebaseManager.verifyOtp(phone, codeController.text.trim());
    if (success) {
      final rand = Random();
      final uid = 'otp_${phone.replaceAll('+', '')}';
      final defaultAvatar = 'avatar_${rand.nextInt(12) + 1}';
      
      final profile = await FirebaseManager.loginUser(
        uid: uid,
        displayName: 'موبایل ${phone.substring(max(0, phone.length - 4))}',
        photoUrl: defaultAvatar,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (profile != null) {
        final isSetupOk = await _checkAndPromptSetup();
        if (isSetupOk) {
          widget.onLoginSuccess();
        }
      } else {
        _showError('خطا در ثبت پروفایل در دیتابیس.');
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError('کد وارد شده صحیح نیست یا منقضی شده است.');
    }
  }

  Future<bool> _checkAndPromptSetup() async {
    final profile = FirebaseManager.currentUserProfile;
    if (profile == null) return false;
    
    if (profile['needsSetup'] != true && profile['needsUsername'] != true) {
      return true;
    }
    
    final usernameController = TextEditingController();
    final displayNameController = TextEditingController();
    String selectedAvatar = 'avatar_1';
    String? errorMessage;
    bool dialogLoading = false;
    
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1C1917),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                title: const Text(
                  'تنظیمات نهایی حساب کاربری',
                  style: TextStyle(
                    fontFamily: 'serif',
                    color: Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'انتخاب تصویر نمایه (آواتار):',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'serif'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final avatarName = 'avatar_${index + 1}';
                            final isSelected = selectedAvatar == avatarName;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  selectedAvatar = avatarName;
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
                                  radius: 24,
                                  backgroundColor: const Color(0xFF151211),
                                  backgroundImage: AssetImage('assets/images/$avatarName.png'),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'نام کاربری (حروف انگلیسی و عدد - یکتا):',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'serif'),
                      ),
                      TextField(
                        controller: usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'مثال: secret_agent_99',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'نام درون بازی (حتماً زبان فارسی):',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontFamily: 'serif'),
                      ),
                      TextField(
                        controller: displayNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'مثال: کارآگاه علوی',
                          hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
                        ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMessage!,
                          style: const TextStyle(color: Color(0xFF9E2A2B), fontSize: 12, fontFamily: 'serif'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: dialogLoading ? null : () {
                      FirebaseManager.currentUserProfile = null;
                      Navigator.pop(context, false);
                    },
                    child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                    onPressed: dialogLoading ? null : () async {
                      final username = usernameController.text.trim();
                      final displayName = displayNameController.text.trim();
                      
                      if (username.isEmpty || displayName.isEmpty) {
                        setDialogState(() {
                          errorMessage = 'لطفاً تمامی فیلدها را پر کنید';
                        });
                        return;
                      }
                      
                      final allowedUsername = RegExp(r'^[a-zA-Z0-9_]+$');
                      if (!allowedUsername.hasMatch(username)) {
                        setDialogState(() {
                          errorMessage = 'نام کاربری فقط می‌تواند شامل حروف انگلیسی، عدد و (_) باشد';
                        });
                        return;
                      }

                      final allowedDisplayName = RegExp(r'^[\u0600-\u06FF\u200C\s0-9]+$');
                      final letterRegex = RegExp(r'[\u0622-\u0628\u062A-\u063A\u0641-\u0642\u0644-\u0648\u067E\u0686\u0698\u06A9\u06AF\u06CC]');
                      if (!allowedDisplayName.hasMatch(displayName) || !letterRegex.hasMatch(displayName)) {
                        setDialogState(() {
                          errorMessage = 'نام درون بازی باید فقط شامل حروف فارسی باشد';
                        });
                        return;
                      }

                      setDialogState(() {
                        dialogLoading = true;
                        errorMessage = null;
                      });
                      
                      try {
                        final result = await FirebaseManager.setupProfile(
                          uid: profile['uid'],
                          username: username,
                          displayName: displayName,
                          photoUrl: selectedAvatar,
                        );
                        
                        if (result['success'] == true) {
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } else {
                          if (context.mounted) {
                            setDialogState(() {
                              dialogLoading = false;
                              errorMessage = result['error'] ?? 'خطا در ثبت اطلاعات';
                            });
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() {
                            dialogLoading = false;
                            errorMessage = 'خطا در اتصال به سرور';
                          });
                        }
                      }
                    },
                    child: dialogLoading 
                      ? const SizedBox(
                          width: 16, 
                          height: 16, 
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text('ثبت و ورود', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    
    return success == true;
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
        backgroundColor: const Color(0xFF0F0B0A),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/wood_table_background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Cinematic radial vignette overlay
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    radius: 1.2,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                          decoration: BoxDecoration(
                            color: const Color(0xCC1A1312),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withOpacity(0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Breathing animated Monogram Wax Seal Logo
                              TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0.97, end: 1.03),
                                duration: const Duration(seconds: 3),
                                curve: Curves.easeInOut,
                                builder: (context, scale, child) {
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC92A2A).withOpacity(0.25),
                                        blurRadius: 15,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/wax_seal.png',
                                    width: 110,
                                    height: 110,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Luxury Title
                              Text(
                                'راز هیتلر',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFC92A2A),
                                  letterSpacing: 4,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(2, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'باشگاه آنلاین کارآگاهان و احراز هویت',
                                style: TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFD4AF37).withOpacity(0.85),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 36),

                              if (_isLoading)
                                const Center(
                                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                                )
                              else ...[
                                _buildSocialButton(
                                  label: 'ورود امن با اکانت گوگل',
                                  icon: Icons.g_mobiledata,
                                  color: const Color(0xFF1E1B1A),
                                  borderColor: const Color(0xFFDB4437).withOpacity(0.4),
                                  onPressed: _handleGoogleLogin,
                                  iconColor: const Color(0xFFDB4437),
                                ),
                                const SizedBox(height: 16),
                                _buildSocialButton(
                                  label: 'ورود سریع با شماره موبایل',
                                  icon: Icons.phone_android_rounded,
                                  color: const Color(0xFF1E1B1A),
                                  borderColor: const Color(0xFFD4AF37).withOpacity(0.4),
                                  onPressed: _handlePhoneLogin,
                                  iconColor: const Color(0xFFD4AF37),
                                ),
                                const SizedBox(height: 24),
                                const Divider(color: Colors.white10),
                                const SizedBox(height: 12),
                                // Guest Login Button
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white38,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onPressed: () async {
                                    final rand = Random();
                                    final guestId = 'guest_${rand.nextInt(900000) + 100000}';
                                    final defaultAvatar = 'avatar_${rand.nextInt(12) + 1}';
                                    
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    
                                    final profile = await FirebaseManager.loginUser(
                                      uid: guestId,
                                      displayName: 'کاربر مهمان',
                                      photoUrl: defaultAvatar,
                                    );
                                    
                                    if (mounted) {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                    
                                    if (profile != null) {
                                      widget.onLoginSuccess();
                                    } else {
                                      FirebaseManager.currentUserProfile = {
                                        'uid': guestId,
                                        'displayName': 'کاربر مهمان',
                                        'photoUrl': defaultAvatar,
                                        'stats': {
                                          'gamesPlayed': 0,
                                          'wins': 0,
                                          'losses': 0,
                                          'roles': {'Liberal': 0, 'Fascist': 0, 'Secret Hitler': 0}
                                        }
                                      };
                                      widget.onLoginSuccess();
                                    }
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.person_outline_rounded, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'ورود مستقیم به عنوان مهمان',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'serif',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color borderColor,
    required VoidCallback onPressed,
    required Color iconColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: iconColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
