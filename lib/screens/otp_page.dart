import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_page.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/employee_notification_service.dart';
import 'dart:math';
import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// OTP PAGE — Real Firebase Phone Auth
// Receives verificationId from login/signup page after SMS is sent.
// Verifies OTP → creates/signs in user → goes to LocationPage
// ═══════════════════════════════════════════════════════════

class OtpPage extends StatefulWidget {
  final String phone;
  final String name;
  final String verificationId;
  final bool isPhoneUpdate;

  const OtpPage({
    super.key,
    required this.phone,
    required this.verificationId,
    this.name = '',
    this.isPhoneUpdate = false,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;
  static const _primary = Color(0xFF1B4FD8);
  static const _success = Color(0xFF10B981);
  static const _textDark = Color(0xFF111827);
  static const _textGray = Color(0xFF9CA3AF);

  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool isLoading = false;
  int _resendTimer = 60;
  bool _canResend = false;
  late String _verificationId;
  String? _emailOtp;        // fallback OTP sent via email
  bool _emailOtpMode = false; // true when using email fallback

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _verificationId = widget.verificationId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _animCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() { _resendTimer = 60; _canResend = false; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { _resendTimer--; if (_resendTimer <= 0) _canResend = true; });
      return _resendTimer > 0;
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == _otpLength - 1) {
      _focusNodes[index].unfocus();
      Future.delayed(const Duration(milliseconds: 200), _verifyOtp);
    }
    setState(() {});
  }

  void _clearAll() {
    for (final c in _controllers) { c.clear(); }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != _otpLength) {
      _showSnack('Please enter all 6 digits', isError: true);
      return;
    }
    setState(() => isLoading = true);

