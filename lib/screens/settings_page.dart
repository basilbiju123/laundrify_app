import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_options_page.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _navy = Color(0xFF080F1E);
  static const _gold = Color(0xFFF5C518);
  static const _bg = Color(0xFFF0F4FF);
  static const _card = Colors.white;

  bool get _darkMode => ThemeService().isDarkMode;
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
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
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
                  await ThemeService().setDarkMode(v);
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

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      );

  Widget _settingCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(children: children),
      );

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
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _navy)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8))),
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
                    color: color ?? _navy,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color ?? const Color(0xFF94A3B8), size: 20),
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
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Delete all user subcollections data
          final batch = FirebaseFirestore.instance.batch();
          // Delete user document
          batch.delete(FirebaseFirestore.instance.collection('users').doc(user.uid));
          await batch.commit();
          // Delete Firebase Auth account
          await user.delete();
        }
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthOptionsPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please sign out and sign back in before deleting your account.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}
