import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'schedule_order_page.dart';
import 'laundry_items_page.dart';
import 'dryclean_items_page.dart';
import 'shoe_items_page.dart';
import 'bag_items_page.dart';
import 'carpet_items_page.dart';
import 'curtain_items_page.dart';

const _oNavy = Color(0xFF080F1E);
const _oNavyMid = Color(0xFF0D1F3C);
const _oBlue = Color(0xFF1B4FD8);
const _oGold = Color(0xFFF5C518);
const _oGoldSft = Color(0xFFFDE68A);
const _oGreen = Color(0xFF10B981);
const _oSurface = Color(0xFFF0F4FF);
const _oDark = Color(0xFF0A1628);
const _oFade = Color(0xFF94A3B8);

Color _oAccent(String n) {
  switch (n) {
    case 'Laundry':
      return const Color(0xFF1B4FD8);
    case 'Dry Clean':
      return const Color(0xFF7C3AED);
    case 'Shoe Clean':
      return const Color(0xFF0891B2);
    case 'Bag Clean':
      return const Color(0xFFD97706);
    case 'Carpet':
      return const Color(0xFF059669);
    case 'Curtain':
      return const Color(0xFFE11D48);
    default:
      return const Color(0xFF1B4FD8);
  }
}

IconData _oIcon(String n) {
  switch (n) {
    case 'Laundry':
      return Icons.local_laundry_service_rounded;
    case 'Dry Clean':
      return Icons.dry_cleaning_rounded;
    case 'Shoe Clean':
      return Icons.cleaning_services_rounded;
    case 'Bag Clean':
      return Icons.shopping_bag_outlined;
    case 'Carpet':
      return Icons.grid_on_rounded;
    case 'Curtain':
      return Icons.curtains_rounded;
    default:
      return Icons.category_rounded;
  }
}

class OrderSummaryPage extends StatefulWidget {
  final String serviceName;
  final List<Map<String, dynamic>> selectedItems;
  const OrderSummaryPage(
      {super.key, required this.serviceName, required this.selectedItems});
  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  // KEY FIX: Map keyed by service name — persists across all "Add More Services" additions
  final Map<String, List<Map<String, dynamic>>> _serviceMap = {};

  @override
  void initState() {
    super.initState();
    _merge(widget.serviceName, widget.selectedItems);
  }

  // Upsert items into existing service bucket
  void _merge(String name, List<Map<String, dynamic>> incoming) {
    final filtered =
        incoming.where((i) => (i['qty'] as int? ?? 0) > 0).toList();
    if (filtered.isEmpty) return;
    if (!_serviceMap.containsKey(name)) {
      _serviceMap[name] =
          filtered.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      final existing = _serviceMap[name]!;
      for (final item in filtered) {
        final idx = existing.indexWhere((e) => e['name'] == item['name']);
        if (idx != -1) {
          existing[idx] = Map<String, dynamic>.from(item);
        } else {
          existing.add(Map<String, dynamic>.from(item));
        }
      }
    }
  }

  List<Map<String, dynamic>> get _allServices => _serviceMap.entries
      .map((e) => {'serviceName': e.key, 'items': e.value})
      .toList();

  int get totalItems => _serviceMap.values
      .expand((i) => i)
      .fold(0, (s, i) => s + (i['qty'] as int));
  double get subtotal => _serviceMap.values
      .expand((i) => i)
      .fold(0.0, (s, i) => s + (i['qty'] as int) * (i['price'] as num));
  double get deliveryFee => 40.0;
  double get gst => subtotal * 0.18;
  double get total => subtotal + deliveryFee + gst;

