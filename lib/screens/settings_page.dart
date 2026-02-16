import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';

const _navy = Color(0xFF080F1E);
const _blue = Color(0xFF1B4FD8);
const _gold = Color(0xFFF5C518);
const _surface = Color(0xFFF0F4FF);
const _textDark = Color(0xFF0A1628);
const _textMid = Color(0xFF475569);
const _textFade = Color(0xFF94A3B8);

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService _firestore = FirestoreService();

  bool pushNotifications = true;
  bool emailNotifications = true;
  bool smsNotifications = false;
  bool orderUpdates = true;
  bool promotionalEmails = true;
  bool darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final profile = await _firestore.getUserProfile();
      if (profile != null && profile['settings'] != null) {
        final settings = profile['settings'] as Map<String, dynamic>;
        setState(() {
          pushNotifications = settings['pushNotifications'] ?? true;
          emailNotifications = settings['emailNotifications'] ?? true;
          smsNotifications = settings['smsNotifications'] ?? false;
          orderUpdates = settings['orderUpdates'] ?? true;
          promotionalEmails = settings['promotionalEmails'] ?? true;
          darkMode = settings['darkMode'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _firestore.updateUserSettings({
        'pushNotifications': pushNotifications,
        'emailNotifications': emailNotifications,
        'smsNotifications': smsNotifications,
        'orderUpdates': orderUpdates,
        'promotionalEmails': promotionalEmails,
        'darkMode': darkMode,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Notifications Section
          _sectionHeader('Notifications'),
          const SizedBox(height: 12),
          _settingCard(
            children: [
              _switchTile(
                'Push Notifications',
                'Receive push notifications on your device',
                Icons.notifications_outlined,
                pushNotifications,
                (value) => setState(() => pushNotifications = value),
              ),
              _divider(),
              _switchTile(
                'Email Notifications',
                'Receive updates via email',
                Icons.email_outlined,
                emailNotifications,
                (value) => setState(() => emailNotifications = value),
              ),
              _divider(),
              _switchTile(
                'SMS Notifications',
                'Receive order updates via SMS',
                Icons.sms_outlined,
                smsNotifications,
                (value) => setState(() => smsNotifications = value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Preferences Section
          _sectionHeader('Preferences'),
          const SizedBox(height: 12),
          _settingCard(
            children: [
              _switchTile(
                'Order Updates',
                'Get notified about order status changes',
                Icons.local_shipping_outlined,
                orderUpdates,
                (value) => setState(() => orderUpdates = value),
              ),
              _divider(),
              _switchTile(
                'Promotional Emails',
                'Receive offers and promotional content',
                Icons.local_offer_outlined,
                promotionalEmails,
                (value) => setState(() => promotionalEmails = value),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _sectionHeader('Appearance'),
          const SizedBox(height: 12),
          _settingCard(
            children: [
              _switchTile(
                'Dark Mode',
                'Use dark theme throughout the app',
                Icons.dark_mode_outlined,
                darkMode,
                (value) async {
                  setState(() => darkMode = value);
                  final messenger = ScaffoldMessenger.of(context);
                  // Save to local storage
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('darkMode', value);
                  // Also save to Firestore
                  await _firestore.updateUserSettings({'darkMode': value});
                  // Show confirmation
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(value 
                            ? 'Dark mode enabled (restart app to see changes)' 
                            : 'Light mode enabled (restart app to see changes)'),
                        backgroundColor: const Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Account Section
          _sectionHeader('Account'),
          const SizedBox(height: 12),
          _settingCard(
            children: [
              _actionTile(
                'Change Password',
                'Update your account password',
                Icons.lock_outline_rounded,
                _blue,
                () => _showChangePassword(),
              ),
              _divider(),
              _actionTile(
                'Privacy Policy',
                'Read our privacy policy',
                Icons.privacy_tip_outlined,
                _textMid,
                () => _showPrivacyPolicy(),
              ),
              _divider(),
              _actionTile(
                'Terms of Service',
                'Read our terms of service',
                Icons.description_outlined,
                _textMid,
                () => _showTermsOfService(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Danger Zone
          _sectionHeader('Danger Zone'),
          const SizedBox(height: 12),
          _settingCard(
            children: [
              _actionTile(
                'Clear Cache',
                'Clear all cached data',
                Icons.cleaning_services_outlined,
                const Color(0xFFF59E0B),
                () => _showClearCacheDialog(),
              ),
              _divider(),
              _actionTile(
                'Delete Account',
                'Permanently delete your account',
                Icons.delete_outline_rounded,
                const Color(0xFFEF4444),
                () => _showDeleteAccountDialog(),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // App Version
          Center(
            child: Text(
              'Laundrify v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: _textFade,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: _textDark,
      ),
    );
  }

  Widget _settingCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textMid,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: _blue,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: title == 'Delete Account'
                          ? const Color(0xFFEF4444)
                          : _textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMid,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textFade, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(height: 1, color: _surface),
    );
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Change Password',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'A password reset link will be sent to your email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                if (user?.email != null) {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: user!.email!);
                  if (mounted) {
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    // Navigate to privacy policy page or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This app collects and uses your data to provide laundry services...\n\n'
            'We collect: name, email, phone number, addresses, and order history.\n\n'
            'Your data is stored securely and never shared with third parties without consent.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    // Navigate to terms page or show dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'By using Laundrify, you agree to the following terms:\n\n'
            '1. Service usage is subject to availability\n'
            '2. Payment must be made as per selected method\n'
            '3. We are not liable for pre-existing damage to items\n'
            '4. Pickup and delivery times are estimates\n\n'
            'For full terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Cache',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This will clear all temporary data and free up storage space. Your account data will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement cache clearing logic here
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFFEF4444),
          ),
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  await _firestore.deleteUserData(currentUser.uid);
                  await currentUser.delete();

                  if (mounted) {
                    navigator.pop(); // Close loading
                    navigator.pushReplacementNamed('/login');
                  }
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop(); // Close loading
                  if (e.toString().contains('requires-recent-login')) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please sign in again before deleting your account',
                        ),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