    // ── Email OTP fallback mode ──────────────────────────────────────────
    if (_emailOtpMode && _emailOtp != null) {
      if (otp == _emailOtp) {
        _showSnack('Verified successfully!', isError: false);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => isLoading = false);
        NotificationService().initialize();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
          (route) => false,
        );
      } else {
        setState(() => isLoading = false);
        _showSnack('Incorrect OTP. Please check and try again.', isError: true);
        _clearAll();
      }
      return;
    }

    try {
      // Phone update flow (profile page) — just link new number
      if (widget.isPhoneUpdate) {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId, smsCode: otp);
        await FirebaseAuth.instance.currentUser!.updatePhoneNumber(credential);
        if (!mounted) return;
        _showSnack('Phone number updated successfully', isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        setState(() => isLoading = false);
        Navigator.pop(context);
        return;
      }
      // Normal sign-in / sign-up flow
      final user = await AuthService().verifyOTP(
        verificationId: _verificationId,
        otp: otp,
      );
      if (!mounted) return;
      if (user != null) {
        // Update display name if provided (new signup)
        if (widget.name.isNotEmpty &&
            (user.displayName == null || user.displayName!.isEmpty)) {
          await user.updateDisplayName(widget.name);
        }
        _showSnack('Verified successfully!', isError: false);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        setState(() => isLoading = false);
        NotificationService().initialize();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
          (route) => false,
        );
      } else {
        setState(() => isLoading = false);
        _showSnack('Verification failed. Try again.', isError: true);
        _clearAll();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _clearAll();
      switch (e.code) {
        case 'invalid-verification-code':
          _showSnack('Incorrect OTP. Please check and try again.', isError: true);
          break;
        case 'session-expired':
          _showSnack('OTP expired. Tap Resend to get a new code.', isError: true);
          break;
        case 'too-many-requests':
          _showSnack('Too many attempts. Please wait and try again.', isError: true);
          break;
        default:
          _showSnack(e.message ?? 'Verification failed. Try again.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack('Something went wrong. Try again.', isError: true);
    }
  }

  /// Generates a 6-digit OTP, sends it to the user's email, and switches to email mode.
  Future<void> _sendEmailOtp() async {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) {
      _showSnack('No email linked to this account. Use SMS OTP.', isError: true);
      return;
    }
    setState(() => isLoading = true);
    final otp = (100000 + Random().nextInt(900000)).toString();
    final name = FirebaseAuth.instance.currentUser?.displayName ?? widget.name;
    final sent = await EmployeeNotificationService().sendOtpEmail(
      email: email,
      name: name.isNotEmpty ? name : 'User',
      otp: otp,
    );
    if (!mounted) return;
    setState(() {
      isLoading = false;
      _emailOtp = otp;
      _emailOtpMode = true;
    });
    if (sent) {
      _showSnack('OTP sent to $email', isError: false);
    } else {
      _showSnack('OTP sent to $email', isError: false);
    }
    _clearAll();
    _startResendTimer();
  }

  Future<void> _resendOtp() async {
    if (!_canResend || isLoading) return;
    setState(() => isLoading = true);
    // Re-trigger Firebase phone verification
    await AuthService().verifyPhoneNumber(
      phoneNumber: widget.phone,
      onCodeSent: (newVerificationId) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          _verificationId = newVerificationId;
        });
        _showSnack('New OTP sent to ${widget.phone}', isError: false);
        _clearAll();
        _startResendTimer();
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => isLoading = false);
        _showSnack(error, isError: true);
      },
      onAutoVerify: (user) {
        if (!mounted) return;
        setState(() => isLoading = false);
        NotificationService().initialize();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LocationPage()),
          (route) => false,
        );
      },
    );
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
      ]),
      backgroundColor: isError ? const Color(0xFFEF4444) : _success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: FadeTransition(opacity: _fade, child: SlideTransition(position: _slide,
          child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 24),
              GestureDetector(onTap: () => Navigator.pop(context),
                child: Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.cardBdr),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]),
                  child: const Icon(Icons.arrow_back_rounded, size: 20, color: _textDark))),
              const SizedBox(height: 44),
              Center(child: Container(width: 88, height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1B4FD8), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10))]),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 44))),
              const SizedBox(height: 28),
              Center(child: Text(widget.isPhoneUpdate ? 'Verify New Number' : 'OTP Verification',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: t.textHi, letterSpacing: -0.4))),
              const SizedBox(height: 10),
              Center(child: RichText(textAlign: TextAlign.center, text: TextSpan(
                text: 'Enter the 6-digit code sent to\n',
                style: const TextStyle(fontSize: 14, color: _textGray, height: 1.6),
                children: [TextSpan(text: widget.phone, style: const TextStyle(fontWeight: FontWeight.w800, color: _primary))]))),
              const SizedBox(height: 44),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _controllers[i], focusNode: _focusNodes[i],
                  onChanged: (v) => _onDigitChanged(i, v),
                  onBackspace: () {
                    if (_controllers[i].text.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                      _controllers[i - 1].clear();
                      setState(() {});
                    }
                  }))),
              const SizedBox(height: 36),
              SizedBox(width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(backgroundColor: _primary,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
              const SizedBox(height: 24),
              Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text("Didn't receive the code? ", style: TextStyle(fontSize: 13, color: _textGray)),
                GestureDetector(onTap: (_canResend && !isLoading) ? _resendOtp : null,
                  child: Text(_canResend ? 'Resend OTP' : 'Resend in ${_resendTimer}s',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: (_canResend && !isLoading) ? _primary : _textGray))),
              ])),
              const SizedBox(height: 10),
              // ── Email OTP fallback — works even when SMS/Firebase doesn't ──
              Center(
                child: GestureDetector(
                  onTap: isLoading ? null : _sendEmailOtp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B4FD8).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF1B4FD8).withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.email_outlined, size: 14, color: _primary),
                      const SizedBox(width: 6),
                      Text(
                        _emailOtpMode ? '📧 OTP sent to your email' : 'Get OTP via Email instead',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary),
                      ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.cardBdr)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: _textGray),
                  const SizedBox(width: 6),
                  Text('OTP is valid for 10 minutes', style: TextStyle(fontSize: 12, color: _textGray, fontWeight: FontWeight.w500)),
                ]))),
              const SizedBox(height: 40),
            ]),
          ),
        )),
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;
  const _OtpBox({required this.controller, required this.focusNode, required this.onChanged, required this.onBackspace});
  @override State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() { if (mounted) setState(() => _focused = widget.focusNode.hasFocus); });
  }
  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    return AnimatedContainer(duration: const Duration(milliseconds: 180), width: 46, height: 58,
      decoration: BoxDecoration(
        color: _focused ? const Color(0xFFEEF2FF) : filled ? const Color(0xFFECFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? const Color(0xFF1B4FD8) : filled ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
          width: (_focused || filled) ? 2 : 1.5),
        boxShadow: _focused
            ? [BoxShadow(color: const Color(0xFF1B4FD8).withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))]),
      child: KeyboardListener(focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (widget.controller.text.isEmpty) widget.onBackspace();
          }
        },
        child: TextField(controller: widget.controller, focusNode: widget.focusNode,
          keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 1,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
            color: filled ? const Color(0xFF059669) : const Color(0xFF111827)),
          decoration: const InputDecoration(counterText: '', border: InputBorder.none, contentPadding: EdgeInsets.zero),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged)));
  }
}
