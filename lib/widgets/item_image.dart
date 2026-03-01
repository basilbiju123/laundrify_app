import 'package:flutter/material.dart';

/// Displays an item image from assets with a graceful fallback icon
/// when the asset file is missing (404 on web or not bundled yet).
class ItemImage extends StatelessWidget {
  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ItemImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  IconData _icon() {
    final n = assetPath.toLowerCase();
    if (n.contains('shirt') || n.contains('tshirt')) return Icons.checkroom_rounded;
    if (n.contains('pant') || n.contains('jean'))    return Icons.dry_cleaning_rounded;
    if (n.contains('saree') || n.contains('silk') || n.contains('lehenga')) return Icons.local_laundry_service_rounded;
    if (n.contains('suit') || n.contains('blazer') || n.contains('formal'))  return Icons.dry_cleaning_rounded;
    if (n.contains('party') || n.contains('wedding')) return Icons.celebration_rounded;
    if (n.contains('bag') || n.contains('purse'))    return Icons.shopping_bag_rounded;
    if (n.contains('shoe') || n.contains('boot'))    return Icons.cleaning_services_rounded;
    if (n.contains('carpet') || n.contains('rug'))   return Icons.grid_on_rounded;
    if (n.contains('curtain'))                        return Icons.curtains_rounded;
    return Icons.local_laundry_service_rounded;
  }

  Color _color() {
    final n = assetPath.toLowerCase();
    if (n.contains('bag'))      return const Color(0xFFD97706);
    if (n.contains('carpet'))   return const Color(0xFF059669);
    if (n.contains('curtain'))  return const Color(0xFFE11D48);
    if (n.contains('shoe'))     return const Color(0xFF0891B2);
    if (n.contains('dry') || n.contains('suit') || n.contains('formal')) return const Color(0xFF7C3AED);
    return const Color(0xFF1B4FD8);
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    final fallback = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: borderRadius,
      ),
      child: Center(
        child: Icon(_icon(), color: c, size: (height ?? 60) * 0.42),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
