import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin/admin_dashboard.dart';
import 'manager_dashboard.dart';
import 'delivery_dashboard.dart';
import 'employee_dashboard.dart';
import 'dashboard.dart';

// ═══════════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD SWITCHER
//
// ADMIN gets full access to ALL 5 dashboards:
//   Admin | Manager | Delivery | Employee | User
//
// All other roles go directly to their own dashboard only.
// ═══════════════════════════════════════════════════════════════════════

const _navy  = Color(0xFF080F1E);
const _navyM = Color(0xFF0D1A2E);
const _navyC = Color(0xFF111F35);
const _navyB = Color(0xFF1C2F4A);
const _gold  = Color(0xFFF5C518);
const _goldS = Color(0xFFFDE68A);
const _textHi= Color(0xFFF1F5F9);
const _textMd= Color(0xFF94A3B8);
const _textDm= Color(0xFF475569);

class AdminSwitcherWrapper extends StatefulWidget {
  const AdminSwitcherWrapper({super.key});
  @override State<AdminSwitcherWrapper> createState() => _AdminSwitcherWrapperState();
}

class _AdminSwitcherWrapperState extends State<AdminSwitcherWrapper>
    with SingleTickerProviderStateMixin {
  String _view     = 'admin';
  bool   _isAdmin  = false;
  bool   _checking = true;
  late AnimationController _barCtrl;
  late Animation<double>   _barFade;

  // ── All 5 dashboards available to admin ──────────────────────
  static const _views = [
    _ViewRole('admin',    Icons.admin_panel_settings_rounded, 'Admin',    'Full admin control panel'),
    _ViewRole('manager',  Icons.manage_accounts_rounded,      'Manager',  'Branch manager view'),
    _ViewRole('delivery', Icons.delivery_dining_rounded,      'Delivery', 'Delivery driver view'),
    _ViewRole('employee', Icons.badge_rounded,                'Employee', 'Laundry staff view'),
    _ViewRole('user',     Icons.person_rounded,               'User',     'Customer app view'),
  ];

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _barFade = CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut);
    _checkRole();
  }

  @override void dispose() { _barCtrl.dispose(); super.dispose(); }

  Future<void> _checkRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _checking = false); return; }
    try {
      final doc  = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = doc.data()?['role'] ?? 'user';
      if (mounted) {
        setState(() { _isAdmin = role == 'admin'; _checking = false; });
        if (_isAdmin) _barCtrl.forward();
      }
    } catch (_) { if (mounted) setState(() => _checking = false); }
  }

  void _openSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SwitcherSheet(
        current: _view,
        views: _views,
        onPick: (role) { setState(() => _view = role); Navigator.pop(context); },
      ),
    );
  }

  Widget _buildDashboard() {
    switch (_view) {
      case 'admin':    return const AdminDashboard();
      case 'manager':  return const ManagerDashboard();
      case 'delivery': return const DeliveryDashboard();
      case 'employee': return const EmployeeDashboard();
      case 'user':     return const DashboardPage();
      default:         return const AdminDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2.5)),
      );
    }
    // Not admin — show admin dashboard directly
    if (!_isAdmin) return const AdminDashboard();

    final currentView = _views.firstWhere((v) => v.role == _view);

    return Stack(children: [
      _buildDashboard(),

      // ── Admin switcher bar ──────────────────────────────────
      Positioned(
        top: 0, left: 0, right: 0,
        child: FadeTransition(
          opacity: _barFade,
          child: SafeArea(
            bottom: false,
            child: GestureDetector(
              onTap: _openSwitcher,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D1A2E), Color(0xFF111F35)]),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _gold.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _gold.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 3)),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8),
                  ],
                ),
                child: Row(children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_gold, _goldS]),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.4), blurRadius: 6)],
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: _navy),
                  ),
                  const SizedBox(width: 8),
                  const Text('ADMIN VIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _gold, letterSpacing: 1.2)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 16, color: _navyB),
                  const SizedBox(width: 8),
                  Icon(currentView.icon, color: _textMd, size: 14),
                  const SizedBox(width: 5),
                  Text(currentView.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textHi)),
                  const Spacer(),
                  const Icon(Icons.swap_horiz_rounded, color: _textMd, size: 16),
                  const SizedBox(width: 4),
                  const Text('Switch', style: TextStyle(fontSize: 11, color: _textMd, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ViewRole {
  final String role, label, sub;
  final IconData icon;
  const _ViewRole(this.role, this.icon, this.label, this.sub);
}

class _SwitcherSheet extends StatelessWidget {
  final String current;
  final List<_ViewRole> views;
  final ValueChanged<String> onPick;
  const _SwitcherSheet({required this.current, required this.views, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _navyM,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: _navyB)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: _navyB, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_gold, _goldS]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: _gold.withValues(alpha: 0.35), blurRadius: 8)],
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: _navy, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Switch Dashboard View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _textHi)),
            Text('Admin exclusive • Access all 5 dashboards', style: TextStyle(fontSize: 11, color: _textMd)),
          ]),
        ]),
        const SizedBox(height: 6),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, _gold.withValues(alpha: 0.5), Colors.transparent]),
          ),
        ),
        ...views.map((v) {
          final isCurrent = v.role == current;
          return GestureDetector(
            onTap: () => onPick(v.role),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isCurrent ? _gold.withValues(alpha: 0.1) : _navyC,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isCurrent ? _gold.withValues(alpha: 0.5) : _navyB, width: isCurrent ? 1.5 : 1),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: isCurrent ? _gold.withValues(alpha: 0.15) : _navyM,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? _gold.withValues(alpha: 0.4) : _navyB),
                  ),
                  child: Icon(v.icon, color: isCurrent ? _gold : _textMd, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isCurrent ? _gold : _textHi)),
                  Text(v.sub, style: const TextStyle(fontSize: 11, color: _textMd)),
                ])),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_gold, _goldS]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Current', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _navy)),
                  )
                else
                  const Icon(Icons.chevron_right_rounded, color: _textDm, size: 20),
              ]),
            ),
          );
        }),

        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: _gold, size: 15),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Admin-exclusive. You have full access to all 5 dashboards. Other roles see only their own.',
              style: TextStyle(fontSize: 10, color: _textMd, height: 1.4),
            )),
          ]),
        ),
      ]),
    );
  }
}
