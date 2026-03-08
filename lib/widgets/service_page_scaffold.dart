import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ── Item image URLs (CDN/network for web, asset path for mobile) ─────────────
// Maps item name keywords → public image URL (used on web)
// On mobile, Image.asset loads from assets/images/items/
const Map<String, String> _itemNetworkImages = {
  'shirt':        'https://images.unsplash.com/photo-1598033129183-c4f50c736f10?w=200&q=80',
  't-shirt':      'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=200&q=80',
  'tshirt':       'https://images.unsplash.com/photo-1583743814966-8936f5b7be1a?w=200&q=80',
  'pant':         'https://images.unsplash.com/photo-1542272604-787c3835535d?w=200&q=80',
  'jeans':        'https://images.unsplash.com/photo-1542272604-787c3835535d?w=200&q=80',
  'saree':        'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=200&q=80',
  'party wear':   'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=200&q=80',
  'wedding':      'https://images.unsplash.com/photo-1519657337289-077653f724ed?w=200&q=80',
  'kurta':        'https://images.unsplash.com/photo-1563306406-e66174fa3787?w=200&q=80',
  'jacket':       'https://images.unsplash.com/photo-1551028719-00167b16eac5?w=200&q=80',
  'coat':         'https://images.unsplash.com/photo-1548883354-94bcfe321cbb?w=200&q=80',
  'suit':         'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=200&q=80',
  'trouser':      'https://images.unsplash.com/photo-1624378439575-d8705ad7ae80?w=200&q=80',
  'shorts':       'https://images.unsplash.com/photo-1591195853828-11db59a44f43?w=200&q=80',
  'dress':        'https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=200&q=80',
  'blanket':      'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=200&q=80',
  'bedsheet':     'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=200&q=80',
  'pillow':       'https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=200&q=80',
  'towel':        'https://images.unsplash.com/photo-1563291074-2bf8677ac0e5?w=200&q=80',
  'shoe':         'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=200&q=80',
  'sneaker':      'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=200&q=80',
  'boot':         'https://images.unsplash.com/photo-1608256246200-53e635b5b65f?w=200&q=80',
  'bag':          'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=200&q=80',
  'handbag':      'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=200&q=80',
  'backpack':     'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=200&q=80',
  'carpet':       'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200&q=80',
  'rug':          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=200&q=80',
  'curtain':      'https://images.unsplash.com/photo-1558769132-cb1aea458c5e?w=200&q=80',
  'sofa':         'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=200&q=80',
  'sweater':      'https://images.unsplash.com/photo-1584670747417-594a9412feba?w=200&q=80',
  'hoodie':       'https://images.unsplash.com/photo-1556821840-3a63f15732ce?w=200&q=80',
  'lehenga':      'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=200&q=80',
  'salwar':       'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=200&q=80',
  'dupatta':      'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=200&q=80',
};

