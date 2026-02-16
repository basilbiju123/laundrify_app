import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = user?.displayName ?? '';
    _loadPhoneFromFirestore();
  }

  Future<void> _loadPhoneFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      if (doc.exists && mounted) {
        final phone = doc.data()?['phone'] as String? ?? '';
        setState(() => _phoneController.text = phone);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await user?.updateDisplayName(_nameController.text.trim());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .update({'name': _nameController.text.trim()});
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
      _snack('Profile updated successfully', isError: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _snack('Failed to update profile', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor:
          isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _handleAddPhone() {
    final phoneCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Phone Number',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A1628),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'We\'ll send an OTP to verify your number',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A1628),
                ),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon: const Icon(Icons.phone_outlined,
                      color: Color(0xFF1B4FD8), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF4F7FE),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF1B4FD8), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    final phone = phoneCtrl.text.trim();
                    if (phone.length < 10) {
                      _snack('Enter a valid 10-digit number', isError: true);
                      return;
                    }
                    Navigator.pop(context);
                    // Navigate to OTP page - on return update profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OtpPage(
                          phone: phone,
                          name: user?.displayName ?? '',
                          email: user?.email ?? '',
                          password: '',
                          isPhoneUpdate: true,
                        ),
                      ),
                    ).then((_) => _loadPhoneFromFirestore());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF080F1E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'SEND OTP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initials = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName![0].toUpperCase()
        : (user?.email?.isNotEmpty == true
            ? user!.email![0].toUpperCase()
            : 'U');

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          // ── Sliver App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF080F1E),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              if (!_isEditing)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Colors.white, size: 18),
                  ),
                  onPressed: () => setState(() => _isEditing = true),
                )
              else
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                  onPressed: () {
                    _nameController.text = user?.displayName ?? '';
                    setState(() => _isEditing = false);
                  },
                ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF080F1E),
                      Color(0xFF0D1F3C),
                      Color(0xFF0D2D6B),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative orbs
                    Positioned(
                      right: -30,
                      top: -30,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -20,
                      bottom: 0,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFF5C518).withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    // Avatar + name
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF5C518), Color(0xFFFDE68A)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF5C518)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Color(0xFF080F1E),
                                shape: BoxShape.circle,
                              ),
                              child: user?.photoURL != null
                                  ? CircleAvatar(
                                      radius: 44,
                                      backgroundImage:
                                          NetworkImage(user!.photoURL!),
                                    )
                                  : CircleAvatar(
                                      radius: 44,
                                      backgroundColor: const Color(0xFF1B4FD8)
                                          .withValues(alpha: 0.3),
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Verified badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: user?.emailVerified == true
                                  ? const Color(0xFFF5C518)
                                      .withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  user?.emailVerified == true
                                      ? Icons.verified_rounded
                                      : Icons.pending_outlined,
                                  color: user?.emailVerified == true
                                      ? const Color(0xFFF5C518)
                                      : Colors.white54,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user?.emailVerified == true
                                      ? 'Verified'
                                      : 'Pending Verification',
                                  style: TextStyle(
                                    color: user?.emailVerified == true
                                        ? const Color(0xFFF5C518)
                                        : Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Personal Info ──────────────────────────────────
                  _sectionCard(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                    child: Column(
                      children: [
                        _infoRow(
                          label: 'Full Name',
                          icon: Icons.badge_outlined,
                          child: _isEditing
                              ? _editField(
                                  controller: _nameController,
                                  hint: 'Full Name',
                                )
                              : Text(
                                  user?.displayName ?? 'Not set',
                                  style: _valueStyle,
                                ),
                        ),
                        _divider(),
                        _infoRow(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          child: Text(
                            user?.email ?? 'Not set',
                            style: _valueStyle,
                          ),
                          trailing: user?.emailVerified == true
                              ? _badge('Verified', const Color(0xFF10B981))
                              : _badge('Unverified', const Color(0xFFF59E0B)),
                        ),
                        _divider(),
                        _infoRow(
                          label: 'Phone',
                          icon: Icons.phone_outlined,
                          child: Text(
                            _phoneController.text.isNotEmpty
                                ? _phoneController.text
                                : 'Not added',
                            style: _phoneController.text.isNotEmpty
                                ? _valueStyle
                                : _valueStyle.copyWith(
                                    color: Colors.grey.shade400,
                                    fontStyle: FontStyle.italic,
                                  ),
                          ),
                          trailing: GestureDetector(
                            onTap: _handleAddPhone,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B4FD8)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _phoneController.text.isNotEmpty
                                    ? 'Change'
                                    : '+ Add',
                                style: const TextStyle(
                                  color: Color(0xFF1B4FD8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_isEditing) ...[
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF080F1E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Preferences ─────────────────────────────────────
                  _sectionCard(
                    icon: Icons.tune_rounded,
                    title: 'Preferences',
                    child: Column(
                      children: [
                        _switchRow(
                          label: 'Push Notifications',
                          sub: 'Receive order updates',
                          icon: Icons.notifications_outlined,
                          value: _notificationsEnabled,
                          onChanged: (v) =>
                              setState(() => _notificationsEnabled = v),
                        ),
                        _divider(),
                        _switchRow(
                          label: 'Email Notifications',
                          sub: 'Get updates via email',
                          icon: Icons.email_outlined,
                          value: _emailNotifications,
                          onChanged: (v) =>
                              setState(() => _emailNotifications = v),
                        ),
                        _divider(),
                        _switchRow(
                          label: 'SMS Notifications',
                          sub: 'Receive SMS updates',
                          icon: Icons.sms_outlined,
                          value: _smsNotifications,
                          onChanged: (v) =>
                              setState(() => _smsNotifications = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Account Actions ──────────────────────────────────
                  _sectionCard(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Account',
                    child: Column(
                      children: [
                        _actionRow(
                          label: 'Change Password',
                          icon: Icons.lock_outline_rounded,
                          color: const Color(0xFF1B4FD8),
                          onTap: () => _snack(
                              'Change password feature coming soon',
                              isError: false),
                        ),
                        _divider(),
                        _actionRow(
                          label: 'Privacy Policy',
                          icon: Icons.privacy_tip_outlined,
                          color: const Color(0xFF64748B),
                          onTap: () => _snack('Privacy policy coming soon',
                              isError: false),
                        ),
                        _divider(),
                        _actionRow(
                          label: 'Terms of Service',
                          icon: Icons.description_outlined,
                          color: const Color(0xFF64748B),
                          onTap: () =>
                              _snack('Terms coming soon', isError: false),
                        ),
                        _divider(),
                        _actionRow(
                          label: 'Delete Account',
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444),
                          onTap: _showDeleteDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign out button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await FirebaseAuth.instance.signOut();
                        nav.pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(
                            color: Color(0xFFEF4444), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  TextStyle get _valueStyle => const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0A1628),
      );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4FD8).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1B4FD8), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0A1628),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFF64748B), size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                child,
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0A1628),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: const Color(0xFFF0F4FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B4FD8), width: 1.5),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        color: Colors.grey.shade100,
        indent: 42,
      );

  Widget _switchRow({
    required String label,
    required String sub,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: const Color(0xFF64748B), size: 17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A1628))),
                Text(sub,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFF10B981),
            thumbColor: WidgetStateProperty.all(Colors.white),
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade300, size: 22),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _snack('Account deletion coming soon', isError: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
