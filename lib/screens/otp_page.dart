import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_redirect_page.dart';
import '../services/firestore_service.dart';

class OtpPage extends StatefulWidget {
  final String phone;
  final String name;
  final String email;
  final String password;
  final bool isPhoneUpdate; // true when called from profile to update phone

  const OtpPage({
    super.key,
    required this.phone,
    this.name = '',
    required this.email,
    required this.password,
    this.isPhoneUpdate = false,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSnack('💡 Demo Mode: Enter any 6 digits', isError: false);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  String get _fullOtp => _controllers.map((c) => c.text).join();

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
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    setState(() {});
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _verifyOtp() async {
    final otp = _fullOtp;
    if (otp.length != _otpLength) {
      _showSnack('Please enter all 6 digits', isError: true);
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showSnack('Please enter only numbers', isError: true);
      return;
    }

    setState(() => isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1500));

      // ── Phone update mode (called from profile) ──────────────────
      if (widget.isPhoneUpdate) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _firestore.collection('users').doc(currentUser.uid).update({
            'phone': widget.phone,
            'phoneVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          _showSnack('✅ Phone number updated!', isError: false);
          await Future.delayed(const Duration(milliseconds: 500));
          if (!mounted) return;
          Navigator.pop(context); // return to profile
        }
        return;
      }

      // ── Normal signup/login flow ─────────────────────────────────
      UserCredential? userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: widget.password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );
        } else {
          rethrow;
        }
      }

      final user = userCredential.user;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'name': widget.name.isEmpty ? 'User' : widget.name,
            'email': widget.email,
            'phone': widget.phone,
            'phoneVerified': true,
            'emailVerified': false,
            'role': 'user',
            'isBlocked': false,
            'isActive': true,
            'totalOrders': 0,
            'totalSpent': 0.0,
            'createdAt': FieldValue.serverTimestamp(),
            'authMethod': 'phone_demo',
          });
          if (widget.name.isNotEmpty) {
            await user.updateDisplayName(widget.name);
          }
          try {
            await FirestoreService().sendAccountCreatedNotification();
          } catch (_) {}
        } else {
          await _firestore.collection('users').doc(user.uid).update({
            'phone': widget.phone,
            'phoneVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        if (!mounted) return;
        _showSnack('✅ Verification successful!', isError: false);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const RoleRedirectPage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Verification failed. Please try again.';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Email already in use. Try logging in instead.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak.';
        }
        _showSnack(errorMessage, isError: true);
        _clearAll();
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Verification failed. Please try again.', isError: true);
        _clearAll();
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => isLoading = false);
    if (mounted) {
      _showSnack('✅ OTP resent successfully!', isError: false);
      _clearAll();
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF080F1E), Color(0xFF0D1F3C), Color(0xFF0D2D6B)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    const SizedBox(height: 40),

                    // Lock icon
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF1B4FD8).withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      widget.isPhoneUpdate
                          ? 'Verify Phone Number'
                          : 'Verify Your Number',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the 6-digit code sent to',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.phone,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF5C518),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Change',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.55),
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Demo badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5C518).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF5C518).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFFF5C518), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Demo Mode: Enter any 6 digits',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // White card with OTP boxes
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(
                              6,
                              (i) => _OtpDigitBox(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                onChanged: (v) => _onDigitChanged(i, v),
                                onBackspace: () {
                                  if (_controllers[i].text.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                    _controllers[i - 1].clear();
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _verifyOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF080F1E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'VERIFY & CONTINUE',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 18),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Resend
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code?",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: isLoading ? null : _resendOtp,
                            child: Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: isLoading
                                    ? Colors.grey
                                    : const Color(0xFFF5C518),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'OTP is valid for 10 minutes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpDigitBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpDigitBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  State<_OtpDigitBox> createState() => _OtpDigitBoxState();
}

class _OtpDigitBoxState extends State<_OtpDigitBox> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        color: _isFocused
            ? const Color(0xFF080F1E).withValues(alpha: 0.06)
            : hasValue
                ? const Color(0xFF10B981).withValues(alpha: 0.07)
                : const Color(0xFFF4F7FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused
              ? const Color(0xFF080F1E)
              : hasValue
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade300,
          width: _isFocused || hasValue ? 2 : 1.5,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFF080F1E).withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            if (widget.controller.text.isEmpty) widget.onBackspace();
          }
        },
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: hasValue ? const Color(0xFF080F1E) : Colors.grey.shade700,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
