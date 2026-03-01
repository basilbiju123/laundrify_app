import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

/// Returns true when running on Windows desktop
bool get isWindowsDesktop {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows;
}

/// Windows-aware scaffold that adds a sidebar on Windows and uses the
/// normal mobile layout on Android/iOS.
///
/// Usage:
///   WindowsLayout(
///     title: 'Page Title',
///     currentRoute: '/dashboard',
///     child: YourMobileBody(),
///   )
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
    return _WindowsShell(
      title: title,
      currentRoute: currentRoute,
      child: child,
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

class _WindowsShell extends StatefulWidget {
  final Widget child;
  final String title;
  final String currentRoute;
  const _WindowsShell({
    required this.child,
    required this.title,
    required this.currentRoute,
  });

  @override
  State<_WindowsShell> createState() => _WindowsShellState();
}

class _WindowsShellState extends State<_WindowsShell> {
  bool _sidebarExpanded = true;

  static const _navy = Color(0xFF080F1E);
  static const _navyMid = Color(0xFF0D1F3C);
  static const _gold = Color(0xFFF5C518);
  static const _surface = Color(0xFFF0F4FF);

  static const List<NavItem> _navItems = [
    NavItem('Dashboard', Icons.home_rounded, '/dashboard'),
    NavItem('My Orders', Icons.receipt_long_rounded, '/orders'),
    NavItem('Order History', Icons.history_rounded, '/order-history'),
    NavItem('Loyalty', Icons.stars_rounded, '/loyalty'),
    NavItem('Profile', Icons.person_rounded, '/profile'),
    NavItem('Help', Icons.help_outline_rounded, '/help'),
    NavItem('Settings', Icons.settings_rounded, '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final sidebarW = _sidebarExpanded ? 240.0 : 72.0;

    return Scaffold(
      backgroundColor: _surface,
      body: Row(
        children: [
          // ── SIDEBAR ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: sidebarW,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_navy, _navyMid],
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
                // Logo + Toggle
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
                        onPressed: () =>
                            setState(() => _sidebarExpanded = !_sidebarExpanded),
                      ),
                    ],
                  ),
                ),

                // User info
                if (_sidebarExpanded && user != null) ...[
                  Container(
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: _gold.withValues(alpha: 0.2),
                          child: Text(
                            (user.displayName ?? user.email ?? 'U')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName ?? 'User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.email ?? '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
                      child: Text(
                        (user.displayName ?? user.email ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          color: _gold,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],

                // Nav Items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: _navItems.map((item) {
                      final isActive = widget.currentRoute == item.route;
                      return _NavTile(
                        item: item,
                        isActive: isActive,
                        expanded: _sidebarExpanded,
                        onTap: () => _navigate(context, item.route),
                      );
                    }).toList(),
                  ),
                ),

                // Sign out
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      8, 0, 8, MediaQuery.of(context).padding.bottom + 16),
                  child: _NavTile(
                    item: const NavItem(
                        'Sign Out', Icons.logout_rounded, '/logout',
                        color: Color(0xFFEF4444)),
                    isActive: false,
                    expanded: _sidebarExpanded,
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/auth', (r) => false);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── MAIN CONTENT ─────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: _navy,
                        ),
                      ),
                      const Spacer(),
                      // Windows breadcrumb
                      Text(
                        'Laundrify  /  ${widget.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(
                  child: widget.child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    // For now just pop back — in a full implementation, use GoRouter or named routes
    if (route == widget.currentRoute) return;
    Navigator.pop(context);
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final bool expanded;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.expanded,
    required this.onTap,
  });

  static const _gold = Color(0xFFF5C518);

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? (isActive ? Colors.white : Colors.white60);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(
          horizontal: expanded ? 14 : 12,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: isActive ? _gold : color, size: 20),
            if (expanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: color,
                    fontWeight:
                        isActive ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _gold,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
