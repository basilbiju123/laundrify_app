import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// LAUNDRIFY ADMIN THEME — supports both light and dark mode
// Dark mode is per-panel, toggled via PanelThemeScope('admin')
// ═══════════════════════════════════════════════════════════════════

class AdminTheme {
  // Core palette — Light UI (static fallbacks)
  static const Color bg          = Color(0xFFF0F4FF);
  static const Color surface     = Color(0xFFF8FAFF);
  static const Color card        = Color(0xFFFFFFFF);
  static const Color cardBorder  = Color(0xFFE8EDF5);

  // Brand — unchanged
  static const Color navy        = Color(0xFF080F1E);
  static const Color navyMid     = Color(0xFF0D1F3C);
  static const Color gold        = Color(0xFFF5C518);
  static const Color goldSoft    = Color(0xFFFDE68A);
  static const Color accent      = Color(0xFF1B4FD8);
  static const Color accentGlow  = Color(0xFF3B82F6);
  static const Color emerald     = Color(0xFF10B981);
  static const Color amber       = Color(0xFFF59E0B);
  static const Color rose        = Color(0xFFEF4444);
  static const Color violet      = Color(0xFF8B5CF6);
  static const Color cyan        = Color(0xFF06B6D4);

  // Text — dark on white
  static const Color textPrimary   = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted     = Color(0xFF94A3B8);

  static const List<Color> chartPalette = [
    Color(0xFF1B4FD8), Color(0xFFF5C518), Color(0xFF10B981),
    Color(0xFF8B5CF6), Color(0xFFEF4444), Color(0xFF06B6D4),
  ];

  static BoxDecoration cardDecoration({bool glow = false, bool goldGlow = false}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: cardBorder, width: 1),
    boxShadow: goldGlow
        ? [BoxShadow(color: gold.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0,4))]
        : glow
            ? [BoxShadow(color: accent.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0,4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,3))],
  );

  static TextStyle heading(double size) => TextStyle(
    fontSize: size, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5,
  );
  static TextStyle label(double size) => TextStyle(
    fontSize: size, fontWeight: FontWeight.w600, color: textSecondary,
  );

  static InputDecoration inputDec(String lbl, IconData icon) => InputDecoration(
    labelText: lbl,
    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
    filled: true, fillColor: card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: navy, width: 2)),
  );
}

class AdminStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final double? trend;
  const AdminStatCard({super.key, required this.title, required this.value,
      required this.icon, required this.color, this.subtitle, this.trend});

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: at.cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          if (trend != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (trend! >= 0 ? AdminTheme.emerald : AdminTheme.rose).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(trend! >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    color: trend! >= 0 ? AdminTheme.emerald : AdminTheme.rose, size: 14),
                const SizedBox(width: 4),
                Text('${trend!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: trend! >= 0 ? AdminTheme.emerald : AdminTheme.rose)),
              ]),
            ),
        ]),
        const SizedBox(height: 16),
        Text(value, style: at.heading(26)),
        const SizedBox(height: 4),
        Text(title, style: at.label(13)),
        if (subtitle != null) ...[const SizedBox(height: 4),
          Text(subtitle!, style: at.label(11).copyWith(color: at.textMuted))],
      ]),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const AdminPageHeader({super.key, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: at.heading(22)),
        const SizedBox(height: 4),
        Text(subtitle, style: at.label(13)),
      ])),
      if (action != null) action!,
    ]);
  }
}

class AdminBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const AdminBadge({super.key, required this.label, required this.color, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
  );
}

class AdminGoldBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  const AdminGoldBadge({super.key, required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AdminTheme.navy, AdminTheme.navyMid]),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AdminTheme.navy.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0,2))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 12, color: AdminTheme.gold), const SizedBox(width: 4)],
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
    ]),
  );
}

Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':          return AdminTheme.amber;
    case 'assigned':         return AdminTheme.gold;
    case 'accepted':         return AdminTheme.accent;
    case 'pickup':           return AdminTheme.accentGlow;
    case 'processing':       return AdminTheme.violet;
    case 'delivery':
    case 'out_for_delivery': return AdminTheme.amber;
    case 'delivered':
    case 'completed':        return AdminTheme.emerald;
    case 'cancelled':
    case 'rejected':         return AdminTheme.rose;
    default:                 return AdminTheme.textSecondary;
  }
}

IconData statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'pending':          return Icons.schedule_rounded;
    case 'assigned':         return Icons.assignment_rounded;
    case 'accepted':         return Icons.thumb_up_rounded;
    case 'pickup':           return Icons.local_shipping_outlined;
    case 'processing':       return Icons.local_laundry_service_outlined;
    case 'delivery':
    case 'out_for_delivery': return Icons.delivery_dining_rounded;
    case 'delivered':
    case 'completed':        return Icons.check_circle_outline_rounded;
    case 'cancelled':
    case 'rejected':         return Icons.cancel_outlined;
    default:                 return Icons.circle_outlined;
  }
}

// ─── DynAdmin: context-aware AdminTheme with full dark mode support ───────────
// Usage: final at = DynAdmin.of(context);
// Dark mode driven by PanelThemeScope('admin') wrapping the admin dashboard.
class DynAdmin {
  final bool isDark;
  const DynAdmin._({required this.isDark});

  // Surfaces
  Color get bg         => isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F4FF);
  Color get surface    => isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFF);
  Color get card       => isDark ? const Color(0xFF1A2540) : Colors.white;
  Color get cardBorder => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);
  Color get input      => isDark ? const Color(0xFF1A2540) : Colors.white;

  // Brand (static)
  static const Color navy       = Color(0xFF080F1E);
  static const Color navyMid    = Color(0xFF0D1F3C);
  static const Color gold       = Color(0xFFF5C518);
  static const Color goldSoft   = Color(0xFFFDE68A);
  static const Color accent     = Color(0xFF1B4FD8);
  static const Color accentGlow = Color(0xFF3B82F6);
  static const Color emerald    = Color(0xFF10B981);
  static const Color amber      = Color(0xFFF59E0B);
  static const Color rose       = Color(0xFFEF4444);
  static const Color violet     = Color(0xFF8B5CF6);
  static const Color cyan       = Color(0xFF06B6D4);

  // Text
  Color get textPrimary   => isDark ? Colors.white            : const Color(0xFF0A1628);
  Color get textSecondary => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get textMuted     => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get divider       => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);

  static DynAdmin of(BuildContext context) =>
      DynAdmin._(isDark: Theme.of(context).brightness == Brightness.dark);

  BoxDecoration cardDecoration({bool glow = false, bool goldGlow = false}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: cardBorder, width: 1),
    boxShadow: goldGlow
        ? [BoxShadow(color: gold.withValues(alpha: isDark ? 0.18 : 0.15), blurRadius: 16, offset: const Offset(0, 4))]
        : glow
            ? [BoxShadow(color: accent.withValues(alpha: isDark ? 0.18 : 0.12), blurRadius: 16, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
  );

  TextStyle heading(double size) => TextStyle(
      fontSize: size, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5);
  TextStyle label(double size) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: textSecondary);
}