String? _networkImageFor(String itemName) {
  final lower = itemName.toLowerCase();
  for (final entry in _itemNetworkImages.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

/// A fully responsive service-page scaffold.
/// • Mobile  : standard AppBar + ListView + bottom checkout bar
/// • Web/Wide : side panel (service info + checkout) + scrollable item grid
class ServicePageScaffold extends StatelessWidget {
  final String serviceName;
  final IconData serviceIcon;
  final Color serviceColor;
  final List<Map<String, dynamic>> items;
  final int totalItems;
  final double totalAmount;
  final VoidCallback onCheckout;
  final void Function(int index) onIncrement;
  final void Function(int index) onDecrement;
  final AnimationController cartAnimController;

  const ServicePageScaffold({
    super.key,
    required this.serviceName,
    required this.serviceIcon,
    required this.serviceColor,
    required this.items,
    required this.totalItems,
    required this.totalAmount,
    required this.onCheckout,
    required this.onIncrement,
    required this.onDecrement,
    required this.cartAnimController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700 || kIsWeb;
        if (isWide) return _WideLayout(scaffold: this);
        return _MobileLayout(scaffold: this);
      },
    );
  }

  Widget buildItemCard(BuildContext context, int index, {bool gridMode = false}) {
    final t = AppColors.of(context);
    final item   = items[index];
    final bool hasItems  = (item['qty'] as int) > 0;
    final String name    = item['name'] as String;
    final int    price   = (item['price'] as num).toInt();
    final int    qty     = item['qty'] as int;
    final String? imagePath = item['image'] as String?;
    final IconData? iconData = item['icon'] as IconData?;
    final String? category  = item['category'] as String?;

    return Container(
      margin: gridMode ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasItems ? serviceColor : t.cardBdr,
          width: hasItems ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasItems
                ? serviceColor.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: t.isDark ? 0.2 : 0.04),
            blurRadius: hasItems ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onIncrement(index),
          child: Padding(
            padding: EdgeInsets.all(gridMode ? 10 : 12),
            child: gridMode
                ? _gridCardContent(context, name, price, qty, imagePath, iconData, category, hasItems, index)
                : _listCardContent(context, name, price, qty, imagePath, iconData, category, hasItems, index),
          ),
        ),
      ),
    );
  }

  Widget _listCardContent(BuildContext context, String name, int price, int qty, String? imagePath,
      IconData? iconData, String? category, bool hasItems, int index) {
    return Row(
      children: [
        _itemThumbnail(context, imagePath, iconData, hasItems, size: 72, itemName: name),
        const SizedBox(width: 12),
        Expanded(child: _itemInfo(context, name, price, qty, category, hasItems)),
        const SizedBox(width: 8),
        _qtyControl(context, qty, index, hasItems),
      ],
    );
  }

  Widget _gridCardContent(BuildContext context, String name, int price, int qty, String? imagePath,
      IconData? iconData, String? category, bool hasItems, int index) {
    final t = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _itemThumbnail(context, imagePath, iconData, hasItems, size: 60, fullWidth: true, itemName: name),
        const SizedBox(height: 8),
        Text(name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: t.textHi)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('₹$price',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.blue)),
        ),
        const SizedBox(height: 8),
        _qtyControl(context, qty, index, hasItems, compact: true),
      ],
    );
  }

  Widget _itemThumbnail(BuildContext context, String? imagePath, IconData? iconData, bool hasItems,
      {double size = 72, bool fullWidth = false, String? itemName}) {
    final t = AppColors.of(context);

    // Determine the best image source
    Widget child;
    final networkUrl = itemName != null ? _networkImageFor(itemName) : null;

    if (kIsWeb) {
      // Web: use network image (assets don't always resolve on web deploys)
      if (networkUrl != null) {
        child = Image.network(
          networkUrl,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor),
          errorBuilder: (_, __, ___) =>
              Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor),
        );
      } else if (imagePath != null) {
        child = Image.network(
          imagePath, // might be a URL already
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor),
        );
      } else {
        child = Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor);
      }
    } else {
      // Mobile: use asset image with network fallback
      if (imagePath != null) {
        child = Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            // Asset failed, try network
            if (networkUrl != null) {
              return Image.network(
                networkUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor),
              );
            }
            return Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor);
          });
      } else if (networkUrl != null) {
        child = Image.network(
          networkUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor),
        );
      } else {
        child = Icon(iconData ?? serviceIcon, size: size * 0.45, color: serviceColor);
      }
    }
    return Container(
      height: size,
      width: fullWidth ? double.infinity : size,
      decoration: BoxDecoration(
        color: t.isDark
            ? serviceColor.withValues(alpha: 0.1)
            : serviceColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: serviceColor.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Center(child: child),
    );
  }

  Widget _itemInfo(BuildContext context, String name, int price, int qty, String? category, bool hasItems) {
    final t = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.textHi),
            overflow: TextOverflow.ellipsis),
        if (category != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: t.isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(category,
                style: TextStyle(
                    fontSize: 10,
                    color: serviceColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('₹$price',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.blue)),
          ),
          const SizedBox(width: 6),
          Text('per item',
              style: TextStyle(fontSize: 12, color: t.textDim)),
        ]),
        if (hasItems) ...[
          const SizedBox(height: 5),
          Text('Subtotal: ₹${qty * price}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.emerald)),
        ],
      ],
    );
  }

  Widget _qtyControl(BuildContext context, int qty, int index, bool hasItems, {bool compact = false}) {
    final t = AppColors.of(context);
    if (!hasItems) {
      return GestureDetector(
        onTap: () => onIncrement(index),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 16, vertical: compact ? 6 : 8),
          decoration: BoxDecoration(color: serviceColor, borderRadius: BorderRadius.circular(12)),
          child: Text('ADD',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: compact ? 11 : 13)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: serviceColor.withValues(alpha: t.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _qtyBtn(context, Icons.remove, () => onDecrement(index), compact: compact),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('$qty',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: compact ? 13 : 16,
                    color: t.textHi)),
          ),
          _qtyBtn(context, Icons.add, () => onIncrement(index), compact: compact),
        ],
      ),
    );
  }

  Widget _qtyBtn(BuildContext context, IconData icon, VoidCallback onTap, {bool compact = false}) {
    final t = AppColors.of(context);
    final s = compact ? 30.0 : 34.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: s, width: s,
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: compact ? 16 : 18, color: serviceColor),
      ),
    );
  }

  Widget buildCheckoutBar(BuildContext context, {bool asCard = false}) {
    if (totalItems == 0) return const SizedBox.shrink();
    final t = AppColors.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$totalItems ${totalItems == 1 ? 'Item' : 'Items'}',
                      style: TextStyle(fontSize: 13, color: t.textMid, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('₹${totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: t.textHi)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppColors.emerald, size: 26),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: serviceColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('PROCEED TO CHECKOUT',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (asCard) {
      final t = AppColors.of(context);
      return Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(top: BorderSide(color: t.cardBdr)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: t.isDark ? 0.3 : 0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: content,
    );
  }
}

// ── MOBILE LAYOUT ────────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final ServicePageScaffold scaffold;
  const _MobileLayout({required this.scaffold});

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    final s = scaffold;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(s.serviceName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19)),
        backgroundColor: s.serviceColor,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, size: 26),
                onPressed: s.totalItems > 0 ? s.onCheckout : null,
              ),
              if (s.totalItems > 0)
                Positioned(
                  right: 6, top: 6,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 1.25).animate(
                        CurvedAnimation(parent: s.cartAnimController, curve: Curves.elasticOut)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(color: s.serviceColor, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                          s.totalItems > 9 ? '9+' : '${s.totalItems}',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: s.items.length,
        itemBuilder: (context, index) => s.buildItemCard(context, index),
      ),
      bottomNavigationBar: s.totalItems > 0
          ? SafeArea(
              top: false,
              child: s.buildCheckoutBar(context),
            )
          : null,
    );
  }
}

