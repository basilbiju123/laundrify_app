import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/orders_page.dart';
import '../screens/order_history_page.dart';
import '../screens/loyalty_page.dart';
import '../screens/profile_page.dart';
import '../screens/help_page.dart';
import '../screens/settings_page.dart';
import '../screens/auth_options_page.dart';
import '../screens/notifications_page.dart';
import '../screens/abandoned_cart_page.dart';
import '../services/panel_theme_service.dart';

bool get isWindowsDesktop {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.windows;
}

// ─── InheritedWidget marker ───────────────────────────────────────────────
// Placed above every page rendered by the shell so sub-pages can detect
// they are already inside the shell and skip their own WindowsLayout wrap.
class _WindowsShellScope extends InheritedWidget {
  const _WindowsShellScope({required super.child});
  @override
  bool updateShouldNotify(_WindowsShellScope _) => false;
}

// ─── Public helper ────────────────────────────────────────────────────────
abstract class WindowsShell {
  /// Returns true when this widget is rendered inside the WindowsShell.
  /// Use this in pages that self-wrap with WindowsLayout to avoid double sidebar.
  static bool isInsideShell(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_WindowsShellScope>() != null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class WindowsLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final String currentRoute;
  final List<NavItem>? extraActions;

  const WindowsLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentRoute,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWindowsDesktop) return child;
    return PanelThemeScope(
      panelKey: 'user',
      child: _WindowsShellWidget(
        title: title,
        currentRoute: currentRoute,
        dashboardHome: child,
      ),
    );
  }
}

class NavItem {
  final String label;
  final IconData icon;
  final String route;
  final Color? color;
  const NavItem(this.label, this.icon, this.route, {this.color});
}

// ─────────────────────────────────────────────────────────────────────────────
// Shell state
// BLACK SCREEN FIX: all sidebar pages are rendered inline as widgets.
// No Navigator.push() is used for sidebar navigation — selecting a nav item
// just calls setState(_activeIndex = i) which swaps the child widget.
// Each rendered page is wrapped in _WindowsShellScope so it can detect it's
// inside the shell and skip its own WindowsLayout wrapper.
// ─────────────────────────────────────────────────────────────────────────────
class _WindowsShellWidget extends StatefulWidget {
  final Widget dashboardHome;
  final String title;
  final String currentRoute;
  const _WindowsShellWidget({
    required this.dashboardHome,
    required this.title,
    required this.currentRoute,
  });

  @override
  State<_WindowsShellWidget> createState() => _WindowsShellWidgetState();
}

class _WindowsShellWidgetState extends State<_WindowsShellWidget> {
  bool _sidebarExpanded = true;
  int _activeIndex = 0;

  static const _navy     = Color(0xFF080F1E);
  static const _navyMid  = Color(0xFF0D1F3C);
  static const _gold     = Color(0xFFF5C518);
  static const _goldSoft = Color(0xFFFDE68A);

  static const List<NavItem> _navItems = [
    NavItem('Dashboard',     Icons.home_rounded,           '/dashboard'),
    NavItem('My Orders',     Icons.receipt_long_rounded,   '/orders'),
    NavItem('Order History', Icons.history_rounded,        '/order-history'),
    NavItem('Loyalty',       Icons.stars_rounded,          '/loyalty'),
    NavItem('Profile',       Icons.person_rounded,         '/profile'),
    NavItem('Help',          Icons.help_outline_rounded,   '/help'),
    NavItem('Settings',      Icons.settings_rounded,       '/settings'),
  ];

  @override
  void initState() {
    super.initState();
    final idx = _navItems.indexWhere((n) => n.route == widget.currentRoute);
    _activeIndex = idx < 0 ? 0 : idx;
  }

  /// Each page is wrapped in _WindowsShellScope so it knows it's inside the shell.
  Widget _pageForIndex(int index) {
    Widget page;
    switch (index) {
      case 0:  page = widget.dashboardHome; break;
      case 1:  page = const OrdersPage(); break;
      case 2:  page = const OrderHistoryPage(); break;
      case 3:  page = const LoyaltyPage(); break;
      case 4:  page = const ProfilePage(); break;
      case 5:  page = const HelpPage(); break;
      case 6:  page = const SettingsPage(); break;
      default: page = widget.dashboardHome;
    }
    return _WindowsShellScope(child: page);
  }

  @override
  Widget build(BuildContext context) {
    final panelTheme = PanelThemeScope.of(context);
    final isDark = panelTheme.isDark;

    final bgColor   = isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F4FF);
    final sidebarBg = isDark ? const Color(0xFF050D1A) : _navy;
    final sidebar2  = isDark ? const Color(0xFF081526) : _navyMid;

