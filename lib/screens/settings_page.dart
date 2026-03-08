import 'auth_options_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/panel_theme_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);

  // Access user panel theme service directly via the static cache
  PanelThemeService get _userTheme => PanelThemeService.forKey('user');

  bool get _darkMode => _userTheme.isDark;
  bool _orderNotifications = true;
  bool _promotionalNotifications = true;
  bool _smsAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _orderNotifications = prefs.getBool('orderNotifications') ?? true;
      _promotionalNotifications = prefs.getBool('promoNotifications') ?? true;
      _smsAlerts = prefs.getBool('smsAlerts') ?? false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('orderNotifications', _orderNotifications);
    await prefs.setBool('promoNotifications', _promotionalNotifications);
    await prefs.setBool('smsAlerts', _smsAlerts);
    // Sync push notification opt-in/out with OneSignal
    try {
      if (_orderNotifications) {
        await NotificationService.optInToNotifications();
      } else {
        await NotificationService.optOutOfNotifications();
      }
    } catch (_) {} // Non-fatal
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Settings saved'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // APPEARANCE
            _sectionTitle('Appearance'),
            const SizedBox(height: 12),
            _settingCard([
              _toggleTile(
                'Dark Mode',
                'Switch to dark theme',
                Icons.dark_mode_rounded,
                _darkMode,
                (v) async {
                  await _userTheme.setDark(v);
                  if (mounted) setState(() {});
                },
              ),
            ]),

            const SizedBox(height: 20),

            // NOTIFICATIONS
            _sectionTitle('Notifications'),
            const SizedBox(height: 12),
            _settingCard([
              _toggleTile(
                'Order Updates',
                'Get notified about your order status',
                Icons.shopping_bag_rounded,
                _orderNotifications,
                (v) => setState(() => _orderNotifications = v),
              ),
              const Divider(height: 1, color: Color(0xFFE8EDF5)),
              _toggleTile(
                'Promotions & Offers',
                'Receive deals and discount notifications',
                Icons.local_offer_rounded,
                _promotionalNotifications,
                (v) => setState(() => _promotionalNotifications = v),
              ),
              const Divider(height: 1, color: Color(0xFFE8EDF5)),
              _toggleTile(
                'SMS Alerts',
                'Receive alerts via SMS',
                Icons.sms_rounded,
                _smsAlerts,
                (v) => setState(() => _smsAlerts = v),
              ),
            ]),

            const SizedBox(height: 20),

            // ACCOUNT
            _sectionTitle('Account'),
            const SizedBox(height: 12),
            _settingCard([
              _actionTile(
                'Change Password',
                Icons.lock_outline_rounded,
                () => _sendPasswordReset(),
              ),
              const Divider(height: 1, color: Color(0xFFE8EDF5)),
              _actionTile(
                'Delete Account',
                Icons.delete_outline_rounded,
                () => _showDeleteDialog(),
                color: Colors.red,
              ),
            ]),

            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _saveSettings,
                child: const Text(
                  'SAVE SETTINGS',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // VERSION INFO
            Center(
              child: Text(
                'Laundrify v2.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    final t = AppColors.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: t.textDim,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _settingCard(List<Widget> children) {
    final t = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBdr),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _toggleTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    void Function(bool) onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _gold, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.of(context).textHi)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.of(context).textDim)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _gold,
              activeTrackColor: _gold.withValues(alpha: 0.3),
            ),
          ],
        ),
      );

  Widget _actionTile(String title, IconData icon, VoidCallback onTap,
          {Color? color}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color ?? const Color(0xFF475569), size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.of(context).textHi,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color ?? AppColors.of(context).textDim, size: 20),
            ],
          ),
        ),
      );

  Future<void> _sendPasswordReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to ${user.email}'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _performDeleteAccount();
    }
  }

  Future<void> _performDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Delete Firestore data first
      final db = FirebaseFirestore.instance;
      final uid = user.uid;

      // Delete subcollections
      final subcolls = ['notifications', 'cart', 'addresses', 'orders'];
      for (final sub in subcolls) {
        final snap = await db.collection('users').doc(uid).collection(sub).get();
        for (final doc in snap.docs) { await doc.reference.delete(); }
      }
      // Delete user document
      await db.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
      await user.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.of(context).pop(); // close loading
      if (e.code == 'requires-recent-login' && mounted) {
        // Need to reauthenticate first
        await _reauthAndDelete(user);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message ?? 'Failed to delete account'}'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account. Please try again.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _reauthAndDelete(User user) async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Identity', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('For security, please enter your password to delete your account.'),
          const SizedBox(height: 16),
          TextField(
            controller: passwordCtrl,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock_outline_rounded),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: passwordCtrl.text.trim(),
        );
        await user.reauthenticateWithCredential(cred);
        await _performDeleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Incorrect password. Account not deleted.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    passwordCtrl.dispose();
  }
}
