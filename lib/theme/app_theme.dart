import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LAUNDRIFY UNIFIED THEME
//  • Brand:  Navy #080F1E  |  Gold #F5C518  |  Blue #1B4FD8
//  • Light:  white surfaces
//  • Dark:   deep-navy surfaces
//  Usage:  final t = AppColors.of(context);  then t.bg, t.card, t.textHi …
// ═══════════════════════════════════════════════════════════════════════════

class AppColors {
  final bool isDark;
  const AppColors._({required this.isDark});

  // ── Surfaces ───────────────────────────────────────────────────
  Color get bg       => isDark ? const Color(0xFF0A1628) : const Color(0xFFF0F4FF);
  Color get surface  => isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFF);
  Color get card     => isDark ? const Color(0xFF1A2540) : Colors.white;
  Color get cardBdr  => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);
  Color get input    => isDark ? const Color(0xFF1A2540) : Colors.white;

  // ── Brand (static) ────────────────────────────────────────────
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

  // ── Text ──────────────────────────────────────────────────────
  Color get textHi  => isDark ? Colors.white            : const Color(0xFF0A1628);
  Color get textMid => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get textDim => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
  Color get divider => isDark ? const Color(0xFF2D3A52) : const Color(0xFFE8EDF5);

  // ── Gradients ─────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(colors: [navy, navyMid], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient goldGradient   = LinearGradient(colors: [gold, goldSoft, gold], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const LinearGradient blueGradient   = LinearGradient(colors: [blue, blueSoft], begin: Alignment.topLeft, end: Alignment.bottomRight);

  // ── Factory ───────────────────────────────────────────────────
  static AppColors of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AppColors._(isDark: dark);
  }

  BoxDecoration cardBox({Color? borderColor, bool glow = false, bool goldGlow = false}) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: borderColor ?? cardBdr, width: borderColor != null ? 1.5 : 1),
    boxShadow: goldGlow
        ? [BoxShadow(color: gold.withValues(alpha: isDark ? 0.18 : 0.12), blurRadius: 16, offset: const Offset(0,4))]
        : glow
            ? [BoxShadow(color: blue.withValues(alpha: isDark ? 0.18 : 0.12), blurRadius: 16, offset: const Offset(0,4))]
            : [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0,3))],
  );

  TextStyle heading(double size, {Color? color}) => TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color ?? textHi, letterSpacing: -0.5);
  TextStyle label(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: textMid);

  InputDecoration inputDec(String lbl, IconData icon) => InputDecoration(
    labelText: lbl,
    labelStyle: TextStyle(color: textDim, fontSize: 13, fontWeight: FontWeight.w600),
    prefixIcon: Icon(icon, color: textDim, size: 20),
    filled: true, fillColor: input,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBdr)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBdr)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: blue, width: 2)),
  );
}

// ─── ThemeData ─────────────────────────────────────────────────────────────
class AppThemeData {
  static ThemeData light() => ThemeData(
    useMaterial3: true, brightness: Brightness.light,
    primaryColor: AppColors.blue,
    scaffoldBackgroundColor: const Color(0xFFF0F4FF),
    colorScheme: const ColorScheme.light(primary: AppColors.blue, secondary: AppColors.gold, surface: Colors.white, error: AppColors.rose),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(color: Colors.white, elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.blue, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blue, width: 2))),
    dividerColor: const Color(0xFFE8EDF5),
    dialogTheme: DialogThemeData(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Colors.white, selectedItemColor: AppColors.blue, unselectedItemColor: Color(0xFF94A3B8)),
    switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.blue : Colors.white), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.blue.withValues(alpha: 0.4) : const Color(0xFFE5E7EB))),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    primaryColor: AppColors.blueSoft,
    scaffoldBackgroundColor: const Color(0xFF0A1628),
    colorScheme: const ColorScheme.dark(primary: AppColors.blueSoft, secondary: AppColors.goldSoft, surface: Color(0xFF1A2540), error: AppColors.rose),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.navy, foregroundColor: Colors.white, elevation: 0),
    cardTheme: CardThemeData(color: const Color(0xFF1A2540), elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: AppColors.blueSoft, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFF1A2540), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3A52))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2D3A52))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.blueSoft, width: 2))),
    dividerColor: const Color(0xFF2D3A52),
    dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1A2540), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(backgroundColor: Color(0xFF111827), selectedItemColor: AppColors.blueSoft, unselectedItemColor: Color(0xFF64748B)),
    switchTheme: SwitchThemeData(thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.blueSoft : Colors.white), trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.blueSoft.withValues(alpha: 0.4) : const Color(0xFF2D3A52))),
  );
}

// ─── Status helpers ────────────────────────────────────────────────────────
Color lStatusColor(String s) {
  switch (s.toLowerCase()) {
    case 'pending':          return AppColors.amber;
    case 'assigned':         return AppColors.gold;
    case 'accepted':         return AppColors.blue;
    case 'pickup':           return AppColors.blueSoft;
    case 'processing':       return AppColors.violet;
    case 'reached':          return AppColors.violet;
    case 'picked':           return AppColors.cyan;
    case 'delivery':
    case 'out_for_delivery': return AppColors.amber;
    case 'delivered':
    case 'completed':        return AppColors.emerald;
    case 'cancelled':
    case 'rejected':         return AppColors.rose;
    default:                 return const Color(0xFF94A3B8);
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