// ── WEB/WIDE LAYOUT ──────────────────────────────────────────────────────────
class _WideLayout extends StatelessWidget {
  final ServicePageScaffold scaffold;
  const _WideLayout({required this.scaffold});

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    final s = scaffold;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: Text(s.serviceName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: s.serviceColor,
        elevation: 0,
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: items grid ──
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Items',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: t.textMid)),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: s.items.length,
                      itemBuilder: (context, index) => s.buildItemCard(context, index, gridMode: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Right: service info + checkout ──
          Container(
            width: 290,
            constraints: const BoxConstraints(maxWidth: 290),
            height: double.infinity,
            decoration: BoxDecoration(
              color: t.card,
              border: Border(left: BorderSide(color: t.cardBdr)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: t.isDark ? 0.3 : 0.07), blurRadius: 20, offset: const Offset(-4, 0))
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service branding
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [s.serviceColor, s.serviceColor.withValues(alpha: 0.7)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      Icon(s.serviceIcon, color: Colors.white, size: 42),
                      const SizedBox(height: 10),
                      Text(s.serviceName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text('Professional cleaning service',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // Order summary
                  Text('Order Summary',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: t.textHi)),
                  const SizedBox(height: 10),
                  ...s.items.where((item) => (item['qty'] as int) > 0).map((item) {
                    final t = AppColors.of(context);
                    final qty   = item['qty'] as int;
                    final price = (item['price'] as num).toInt();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        Expanded(child: Text(item['name'] as String,
                            style: TextStyle(fontSize: 13, color: t.textMid))),
                        Text('$qty× ₹${qty * price}',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: s.serviceColor)),
                      ]),
                    );
                  }),
                  if (s.totalItems > 0) ...[
                    Divider(color: t.divider),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: t.textHi)),
                      Text('₹${s.totalAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: s.serviceColor)),
                    ]),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity, height: 48,
                      child: ElevatedButton(
                        onPressed: s.onCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: s.serviceColor, foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ]),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: t.cardBdr),
                      ),
                      child: Text(
                        'Tap any item on the left to add it to your order.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: t.textDim),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
