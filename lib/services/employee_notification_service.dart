// lib/services/employee_notification_service.dart
//
// Sends three simultaneous notifications when an employee is added:
//   1. In-app    → /notifications Firestore doc (visible in the app notification page)
//   2. Email     → EmailJS API (free, sends from your Gmail, no domain needed)
//   3. WhatsApp  → opens WhatsApp via wa.me with pre-filled message
//
// EmailJS setup:
//   1. Sign up free at https://www.emailjs.com
//   2. Add Email Service → connect your Gmail → copy the Service ID
//   3. Create Email Template → copy the Template ID
//   4. Go to Account → copy your Public Key
//   5. Fill in the three constants below

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class EmployeeNotificationService {
  static final EmployeeNotificationService _i =
      EmployeeNotificationService._internal();
  factory EmployeeNotificationService() => _i;
  EmployeeNotificationService._internal();

  final _db = FirebaseFirestore.instance;

  // ─── EmailJS credentials — fill these in after setup ─────────────────────
  // Step-by-step instructions are in the README / setup guide below
  static const _emailjsServiceId  = 'service_pvzpnen';
  static const _emailjsTemplateId = 'template_hmydmng';
  static const _emailjsPublicKey  = '4WOk5Up1oiLcU8UGH4';
  // ─────────────────────────────────────────────────────────────────────────

  static const _appName = 'Laundrify';

  /// Fires all three notification channels concurrently.
  /// Returns { inApp, email, whatsapp } success flags.
  Future<Map<String, bool>> notifyNewEmployee({
    required BuildContext context,
    required String name,
    required String email,
    required String phone,
    required String role,
    required String employeeId,
    String tempPassword = '',
  }) async {
    final results = await Future.wait([
      _sendInAppNotification(
          name: name, email: email, role: role, employeeId: employeeId),
      _sendEmailViaEmailJS(
          name: name, email: email, phone: phone, role: role, employeeId: employeeId,
          extraParams: {
            'message': 'Welcome to Laundrify! You have been added as a ${_roleLabel(role)}.\n\nTo access your dashboard:\n1. Open the Laundrify app\n2. Tap "Continue with Google"\n3. Sign in with this email: $email\n\nYour dashboard will open automatically after sign-in.',
          }),
      _openWhatsApp(name: name, phone: phone, role: role, employeeId: employeeId),
    ]);
    return {'inApp': results[0], 'email': results[1], 'whatsapp': results[2]};
  }

  // ─── 1. In-App Notification ──────────────────────────────────────────────

  Future<bool> _sendInAppNotification({
    required String name,
    required String email,
    required String role,
    required String employeeId,
  }) async {
    try {
      // Search correct role collection for the employee uid
      final roleCollection = {
        'delivery': 'delivery_agents',
        'manager':  'managers',
        'staff':    'staff',
      }[role] ?? 'users';

      String? userId;
      try {
        final snap = await _db
            .collection(roleCollection)
            .where('email', isEqualTo: email.trim().toLowerCase())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) userId = snap.docs.first.id;
      } catch (_) {}

      final roleLabel = _roleLabel(role);
      final welcomeMessages = {
        'delivery': 'Hi $name! 🚴 You are now a Delivery Agent on $_appName. Accept orders and start earning. Welcome aboard!',
        'manager':  'Hi $name! 👔 You have been added as a Manager on $_appName. You can now oversee operations and manage your team.',
        'staff':    'Hi $name! 👕 Welcome to the $_appName staff team! You will be handling laundry processing. Let\'s get started!',
        'admin':    'Hi $name! 🛡️ You now have admin access to $_appName. You can manage all users, orders and settings.',
      };
      final welcomeBody = welcomeMessages[role] ??
          'Hi $name, you have been added as a $roleLabel (ID: $employeeId). Sign in to access your dashboard.';

      final notifData = <String, dynamic>{
        'title': '🎉 Welcome to $_appName, $name!',
        'body': welcomeBody,
        'message': welcomeBody,
        'type': 'employee_welcome',
        'role': role,
        'employeeId': employeeId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (userId != null) {
        notifData['userId'] = userId;
      } else {
        notifData['pendingEmail'] = email.trim().toLowerCase();
        notifData['targetGroup']  = 'pending_employee';
      }

      await _db.collection('notifications').add(notifData);
      return true;
    } catch (e) {
      debugPrint('EmployeeNotificationService._sendInAppNotification: $e');
      return false;
    }
  }

  // ─── 2. Email via EmailJS ────────────────────────────────────────────────
  //
  // EmailJS sends email directly from Flutter using your Gmail (or any email).
  // Free plan: 200 emails/month. No domain, no backend, no extra packages.
  //
  // Template variables used (set these up in your EmailJS template):
  //   {{to_email}}     - recipient email
  //   {{to_name}}      - employee name
  //   {{role}}         - employee role
  //   {{employee_id}}  - employee ID
  //   {{phone}}        - employee phone
  //   {{app_name}}     - app name

  Future<bool> _sendEmailViaEmailJS({
    required String name,
    required String email,
    required String phone,
    required String role,
    required String employeeId,
    String? subject,
    Map<String, dynamic>? extraParams,
  }) async {
    if (_emailjsServiceId == 'YOUR_SERVICE_ID' ||
        _emailjsTemplateId == 'YOUR_TEMPLATE_ID' ||
        _emailjsPublicKey == 'YOUR_PUBLIC_KEY') {
      debugPrint('EmployeeNotificationService: EmailJS credentials not set — skipping email');
      return false;
    }

    try {
      final roleLabel = _roleLabel(role);

      debugPrint('EmployeeNotificationService: sending email to \$email via EmailJS...');

      final templateParams = <String, dynamic>{
        'to_email':    email,
        'to_name':     name,
        'role':        roleLabel,
        'employee_id': employeeId,
        'phone':       phone.isNotEmpty ? phone : 'N/A',
        'app_name':    _appName,
        if (subject != null) 'subject': subject,
        ...?extraParams,
      };

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id':  _emailjsServiceId,
          'template_id': _emailjsTemplateId,
          'user_id':     _emailjsPublicKey,
          'template_params': templateParams,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('EmployeeNotificationService: ✅ email sent to \$email');
        return true;
      } else {
        debugPrint('EmployeeNotificationService: ❌ EmailJS HTTP \${response.statusCode}');
        debugPrint('  Response: \${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('EmployeeNotificationService: EmailJS request timed out');
      return false;
    } catch (e) {
      debugPrint('EmployeeNotificationService._sendEmailViaEmailJS: \$e');
      return false;
    }
  }

  // ─── 3. WhatsApp via wa.me ───────────────────────────────────────────────

  Future<bool> _openWhatsApp({
    required String name,
    required String phone,
    required String role,
    required String employeeId,
  }) async {
    try {
      final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleaned.isEmpty) return false;

      final intlPhone = cleaned.startsWith('+')
          ? cleaned
          : cleaned.startsWith('91') && cleaned.length >= 12
              ? '+$cleaned'
              : '+91$cleaned';

      final roleLabel = _roleLabel(role);
      final message = Uri.encodeComponent(
        'Hi $name! 👋\n\n'
        'Welcome to *$_appName*! 🎉\n\n'
        'You have been added as a *$roleLabel* to our team.\n\n'
        '📋 *Your Details:*\n'
        '• Employee ID: *$employeeId*\n'
        '• Role: *$roleLabel*\n\n'
        '📱 Open the $_appName app and tap "Continue with Google" '
        'to sign in with your registered email. '
        'You will be taken straight to your dashboard.\n\n'
        'Welcome aboard! 🚀',
      );

      // Try WhatsApp direct first, fall back to wa.me web link
      final waUri = Uri.parse('whatsapp://send?phone=$intlPhone&text=$message');
      final webUri = Uri.parse('https://wa.me/$intlPhone?text=$message');

      if (!kIsWeb && await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return true;
      }
      // Fallback: open wa.me in browser (works on web + when WhatsApp not installed)
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return true;
    } catch (e) {
      debugPrint('EmployeeNotificationService._openWhatsApp: $e');
      return false;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'delivery': return 'Delivery Agent';
      case 'manager':  return 'Manager';
      case 'staff':    return 'Staff Member';
      case 'admin':    return 'Administrator';
      default: return role[0].toUpperCase() + role.substring(1);
    }
  }
  // ═══════════════════════════════════════════════════════════════════════
  // CUSTOMER WELCOME EMAIL
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> notifyNewCustomer({
    required String name,
    required String email,
  }) async {
    final results = await Future.wait([
      _sendInAppWelcome(name: name, email: email),
      _sendEmailViaEmailJS(
        name: name,
        email: email,
        phone: '',
        role: 'customer',
        employeeId: '',
        subject: 'Welcome to Laundrify! 🎉',
        extraParams: {
          'message': 'Thank you for joining Laundrify! Enjoy our premium laundry services at your doorstep.',
          'cta_text': 'Start ordering now',
        },
      ),
    ]);
    return results.any((r) => r);
  }

  Future<bool> _sendInAppWelcome({
    required String name,
    required String email,
  }) async {
    try {
      final snap = await _db.collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1).get();
      if (snap.docs.isEmpty) return false;
      final uid = snap.docs.first.id;
      final body = 'Hi \$name! Welcome to \$_appName. Start your first order and get laundry done hassle-free!';
      await _db.collection('notifications').add({
        'userId': uid,
        'title': '👋 Welcome to \$_appName!',
        'message': body,
        'body': body,
        'type': 'welcome',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) { return false; }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ORDER CONFIRMATION EMAIL
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> sendOrderConfirmationEmail({
    required String name,
    required String email,
    required String orderId,
    required double amount,
    required String pickupDate,
    required String paymentMethod,
  }) async {
    return _sendEmailViaEmailJS(
      name: name,
      email: email,
      phone: '',
      role: '',
      employeeId: orderId,
      subject: 'Order Confirmed #\${orderId.substring(0, 6).toUpperCase()} 📦',
      extraParams: {
        'message': 'Your order #\${orderId.substring(0, 6).toUpperCase()} has been placed successfully!',
        'order_id': orderId.substring(0, 6).toUpperCase(),
        'amount': '₹\${amount.toStringAsFixed(0)}',
        'pickup_date': pickupDate,
        'payment_method': paymentMethod == 'cod' ? 'Cash on Delivery' : 'Online Payment',
        'cta_text': 'Track your order',
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ORDER STATUS UPDATE EMAIL
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> sendOrderStatusEmail({
    required String name,
    required String email,
    required String orderId,
    required String newStatus,
  }) async {
    final statusLabel = _statusLabel(newStatus);
    return _sendEmailViaEmailJS(
      name: name,
      email: email,
      phone: '',
      role: '',
      employeeId: orderId,
      subject: 'Order #\${orderId.substring(0, 6).toUpperCase()} — \$statusLabel',
      extraParams: {
        'message': 'Your order #\${orderId.substring(0, 6).toUpperCase()} is now \$statusLabel.',
        'order_id': orderId.substring(0, 6).toUpperCase(),
        'status': statusLabel,
        'cta_text': 'Track your order',
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ORDER CANCELLED EMAIL
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> sendOrderCancelledEmail({
    required String name,
    required String email,
    required String orderId,
    required double refundAmount,
    required String refundMethod,
  }) async {
    return _sendEmailViaEmailJS(
      name: name,
      email: email,
      phone: '',
      role: '',
      employeeId: orderId,
      subject: 'Order #\${orderId.substring(0, 6).toUpperCase()} Cancelled',
      extraParams: {
        'message': 'Your order has been cancelled. Refund of ₹\${refundAmount.toStringAsFixed(0)} will be processed via \$refundMethod.',
        'order_id': orderId.substring(0, 6).toUpperCase(),
        'refund_amount': '₹\${refundAmount.toStringAsFixed(0)}',
        'refund_method': refundMethod,
        'cta_text': 'View order history',
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ROLE CHANGED EMAIL
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> sendRoleChangedEmail({
    required String name,
    required String email,
    required String newRole,
  }) async {
    final roleLabel = _roleLabel(newRole);
    return _sendEmailViaEmailJS(
      name: name,
      email: email,
      phone: '',
      role: newRole,
      employeeId: '',
      subject: 'Your role has been updated — $_appName',
      extraParams: {
        'message': 'Hi $name, your role has been updated to $roleLabel. Please sign out and sign back in to access your new dashboard.',
        'cta_text': 'Sign in now',
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OTP VIA EMAIL (fallback when SMS doesn't work — perfect for demo)
  // ═══════════════════════════════════════════════════════════════════════
  Future<bool> sendOtpEmail({
    required String email,
    required String name,
    required String otp,
  }) async {
    return _sendEmailViaEmailJS(
      name: name,
      email: email,
      phone: '',
      role: '',
      employeeId: '',
      subject: 'Your Laundrify OTP: \$otp',
      extraParams: {
        'message': 'Your OTP for Laundrify login is: \$otp\n\nThis OTP is valid for 10 minutes. Do not share it with anyone.',
        'otp': otp,
        'cta_text': 'Use this OTP to login',
      },
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':          return 'Pending';
      case 'assigned':         return 'Assigned to Driver';
      case 'pickup':           return 'Out for Pickup';
      case 'picked':           return 'Picked Up';
      case 'processing':       return 'Being Processed';
      case 'ready':            return 'Ready for Delivery';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered':        return 'Delivered ✅';
      case 'completed':        return 'Completed ✅';
      case 'cancelled':        return 'Cancelled';
      default: return status;
    }
  }
}