    final user        = FirebaseAuth.instance.currentUser;
    final sidebarW    = _sidebarExpanded ? 240.0 : 68.0;
    final displayName = user?.displayName ?? user?.email?.split('@').first ?? 'User';
    final initials    = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          // ── SIDEBAR ─────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: sidebarW,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [sidebarBg, sidebar2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _navy.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo + toggle
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                  child: Row(
                    mainAxisAlignment: _sidebarExpanded
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      if (_sidebarExpanded)
                        const Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text(
                            'Laundrify',
                            style: TextStyle(
                              color: _gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      IconButton(
                        icon: Icon(
                          _sidebarExpanded
                              ? Icons.menu_open_rounded
                              : Icons.menu_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => setState(
                            () => _sidebarExpanded = !_sidebarExpanded),
                      ),
                    ],
                  ),
                ),

                // User card
                if (_sidebarExpanded && user != null) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _gold.withValues(alpha: 0.2),
                          child: Text(initials,
                              style: const TextStyle(
                                  color: _gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              Text(user.email ?? '',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 10),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!_sidebarExpanded && user != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: _gold.withValues(alpha: 0.2),
                      child: Text(initials,
                          style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
                  ),
                ],

                // Nav items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: List.generate(_navItems.length, (i) {
                      return _NavTile(
                        item: _navItems[i],
                        isActive: _activeIndex == i,
                        expanded: _sidebarExpanded,
                        onTap: () => setState(() => _activeIndex = i),
                      );
                    }),
                  ),
                ),

                // Dark mode toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _DarkToggleTile(
                    expanded: _sidebarExpanded,
                    isDark: isDark,
                    onToggle: () => panelTheme.toggle(),
                  ),
                ),

                // Sign out
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      8, 4, 8, MediaQuery.of(context).padding.bottom + 16),
                  child: _NavTile(
                    item: const NavItem('Sign Out', Icons.logout_rounded,
                        '/logout', color: Color(0xFFEF4444)),
                    isActive: false,
                    expanded: _sidebarExpanded,
                    onTap: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          title: const Text('Sign Out',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                          content: const Text(
                              'Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Sign Out',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const AuthOptionsPage()),
                            (r) => false,
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── MAIN CONTENT ─────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  user: user,
                  displayName: displayName,
                  initials: initials,
                  gold: _gold,
                  goldSoft: _goldSoft,
                  navy: _navy,
                  isDark: isDark,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_activeIndex),
                      child: _pageForIndex(_activeIndex),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dark Mode Toggle Tile ──────────────────────────────────────────────────
class _DarkToggleTile extends StatelessWidget {
  final bool expanded;
  final bool isDark;
  final VoidCallback onToggle;
  const _DarkToggleTile(
      {required this.expanded, required this.isDark, required this.onToggle});
  static const _gold = Color(0xFFF5C518);

  @override
  Widget build(BuildContext context) {
    final icon = isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final clr  = isDark ? _gold : Colors.white60;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 0, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: expanded
            ? Row(children: [
                Icon(icon, color: clr, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isDark ? 'Light Mode' : 'Dark Mode',
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Switch(
                  value: isDark,
                  onChanged: (_) => onToggle(),
                  activeThumbColor: _gold,
                  activeTrackColor: _gold.withValues(alpha: 0.3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ])
            : Center(child: Icon(icon, color: clr, size: 20)),
      ),
    );
  }
}

// ── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final User? user;
  final String displayName;
  final String initials;
  final Color gold, goldSoft, navy;
  final bool isDark;
  const _TopBar(
      {required this.user,
      required this.displayName,
      required this.initials,
      required this.gold,
      required this.goldSoft,
      required this.navy,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final barBg  = isDark ? const Color(0xFF111827) : Colors.white;
    final iconClr = isDark ? Colors.white70 : navy;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: navy,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                        Icons.local_laundry_service_rounded,
                        color: gold, size: 18)),
            ),
          ),
          const SizedBox(width: 10),
          const Spacer(),

          // Abandoned cart badge
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('abandoned_carts')
                  .where('status', isEqualTo: 'abandoned')
                  .snapshots(),
              builder: (ctx, snap) {
                final count = snap.data?.docs.length ?? 0;
                if (count == 0) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Abandoned Cart',
                  icon: Stack(clipBehavior: Clip.none, children: [
                    Icon(Icons.shopping_cart_outlined, color: iconClr, size: 22),
                    Positioned(
                      right: -3, top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Color(0xFFEF4444), shape: BoxShape.circle),
                        child: Text('$count',
                            style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                    ),
                  ]),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const AbandonedCartPage())),
                );
              },
            ),

          // Notification bell
          if (user != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('notifications')
                  .snapshots(),
              builder: (ctx, snap) {
                final unread = snap.data?.docs
                        .where((d) => (d.data() as Map)['isRead'] != true)
                        .length ??
                    0;
                return IconButton(
                  tooltip: 'Notifications',
                  icon: Stack(clipBehavior: Clip.none, children: [
                    Icon(Icons.notifications_outlined, color: iconClr, size: 23),
                    if (unread > 0)
                      Positioned(
                        right: -3, top: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                              color: Color(0xFFEF4444), shape: BoxShape.circle),
                          child: Text('$unread',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                  ]),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsPage())),
                );
              },
            )
          else
            IconButton(
              tooltip: 'Notifications',
              icon: Icon(Icons.notifications_outlined, color: iconClr, size: 23),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage())),
            ),

          const SizedBox(width: 6),

          // Avatar
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gold, goldSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gold.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Center(
              child: Text(initials,
                  style: TextStyle(
                      color: navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ── Nav Tile ───────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool isActive, expanded;
  final VoidCallback onTap;
  const _NavTile(
      {required this.item,
      required this.isActive,
      required this.expanded,
      required this.onTap});
  static const _gold = Color(0xFFF5C518);

  @override
  Widget build(BuildContext context) {
    final clr = item.color ?? (isActive ? Colors.white : Colors.white60);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(
            horizontal: expanded ? 14 : 0, vertical: 11),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: expanded
            ? Row(children: [
                Icon(item.icon,
                    color: isActive ? _gold : clr, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      style: TextStyle(
                          color: clr,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w500,
                          fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                ),
                if (isActive)
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: _gold, shape: BoxShape.circle)),
              ])
            : Center(
                child: Icon(item.icon,
                    color: isActive ? _gold : clr, size: 20)),
      ),
    );
  }
}
