// lib/screens/admin/admin_coupons_page.dart
//
// Admin Coupons Management
// • Create / edit / deactivate global coupons (/coupons collection)
// • See full usage analytics per coupon
// • Per-coupon: usage count, total savings given, list of users who used it

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_theme.dart';

class AdminCouponsPage extends StatefulWidget {
  const AdminCouponsPage({super.key});
  @override
  State<AdminCouponsPage> createState() => _AdminCouponsPageState();
}

class _AdminCouponsPageState extends State<AdminCouponsPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final at = DynAdmin.of(context);
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        color: at.surface,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Coupon Management',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                    color: at.textPrimary)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Create', style: TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.gold,
                  foregroundColor: const Color(0xFF080F1E),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _showCreateSheet(context, at),
            ),
          ]),
          const SizedBox(height: 14),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            controller: _tab,
            labelColor: AdminTheme.gold,
            unselectedLabelColor: at.textMuted,
            indicatorColor: AdminTheme.gold,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'All Coupons'),
              Tab(text: 'Offers'),
            ],
          ),
        ]),
      ),

      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            _couponList(at, activeOnly: true),
            _couponList(at, activeOnly: false),
            _offersTab(at),
          ],
        ),
      ),
    ]);
  }

  Widget _couponList(DynAdmin at, {required bool activeOnly}) {
    var query = _db.collection('coupons')
        .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AdminTheme.gold, strokeWidth: 2));
        }
        final docs = (snap.data?.docs ?? [])
            .where((d) {
              final data = d.data() as Map<String, dynamic>;
              if (activeOnly) return data['isActive'] == true;
              return true;
            }).toList();

        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer_outlined, size: 48, color: at.textMuted),
              const SizedBox(height: 12),
              Text(activeOnly ? 'No active coupons' : 'No coupons created yet',
                  style: TextStyle(color: at.textMuted, fontSize: 14)),
            ],
          ));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _couponCard(at, docs[i]),
        );
      },
    );
  }

  Widget _couponCard(DynAdmin at, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isActive   = data['isActive'] == true;
    final code       = data['code'] ?? '';
    final title      = data['title'] ?? '';
    final type       = data['discountType'] ?? 'flat';
    final discount   = (data['discount'] ?? 0).toDouble();
    final usedCount  = (data['usedCount'] ?? 0) as int;
    final maxUses    = data['maxUses'];
    final rawExp = data['validUntil'];
    final exp = rawExp is DateTime ? rawExp : (rawExp != null ? (() { try { return (rawExp as dynamic).toDate() as DateTime; } catch(_) { return null; }})() : null);
    final isExpired  = exp != null && exp.isBefore(DateTime.now());

    final discountStr = type == 'percentage'
        ? '${discount.toStringAsFixed(0)}% OFF'
        : '₹${discount.toStringAsFixed(0)} OFF';

    return Container(
      decoration: BoxDecoration(
        color: at.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isActive && !isExpired
            ? AdminTheme.gold.withValues(alpha: 0.3)
            : at.cardBorder),
      ),
      child: Column(children: [
        // Top row
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isActive && !isExpired)
                    ? AdminTheme.gold.withValues(alpha: 0.12)
                    : at.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (isActive && !isExpired)
                    ? AdminTheme.gold.withValues(alpha: 0.4)
                    : at.cardBorder),
              ),
              child: Text(code,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900,
                      color: (isActive && !isExpired) ? AdminTheme.gold : at.textMuted,
                      letterSpacing: 2)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(title, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: at.textPrimary)),
                Text(discountStr, style: TextStyle(
                    fontSize: 12, color: AdminTheme.emerald,
                    fontWeight: FontWeight.w700)),
              ],
            )),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isExpired
                    ? AdminTheme.rose
                    : isActive ? AdminTheme.emerald : at.textMuted)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                  isExpired ? 'EXPIRED' : isActive ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: isExpired ? AdminTheme.rose
                          : isActive ? AdminTheme.emerald : at.textMuted,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              color: at.surface,
              onSelected: (v) {
                if (v == 'toggle') _toggleActive(doc.id, isActive);
                if (v == 'delete') _deleteCoupon(doc.id);
                if (v == 'usages') _showUsages(context, at, doc.id, code);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'usages',
                    child: Row(children: [
                      Icon(Icons.bar_chart_rounded, size: 16, color: AdminTheme.accent),
                      const SizedBox(width: 8),
                      Text('View Usages', style: TextStyle(color: at.textPrimary)),
                    ])),
                PopupMenuItem(value: 'toggle',
                    child: Row(children: [
                      Icon(isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 16, color: AdminTheme.amber),
                      const SizedBox(width: 8),
                      Text(isActive ? 'Deactivate' : 'Activate',
                          style: TextStyle(color: at.textPrimary)),
                    ])),
                PopupMenuItem(value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_rounded, size: 16, color: AdminTheme.rose),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AdminTheme.rose)),
                    ])),
              ],
              child: Icon(Icons.more_vert_rounded, color: at.textMuted, size: 20),
            ),
          ]),
        ),
        // Stats row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: at.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
          child: Row(children: [
            _stat(at, Icons.people_rounded, '$usedCount used',
                maxUses != null ? 'of $maxUses' : 'no limit'),
            const SizedBox(width: 16),
            if (exp != null)
              _stat(at, Icons.event_rounded,
                  'Expires', '${exp.day}/${exp.month}/${exp.year}'),
            const Spacer(),
            GestureDetector(
              onTap: () => _showUsages(context, at, doc.id, code),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: AdminTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AdminTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('Analytics', style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AdminTheme.accent)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(DynAdmin at, IconData icon, String label, String sub) =>
      Row(children: [
        Icon(icon, size: 14, color: at.textMuted),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: at.textPrimary)),
          Text(sub, style: TextStyle(fontSize: 10, color: at.textMuted)),
        ]),
      ]);

  // ── Create coupon bottom sheet ────────────────────────────────
  void _showCreateSheet(BuildContext ctx, DynAdmin at) {
    final codeCtrl     = TextEditingController();
    final titleCtrl    = TextEditingController();
    final discountCtrl = TextEditingController();
    final maxDiscCtrl  = TextEditingController();
    final minOrderCtrl = TextEditingController();
    final maxUsesCtrl  = TextEditingController();
    String type = 'flat';
    DateTime? expiry;
    bool saving = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx2, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
                color: at.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Center(child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: at.cardBorder,
                        borderRadius: BorderRadius.circular(2)))),
                Text('Create Coupon', style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w900, color: at.textPrimary)),
                const SizedBox(height: 20),

                _field(at, codeCtrl, 'Coupon Code (e.g. SAVE20)',
                    Icons.confirmation_number_rounded,
                    caps: true),
                const SizedBox(height: 12),
                _field(at, titleCtrl, 'Title / Description',
                    Icons.label_rounded),
                const SizedBox(height: 12),

                // Discount type toggle
                Text('Discount Type', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: at.textMuted)),
                const SizedBox(height: 8),
                Row(children: [
                  _typeBtn(at, 'flat', '₹ Flat', type,
                      (v) => setLocal(() => type = v)),
                  const SizedBox(width: 10),
                  _typeBtn(at, 'percentage', '% Percentage', type,
                      (v) => setLocal(() => type = v)),
                ]),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(child: _field(at, discountCtrl,
                      type == 'percentage' ? 'Discount %' : 'Discount ₹',
                      Icons.discount_rounded, num: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(at, maxDiscCtrl,
                      'Max Discount ₹ (optional)',
                      Icons.shield_rounded, num: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(at, minOrderCtrl,
                      'Min Order ₹', Icons.shopping_bag_rounded, num: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(at, maxUsesCtrl,
                      'Max Uses (optional)', Icons.people_rounded, num: true)),
                ]),
                const SizedBox(height: 12),

                // Expiry date
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx2,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setLocal(() => expiry = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                        color: at.card, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: at.cardBorder)),
                    child: Row(children: [
                      Icon(Icons.event_rounded, size: 18, color: at.textMuted),
                      const SizedBox(width: 10),
                      Text(expiry != null
                          ? 'Expires: ${expiry!.day}/${expiry!.month}/${expiry!.year}'
                          : 'Set Expiry Date (optional)',
                          style: TextStyle(
                              color: expiry != null ? at.textPrimary : at.textMuted,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.gold,
                        foregroundColor: const Color(0xFF080F1E),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    onPressed: saving ? null : () async {
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (code.isEmpty) return;
                      final disc = double.tryParse(discountCtrl.text) ?? 0;
                      if (disc <= 0) return;

                      setLocal(() => saving = true);
                      try {
                        await _db.collection('coupons').add({
                          'code':         code,
                          'title':        titleCtrl.text.trim(),
                          'discountType': type,
                          'discount':     disc,
                          if (maxDiscCtrl.text.isNotEmpty)
                            'maxDiscount': double.tryParse(maxDiscCtrl.text),
                          'minOrder':     double.tryParse(minOrderCtrl.text) ?? 0,
                          if (maxUsesCtrl.text.isNotEmpty)
                            'maxUses': int.tryParse(maxUsesCtrl.text),
                          if (expiry != null)
                            'validUntil': Timestamp.fromDate(expiry!),
                          'usedCount':    0,
                          'isActive':     true,
                          'createdAt':    FieldValue.serverTimestamp(),
                        });
                        if (ctx2.mounted) Navigator.pop(ctx2);
                      } catch (_) {
                        setLocal(() => saving = false);
                      }
                    },
                    child: saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF080F1E)))
                        : const Text('CREATE COUPON',
                            style: TextStyle(fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(DynAdmin at, TextEditingController ctrl, String hint,
      IconData icon, {bool num = false, bool caps = false}) =>
      TextField(
        controller: ctrl,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        textCapitalization: caps
            ? TextCapitalization.characters : TextCapitalization.none,
        style: TextStyle(fontSize: 13, color: at.textPrimary,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: at.textMuted, fontSize: 12),
          prefixIcon: Icon(icon, size: 16, color: at.textMuted),
          filled: true, fillColor: at.card,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: at.cardBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: at.cardBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AdminTheme.gold, width: 1.5)),
        ),
      );

  Widget _typeBtn(DynAdmin at, String value, String label, String current,
      void Function(String) onTap) {
    final active = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AdminTheme.gold.withValues(alpha: 0.12) : at.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: active ? AdminTheme.gold : at.cardBorder,
                width: active ? 1.5 : 1),
          ),
          child: Center(child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: active ? AdminTheme.gold : at.textMuted))),
        ),
      ),
    );
  }

  // ── Usage analytics sheet ─────────────────────────────────────
  void _showUsages(BuildContext ctx, DynAdmin at, String couponId, String code) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx2, sc) => Container(
          decoration: BoxDecoration(
              color: at.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Column(children: [
                Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: at.cardBorder,
                        borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 14),
                Row(children: [
                  Icon(Icons.local_offer_rounded,
                      color: AdminTheme.gold, size: 20),
                  const SizedBox(width: 8),
                  Text('Usage: $code',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w900, color: at.textPrimary)),
                ]),
                const SizedBox(height: 14),
                Divider(color: at.cardBorder, height: 1),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('coupons').doc(couponId)
                    .collection('usages')
                    .orderBy('usedAt', descending: true)
                    .snapshots(),
                builder: (ctx3, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(
                        color: AdminTheme.gold, strokeWidth: 2));
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(child: Text('No usages yet',
                        style: TextStyle(color: at.textMuted)));
                  }

                  // Summary
                  double totalSaved = 0;
                  for (final d in docs) {
                    final data = d.data() as Map<String, dynamic>;
                    totalSaved += (data['discountAmount'] ?? 0).toDouble();
                  }

                  return ListView(
                    controller: sc,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Summary cards
                      Row(children: [
                        _summaryCard(at, '${docs.length}',
                            'Total Uses', AdminTheme.accent),
                        const SizedBox(width: 10),
                        _summaryCard(at,
                            '₹${totalSaved.toStringAsFixed(0)}',
                            'Total Discount Given', AdminTheme.emerald),
                      ]),
                      const SizedBox(height: 16),
                      Text('Usage Details',
                          style: TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w800, color: at.textPrimary)),
                      const SizedBox(height: 10),
                      ...docs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final usedAt = (data['usedAt'] as Timestamp?)?.toDate();
                        final disc = (data['discountAmount'] ?? 0).toDouble();
                        final total = (data['orderTotal'] ?? 0).toDouble();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: at.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: at.cardBorder)),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                  color: AdminTheme.emerald.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: const Center(child: Icon(
                                  Icons.person_rounded,
                                  color: AdminTheme.emerald, size: 18)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(data['userName'] ?? data['userEmail'] ?? '',
                                    style: TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: at.textPrimary)),
                                Text(data['userEmail'] ?? '',
                                    style: TextStyle(fontSize: 11,
                                        color: at.textMuted)),
                                if (usedAt != null)
                                  Text(
                                      '${usedAt.day}/${usedAt.month}/${usedAt.year} ${usedAt.hour.toString().padLeft(2,'0')}:${usedAt.minute.toString().padLeft(2,'0')}',
                                      style: TextStyle(fontSize: 10,
                                          color: at.textMuted)),
                              ],
                            )),
                            Column(crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                              Text('−₹${disc.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: AdminTheme.emerald)),
                              Text('of ₹${total.toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 11,
                                      color: at.textMuted)),
                            ]),
                          ]),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _summaryCard(DynAdmin at, String value, String label, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: at.textMuted,
              fontWeight: FontWeight.w600)),
        ]),
      ));

  Future<void> _toggleActive(String id, bool current) =>
      _db.collection('coupons').doc(id).update({'isActive': !current});

  Future<void> _deleteCoupon(String id) =>
      _db.collection('coupons').doc(id).delete();


  // ── OFFERS TAB ─────────────────────────────────────────────────
  Widget _offersTab(DynAdmin at) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: Text('Promotional Offers & Banners',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: at.textPrimary))),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Offer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.emerald, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _showAddOfferSheet(at),
          ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db.collection('offers').orderBy('createdAt', descending: true).snapshots(),
          builder: (ctx, snap) {
            final at2 = DynAdmin.of(ctx);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: AdminTheme.gold, strokeWidth: 2));
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_offer_outlined, size: 48, color: at2.textMuted),
                const SizedBox(height: 12),
                Text('No offers yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: at2.textPrimary)),
                const SizedBox(height: 4),
                Text('Add promotional banners shown in the app', style: TextStyle(fontSize: 13, color: at2.textMuted)),
              ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (ctx, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final isActive = d['isActive'] ?? true;
                final rawExp = d['expiresAt'];
                DateTime? expiresAt;
                if (rawExp is DateTime) {
                  expiresAt = rawExp;
                } else if (rawExp != null) {
                  try { expiresAt = (rawExp as dynamic).toDate(); } catch (_) {}
                }
                final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: at2.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isActive && !expired ? AdminTheme.emerald.withValues(alpha: 0.4) : at2.cardBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: (isActive && !expired ? AdminTheme.emerald : at2.textMuted).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.local_offer_rounded,
                          color: isActive && !expired ? AdminTheme.emerald : at2.textMuted, size: 22),
                    ),
                    title: Text(d['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: at2.textPrimary)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 2),
                      Text(d['description'] ?? '', style: TextStyle(fontSize: 12, color: at2.textMuted), maxLines: 2),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (expiresAt != null) ...[ 
                          Icon(Icons.schedule_rounded, size: 11, color: expired ? AdminTheme.rose : at2.textMuted),
                          const SizedBox(width: 3),
                          Text(expired ? 'Expired' : 'Expires ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}',
                              style: TextStyle(fontSize: 10, color: expired ? AdminTheme.rose : at2.textMuted)),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isActive && !expired ? AdminTheme.emerald : AdminTheme.rose).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(isActive && !expired ? 'ACTIVE' : expired ? 'EXPIRED' : 'INACTIVE',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                                  color: isActive && !expired ? AdminTheme.emerald : AdminTheme.rose)),
                        ),
                      ]),
                    ]),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: at2.textMuted),
                      color: at2.card,
                      onSelected: (action) async {
                        if (action == 'toggle') {
                          await docs[i].reference.update({'isActive': !isActive});
                        } else if (action == 'delete') {
                          await docs[i].reference.delete();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'toggle', child: Text(isActive ? 'Deactivate' : 'Activate',
                            style: TextStyle(color: at2.textPrimary))),
                        PopupMenuItem(value: 'delete', child: Text('Delete',
                            style: TextStyle(color: AdminTheme.rose))),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Future<void> _showAddOfferSheet(DynAdmin at) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final linkCtrl = TextEditingController();
    DateTime? expiresAt;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: at.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom, left: 20, right: 20, top: 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Add Offer / Banner', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: at.textPrimary)),
              const Spacer(),
              IconButton(icon: Icon(Icons.close_rounded, color: at.textMuted), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: titleCtrl,
              style: TextStyle(color: at.textPrimary),
              decoration: InputDecoration(
                labelText: 'Offer Title *',
                labelStyle: TextStyle(color: at.textMuted, fontSize: 13),
                filled: true, fillColor: at.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              style: TextStyle(color: at.textPrimary),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: at.textMuted, fontSize: 13),
                filled: true, fillColor: at.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: imageCtrl,
              style: TextStyle(color: at.textPrimary),
              decoration: InputDecoration(
                labelText: 'Image URL (optional)',
                labelStyle: TextStyle(color: at.textMuted, fontSize: 13),
                filled: true, fillColor: at.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkCtrl,
              style: TextStyle(color: at.textPrimary),
              decoration: InputDecoration(
                labelText: 'Deep link / Route (optional)',
                labelStyle: TextStyle(color: at.textMuted, fontSize: 13),
                filled: true, fillColor: at.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: at.cardBorder)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(Icons.calendar_today_rounded, size: 16, color: AdminTheme.gold),
              label: Text(expiresAt == null ? 'Set Expiry Date (optional)' : 'Expires: \${expiresAt!.day}/\${expiresAt!.month}/\${expiresAt!.year}',
                  style: TextStyle(color: at.textPrimary, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: at.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: ctx2,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setS(() => expiresAt = picked);
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.gold,
                    foregroundColor: AdminTheme.navy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: saving ? null : () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  setS(() => saving = true);
                  try {
                    await _db.collection('offers').add({
                      'title': titleCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      if (imageCtrl.text.trim().isNotEmpty) 'imageUrl': imageCtrl.text.trim(),
                      if (linkCtrl.text.trim().isNotEmpty) 'deepLink': linkCtrl.text.trim(),
                      if (expiresAt != null) 'expiresAt': expiresAt,
                      'isActive': true,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (_) {
                    setS(() => saving = false);
                  }
                },
                child: saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Offer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

}
