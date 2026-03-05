import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════
// LAUNDRIFY UNIFIED THEME — White UI matching User Dashboard
// Clean white surfaces  |  Navy #080F1E  |  Gold #F5C518
// Used across Manager, Delivery, Employee dashboards
// ═══════════════════════════════════════════════════════════════════

class LTheme {
  // ── Core Palette — White UI ────────────────────────────────────
  static const Color bg       = Color(0xFFF0F4FF);   // light surface
  static const Color surface  = Color(0xFFF8FAFF);   // almost white
  static const Color card     = Color(0xFFFFFFFF);   // pure white card
  static const Color cardBdr  = Color(0xFFE8EDF5);   // subtle border

  // Brand — unchanged
  static const Color navy     = Color(0xFF080F1E);
  static const Color navyMid  = Color(0xFF0D1F3C);
  static const Color gold     = Color(0xFFF5C518);
  static const Color goldSoft = Color(0xFFFDE68A);
  static const Color goldDim  = Color(0xFF7A6210);

  static const Color blue     = Color(0xFF1B4FD8);
  static const Color blueSoft = Color(0xFF3B82F6);
  static const Color blueGlow = Color(0xFF60A5FA);

  static const Color emerald  = Color(0xFF10B981);
  static const Color amber    = Color(0xFFF59E0B);
  static const Color rose     = Color(0xFFEF4444);
  static const Color violet   = Color(0xFF8B5CF6);
  static const Color cyan     = Color(0xFF06B6D4);

  // Text — dark on white
  static const Color textHi   = Color(0xFF0A1628);
  static const Color textMid  = Color(0xFF475569);
  static const Color textDim  = Color(0xFF94A3B8);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldSoft, gold],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient blueGradient = LinearGradient(
    colors: [blue, blueSoft],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  // Header gradient stays dark navy for brand identity
  static const LinearGradient headerGradient = LinearGradient(
    colors: [navy, navyMid],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Decorations ───────────────────────────────────────────────
  static BoxDecoration cardBox({Color? borderColor, bool glow = false, bool goldGlow = false}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? cardBdr, width: borderColor != null ? 1.5 : 1),
    boxShadow: goldGlow
        ? [BoxShadow(color: gold.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0,4))]
        : glow
            ? [BoxShadow(color: blue.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0,4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0,3))],
  );

  static BoxDecoration goldBadge() => BoxDecoration(
    gradient: goldGradient,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0,3))],
  );

  // ── Text Styles ───────────────────────────────────────────────
  static TextStyle heading(double size, {Color? color}) => TextStyle(
    fontSize: size, fontWeight: FontWeight.w900, color: color ?? textHi, letterSpacing: -0.5,
  );
  static TextStyle label(double size) => TextStyle(
    fontSize: size, fontWeight: FontWeight.w600, color: textMid,
  );
  static TextStyle goldText(double size) => TextStyle(
    fontSize: size, fontWeight: FontWeight.w800, color: gold,
  );

  // ── Input Decoration ──────────────────────────────────────────
  static InputDecoration inputDec(String lbl, IconData icon) => InputDecoration(
    labelText: lbl,
    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
    filled: true, fillColor: card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBdr)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cardBdr)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 2)),
  );
}

// ── Shared Status helpers ─────────────────────────────────────────
Color lStatusColor(String s) {
  switch (s.toLowerCase()) {
    case 'pending':          return LTheme.amber;
    case 'assigned':         return LTheme.gold;
    case 'accepted':         return LTheme.blue;
    case 'pickup':           return LTheme.blueSoft;
    case 'processing':       return LTheme.violet;
    case 'reached':          return LTheme.violet;
    case 'picked':           return LTheme.cyan;
    case 'delivery':
    case 'out_for_delivery': return LTheme.amber;
    case 'delivered':
    case 'completed':        return LTheme.emerald;
    case 'cancelled':
    case 'rejected':         return LTheme.rose;
    default:                 return LTheme.textDim;
  }
}

IconData lStatusIcon(String s) {
  switch (s.toLowerCase()) {
    case 'pending':          return Icons.schedule_rounded;
    case 'assigned':         return Icons.assignment_rounded;
    case 'accepted':         return Icons.thumb_up_rounded;
    case 'pickup':           return Icons.local_shipping_outlined;
    case 'reached':          return Icons.location_on_rounded;
    case 'picked':           return Icons.local_laundry_service_rounded;
    case 'processing':       return Icons.local_laundry_service_outlined;
    case 'delivery':
    case 'out_for_delivery': return Icons.delivery_dining_rounded;
    case 'delivered':        return Icons.done_all_rounded;
    case 'completed':        return Icons.verified_rounded;
    case 'cancelled':
    case 'rejected':         return Icons.cancel_outlined;
    default:                 return Icons.circle_outlined;
  }
}

// ── Shared Widgets ────────────────────────────────────────────────

class LCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final bool goldGlow;
  final bool blueGlow;
  final VoidCallback? onTap;

  const LCard({super.key, required this.child, this.padding, this.borderColor,
      this.goldGlow = false, this.blueGlow = false, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: LTheme.cardBox(borderColor: borderColor, glow: blueGlow, goldGlow: goldGlow),
      child: child,
    ),
  );
}

class LBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const LBadge({super.key, required this.label, required this.color, this.fontSize = 10});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.4)),
  );
}

class LGoldBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  const LGoldBadge({super.key, required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [LTheme.navy, LTheme.navyMid]),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: LTheme.navy.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,2))],
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 12, color: LTheme.gold), const SizedBox(width: 4)],
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
    ]),
  );
}

class LStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const LStatCard({super.key, required this.label, required this.value,
      required this.icon, required this.color, this.sub});
  @override
  Widget build(BuildContext context) => LCard(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        Container(width:32, height:32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.06), shape: BoxShape.circle),
          child: Icon(Icons.trending_up_rounded, color: color.withValues(alpha: 0.5), size: 14)),
      ]),
      const SizedBox(height: 14),
      Text(value, style: LTheme.heading(24)),
      const SizedBox(height: 3),
      Text(label, style: LTheme.label(12)),
      if (sub != null) ...[const SizedBox(height: 2),
        Text(sub!, style: TextStyle(fontSize: 10, color: LTheme.textDim, fontWeight: FontWeight.w500))],
    ]),
  );
}

class LPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  const LPageHeader({super.key, required this.title, required this.subtitle, this.action});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: LTheme.heading(22)),
      const SizedBox(height: 4),
      Text(subtitle, style: LTheme.label(13)),
    ])),
    if (action != null) action!,
  ]);
}

class LDivider extends StatelessWidget {
  const LDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 1, color: LTheme.cardBdr);
}

class LEmptyState extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  final Color? color;
  const LEmptyState({super.key, required this.title, required this.sub, required this.icon, this.color});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: (color ?? LTheme.blue).withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: (color ?? LTheme.blue).withValues(alpha: 0.2), width: 1.5),
        ),
        child: Icon(icon, color: color ?? LTheme.blue, size: 36),
      ),
      const SizedBox(height: 18),
      Text(title, style: LTheme.heading(16)),
      const SizedBox(height: 6),
      Text(sub, style: LTheme.label(13), textAlign: TextAlign.center),
    ]),
  ));
}

class LOnlineDot extends StatelessWidget {
  final bool online;
  const LOnlineDot({super.key, required this.online});
  @override
  Widget build(BuildContext context) => Container(
    width: 12, height: 12,
    decoration: BoxDecoration(
      color: online ? LTheme.emerald : LTheme.textDim,
      shape: BoxShape.circle,
      border: Border.all(color: LTheme.card, width: 2),
    ),
  );
}


// ─── DynTheme: context-aware version for pages that use LTheme / static colors ─
// Usage: final lt = DynTheme.of(context); → lt.bg, lt.card, lt.textHi …
class DynTheme {
  final bool isDark;
  const DynTheme._({required this.isDark});

  Color get bg       => isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F4FF);
  Color get surface  => isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFF);
  Color get card     => isDark ? const Color(0xFF1A2540) : Colors.white;
  Color get cardBdr  => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);
  Color get input    => isDark ? const Color(0xFF1A2540) : Colors.white;

  static const Color navy     = Color(0xFF080F1E);
  static const Color navyMid  = Color(0xFF0D1F3C);
  static const Color gold     = Color(0xFFF5C518);
  static const Color goldSoft = Color(0xFFFDE68A);
  static const Color blue     = Color(0xFF1B4FD8);
  static const Color blueSoft = Color(0xFF3B82F6);
  static const Color emerald  = Color(0xFF10B981);
  static const Color amber    = Color(0xFFF59E0B);
  static const Color rose     = Color(0xFFEF4444);
  static const Color violet   = Color(0xFF8B5CF6);
  static const Color cyan     = Color(0xFF06B6D4);

  Color get textHi  => isDark ? Colors.white            : const Color(0xFF0A1628);
  Color get textMid => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get textDim => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get divider => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);

  static const LinearGradient headerGradient = LinearGradient(
    colors: [navy, navyMid], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldSoft, gold], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  static DynTheme of(BuildContext context) =>
      DynTheme._(isDark: Theme.of(context).brightness == Brightness.dark);

  BoxDecoration cardBox({Color? borderColor, bool glow = false, bool goldGlow = false}) =>
      BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? cardBdr, width: borderColor != null ? 1.5 : 1),
        boxShadow: goldGlow
            ? [BoxShadow(color: gold.withValues(alpha: isDark ? 0.18 : 0.12), blurRadius: 16, offset: const Offset(0, 4))]
            : glow
                ? [BoxShadow(color: blue.withValues(alpha: isDark ? 0.18 : 0.12), blurRadius: 16, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 3))],
      );

  TextStyle heading(double size, {Color? color}) => TextStyle(
      fontSize: size, fontWeight: FontWeight.w900, color: color ?? textHi, letterSpacing: -0.5);
  TextStyle label(double size) =>
      TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: textMid);
}