  // ── Navigate to service page, await Navigator.pop result ──
  // Each service page MUST call:
  //   Navigator.pop(context, {'serviceName': 'Laundry', 'items': items.where((i)=>i['qty']>0).toList()});
  Future<void> _openService(String name, Widget page) async {
    Navigator.pop(context); // close bottom sheet first

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (!mounted || result == null) return;

    final svcName = (result['serviceName'] as String?) ?? name;
    final rawItems = result['items'];
    if (rawItems == null) return;

    final items = (rawItems as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => (e['qty'] as int? ?? 0) > 0)
        .toList();

    if (items.isEmpty) return;

    setState(() => _merge(svcName, items));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text('$svcName added to your order'),
      ]),
      backgroundColor: _oGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _bookNow() {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleOrderPage(
            totalAmount: total,
            totalItems: totalItems,
            services: _allServices,
          ),
        ));
  }

  void _showAddServiceSheet() {
    final svcList = [
      (
        'Laundry',
        Icons.local_laundry_service_rounded,
        const Color(0xFF1B4FD8),
        const LaundryPage(fromSummary: true)
      ),
      (
        'Dry Clean',
        Icons.dry_cleaning_rounded,
        const Color(0xFF7C3AED),
        const DryCleanPage(fromSummary: true)
      ),
      (
        'Shoe Clean',
        Icons.cleaning_services_rounded,
        const Color(0xFF0891B2),
        const ShoeDryCleanPage(fromSummary: true)
      ),
      (
        'Bag Clean',
        Icons.shopping_bag_outlined,
        const Color(0xFFD97706),
        const BagCleaningPage(fromSummary: true)
      ),
      (
        'Carpet',
        Icons.grid_on_rounded,
        const Color(0xFF059669),
        const CarpetCleaningPage(fromSummary: true)
      ),
      (
        'Curtain',
        Icons.curtains_rounded,
        const Color(0xFFE11D48),
        const CurtainCleaningPage(fromSummary: true)
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _oNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_circle_outline_rounded,
                      color: _oNavy, size: 22)),
              const SizedBox(width: 12),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Add More Services",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _oDark)),
                    SizedBox(height: 2),
                    Text("Items merge into your running order",
                        style: TextStyle(fontSize: 12, color: _oFade)),
                  ]),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.88,
              children: svcList.map((s) {
                final (name, icon, color, page) = s;
                final added = _serviceMap.containsKey(name);
                return GestureDetector(
                  onTap: () => _openService(name, page),
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: added
                                ? color.withValues(alpha: 0.6)
                                : color.withValues(alpha: 0.15),
                            width: added ? 2 : 1),
                        boxShadow: [
                          BoxShadow(
                              color: color.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(clipBehavior: Clip.none, children: [
                            Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: Icon(icon, color: color, size: 24)),
                            if (added)
                              Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                          color: _oGreen,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2)),
                                      child: const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 10))),
                          ]),
                          const SizedBox(height: 8),
                          Text(name,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: added ? color : _oDark),
                              textAlign: TextAlign.center),
                          if (added) ...[
                            const SizedBox(height: 2),
                            Text("Added ✓",
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _oGreen,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ]),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _oSurface,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_oNavy, _oNavyMid],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight))),
        leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18))),
        title: const Text("Order Summary",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20)),
        actions: [
          if (_serviceMap.length > 1)
            Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _oGold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _oGold.withValues(alpha: 0.4))),
                child: Text("${_serviceMap.length} services",
                    style: const TextStyle(
                        color: _oGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 12))),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              // ── Hero band ──────────────────────────────────
              _heroBand(),
              const SizedBox(height: 18),

              // ── ALL service sections render here ───────────
              // This iterates _serviceMap which accumulates every
              // service added via "Add More Services" sheet
              ..._serviceMap.entries
                  .map((e) => _serviceSection(e.key, e.value)),

              const SizedBox(height: 6),

              // ── Add More Services button ───────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: _showAddServiceSheet,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _oBlue.withValues(alpha: 0.25), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]),
                    child: Row(children: [
                      Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                              color: _oBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(13)),
                          child: const Icon(Icons.add_circle_outline_rounded,
                              color: _oBlue, size: 24)),
                      const SizedBox(width: 14),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text("Add More Services",
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _oBlue)),
                            SizedBox(height: 2),
                            Text("Mix laundry, dry clean, shoes & more",
                                style: TextStyle(fontSize: 12, color: _oFade)),
                          ])),
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _oNavy,
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white, size: 13)),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _billCard(),
              const SizedBox(height: 120),
            ]),
          ),
        ),
        _bottomBar(),
      ]),
    );
  }

  Widget _heroBand() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [_oNavy, _oNavyMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32))),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
          left: 22,
          right: 22,
          bottom: 24),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.receipt_long_rounded,
                color: _oGold, size: 26)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Your Order",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(
              "$totalItems item${totalItems != 1 ? 's' : ''} · "
              "${_serviceMap.length} service${_serviceMap.length != 1 ? 's' : ''}",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_oGold, _oGoldSft]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _oGold.withValues(alpha: 0.4), blurRadius: 10)
                ]),
            child: Text("₹${total.toStringAsFixed(0)}",
                style: const TextStyle(
                    color: _oNavy, fontWeight: FontWeight.w900, fontSize: 14))),
      ]),
    );
  }

  Widget _serviceSection(String name, List<Map<String, dynamic>> items) {
    final accent = _oAccent(name);
    final icon = _oIcon(name);
    final groupTotal = items.fold<double>(
        0, (s, i) => s + (i['qty'] as int) * (i['price'] as num));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
            ]),
        child: Column(children: [
          // Service header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.07),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22))),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: accent, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(name,
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 15))),
              Text("${items.length} item${items.length > 1 ? 's' : ''}",
                  style: const TextStyle(fontSize: 12, color: _oFade)),
              const SizedBox(width: 10),
              Text("₹${groupTotal.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
            ]),
          ),
          // Item rows
          ...items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            final item = e.value;
            return Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              Image.asset(item['image'], fit: BoxFit.cover))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(item['name'],
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _oDark)),
                        const SizedBox(height: 3),
                        Text("₹${item['price']} × ${item['qty']}",
                            style:
                                const TextStyle(fontSize: 12, color: _oFade)),
                      ])),
                  Text("₹${(item['qty'] as int) * (item['price'] as num)}",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: _oDark)),
                ]),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.grey.withValues(alpha: 0.1)),
            ]);
          }),
        ]),
      ),
    );
  }

  Widget _billCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 5))
            ]),
        child: Column(children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _oNavy.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt_outlined,
                    color: _oNavy, size: 20)),
            const SizedBox(width: 10),
            const Text("Bill Details",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: _oDark)),
          ]),
          const SizedBox(height: 18),
          _bRow("Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
          const SizedBox(height: 12),
          _bRow("Delivery Fee", "₹${deliveryFee.toStringAsFixed(0)}"),
          const SizedBox(height: 12),
          _bRow("GST (18%)", "₹${gst.toStringAsFixed(0)}"),
          const SizedBox(height: 14),
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Total",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w900, color: _oDark)),
            Text("₹${total.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: _oNavy)),
          ]),
        ]),
      ),
    );
  }

  Widget _bRow(String l, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 14, color: _oFade)),
          Text(v,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _oDark)),
        ],
      );

  Widget _bottomBar() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, -6))
          ]),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Multi-service chips
        if (_serviceMap.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              const Text("Services: ",
                  style: TextStyle(fontSize: 12, color: _oFade)),
              ..._serviceMap.keys.map((name) {
                final accent = _oAccent(name);
                return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_oIcon(name), color: accent, size: 11),
                      const SizedBox(width: 4),
                      Text(name,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent)),
                    ]));
              }),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("$totalItems item${totalItems != 1 ? 's' : ''}",
                style: const TextStyle(fontSize: 12, color: _oFade)),
            const SizedBox(height: 2),
            Text("₹${total.toStringAsFixed(0)}",
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900, color: _oDark)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: totalItems > 0 ? _bookNow : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                  gradient: totalItems > 0
                      ? const LinearGradient(
                          colors: [_oNavy, _oNavyMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight)
                      : null,
                  color: totalItems == 0 ? Colors.grey.shade200 : null,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: totalItems > 0
                      ? [
                          BoxShadow(
                              color: _oNavy.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5))
                        ]
                      : null),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text("BOOK NOW",
                    style: TextStyle(
                        color: totalItems > 0
                            ? Colors.white
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5)),
                const SizedBox(width: 8),
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: totalItems > 0
                            ? _oGold.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7)),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: totalItems > 0 ? _oGold : Colors.grey.shade400,
                        size: 16)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}
