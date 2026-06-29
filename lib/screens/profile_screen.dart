import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../logic/firebase_manager.dart';
import '../widgets/avatar_helper.dart';
import '../widgets/image_cropper_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _displayName;
  late String _photoUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = FirebaseManager.currentUserProfile ?? {};
    _displayName = profile['displayName'] ?? 'کاربر مهمان';
    _photoUrl = profile['photoUrl'] ?? 'avatar_1';
  }

  Future<void> _updateAvatar(String avatarName) async {
    setState(() {
      _photoUrl = avatarName;
    });
    await _saveProfileChanges();
  }

  Future<void> _editDisplayName() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF2C2523),
            title: const Text('ویرایش نام کاربری', style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'serif')),
            content: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('انصراف', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('ثبت'),
              ),
            ],
          ),
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != _displayName) {
      final allowedDisplayName = RegExp(r'^[\u0600-\u06FF\u200C\s0-9]+$');
      final letterRegex = RegExp(r'[\u0622-\u0628\u062A-\u063A\u0641-\u0642\u0644-\u0648\u067E\u0686\u0698\u06A9\u06AF\u06CC]');
      if (!allowedDisplayName.hasMatch(newName) || !letterRegex.hasMatch(newName)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نام درون بازی باید فقط شامل حروف فارسی باشد', style: TextStyle(fontFamily: 'serif')),
            backgroundColor: Color(0xFF9E2A2B),
          ),
        );
        return;
      }
      
      setState(() {
        _displayName = newName;
      });
      await _saveProfileChanges();
    }
  }

  Future<void> _saveProfileChanges() async {
    final profile = FirebaseManager.currentUserProfile;
    if (profile == null) return;
    
    // Check if player is guest (we don't persist guests on server)
    final String uid = profile['uid'] ?? '';
    if (uid.startsWith('guest_')) {
      setState(() {
        profile['displayName'] = _displayName;
        profile['photoUrl'] = _photoUrl;
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await FirebaseManager.updateProfile(
        uid: uid,
        displayName: _displayName,
        photoUrl: _photoUrl,
      );
      if (updated != null) {
        setState(() {
          FirebaseManager.currentUserProfile = updated;
        });
      }
    } catch (e) {
      debugPrint("Error updating profile on server: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = FirebaseManager.currentUserProfile ?? {};
    final stats = profile['stats'] ?? {};
    final int gamesPlayed = stats['gamesPlayed'] ?? 0;
    final int wins = stats['wins'] ?? 0;
    final int losses = stats['losses'] ?? 0;
    final double winRate = gamesPlayed > 0 ? (wins / gamesPlayed) * 100 : 0.0;

    final roles = stats['roles'] ?? {};
    final int liberalCount = roles['Liberal'] ?? 0;
    final int fascistCount = roles['Fascist'] ?? 0;
    final int hitlerCount = roles['Secret Hitler'] ?? 0;

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
                        'پروفایل من',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE6DFD3),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          // Profile details card
                          _buildProfileCard(),
                          const SizedBox(height: 24),
                          // Stats grid
                          _buildStatsGrid(gamesPlayed, wins, losses, winRate),
                          const SizedBox(height: 24),
                          // Roles breakdown panel
                          _buildRolesBreakdownCard(liberalCount, fascistCount, hitlerCount),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_isSaving)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final profile = FirebaseManager.currentUserProfile ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xE6251E1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Row(
        children: [
          // Current Avatar with Change button
          GestureDetector(
            onTap: _showAvatarSelectionDialog,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                buildAvatarCircle(
                  _photoUrl,
                  radius: 56,
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 14, color: Colors.black),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // User name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _displayName,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_note, color: Color(0xFFD4AF37), size: 20),
                      onPressed: _editDisplayName,
                    ),
                  ],
                ),
                if (profile['username'] != null && (profile['username'] as String).isNotEmpty) ...[
                  Text(
                    '@${profile['username']}',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontFamily: 'serif'),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  (FirebaseManager.currentUserProfile?['uid'] ?? '').startsWith('guest_')
                      ? 'بازیکن مهمان'
                      : 'بازیکن ثبت شده در شبکه',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int games, int wins, int losses, double rate) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatTile('کل بازی‌ها', games.toString(), Icons.videogame_asset, Colors.blueAccent),
        _buildStatTile('تعداد بردها', wins.toString(), Icons.emoji_events, Colors.amber),
        _buildStatTile('تعداد باخت‌ها', losses.toString(), Icons.sentiment_very_dissatisfied, Colors.redAccent),
        _buildStatTile('درصد برد', '${rate.toStringAsFixed(1)}%', Icons.show_chart, Colors.teal),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6251E1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesBreakdownCard(int lib, int fas, int hit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xE6251E1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'نقش‌های بازی شده',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37), fontFamily: 'serif'),
          ),
          const SizedBox(height: 16),
          _buildRoleRow('لیبرال (Liberal)', lib, const Color(0xFF2E7D32)),
          const SizedBox(height: 12),
          _buildRoleRow('فاشیست (Fascist)', fas, const Color(0xFFC62828)),
          const SizedBox(height: 12),
          _buildRoleRow('هیتلر مخفی (Secret Hitler)', hit, const Color(0xFFE65100)),
        ],
      ),
    );
  }

  Widget _buildRoleRow(String roleName, int count, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(roleName, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        Text('$count بار', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  void _pickAndCropImage() {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        
        // Limit size to max 8 MB
        if (file.size > 8 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('حجم فایل انتخاب شده بسیار زیاد است. حداکثر حجم مجاز ۸ مگابایت می‌باشد.', style: TextStyle(fontFamily: 'serif')),
              backgroundColor: Color(0xFF9E2A2B),
            ),
          );
          return;
        }

        final reader = html.FileReader();
        reader.readAsDataUrl(file);
        reader.onLoadEnd.listen((e) async {
          final base64Data = reader.result as String;
          if (!mounted) return;

          // Open cropper dialog
          final croppedResult = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) => ImageCropperDialog(imageBase64: base64Data),
          );

          if (croppedResult != null) {
            await _updateAvatar(croppedResult);
          }
        });
      }
    });
  }

  void _showAvatarSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: const Color(0xFF2C2523),
            title: const Text('تغییر تصویر پروفایل', style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'serif')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 320,
                  height: 180,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final avatarName = 'avatar_${index + 1}';
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _updateAvatar(avatarName);
                        },
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF151211),
                          backgroundImage: AssetImage('assets/images/$avatarName.png'),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('آپلود تصویر دلخواه', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  onPressed: () {
                    Navigator.pop(context);
                    _pickAndCropImage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
