import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import '../services/firestore_service.dart';

// ═══════════════════════════════════════════════════════════
// LOYALTY & REWARDS PAGE
// Points earn/redeem, referral system, history
// ═══════════════════════════════════════════════════════════

const _navy = Color(0xFF080F1E);
const _gold = Color(0xFFF5C518);
const _goldSoft = Color(0xFFFDE68A);
const _blue = Color(0xFF1B4FD8);
const _green = Color(0xFF10B981);
const _violet = Color(0xFF8B5CF6);
const _rose = Color(0xFFEF4444);

class LoyaltyPage extends StatefulWidget {
  const LoyaltyPage({super.key});
  @override
  State<LoyaltyPage> createState() => _LoyaltyPageState();
}

class _LoyaltyPageState extends State<LoyaltyPage>
    with TickerProviderStateMixin {
  final _firestore = FirestoreService();
  late AnimationController _shimmerCtrl;
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;

  String? _referralCode;
  bool _loadingCode = true;

  // History loaded as Future to avoid dual-stream assertion error on web
  List<Map<String, dynamic>> _historyDocs = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _countCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..forward();
    _countAnim =
        CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic);
    _loadReferralCode();
    _loadHistory();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _historyLoading = true);
    try {
      final snap = await _firestore.getLoyaltyHistoryFuture();
      if (mounted) {
        setState(() {
          _historyDocs = snap;
          _historyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  Future<void> _loadReferralCode() async {
    final code = await _firestore.ensureReferralCode();
    if (mounted) {
      setState(() {
        _referralCode = code;
        _loadingCode = false;
      });
    }
  }

  // Points to tier
  String _tier(int pts) {
    if (pts >= 5000) return 'PLATINUM';
    if (pts >= 2000) return 'GOLD';
    if (pts >= 500) return 'SILVER';
    return 'BRONZE';
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'PLATINUM':
        return const Color(0xFF94A3B8);
      case 'GOLD':
        return _gold;
      case 'SILVER':
        return const Color(0xFFCBD5E1);
      default:
        return const Color(0xFFCD7F32);
    }
  }

  int _nextTierPts(int pts) {
    if (pts >= 5000) return 5000;
    if (pts >= 2000) return 5000;
    if (pts >= 500) return 2000;
    return 500;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppColors.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          children: [
            // APP BAR
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Expanded(
                    child: Text('Rewards & Loyalty',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: t.textHi))),
              ]),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.getLoyaltyStream(),
                builder: (ctx, snap) {
                  final t = AppColors.of(context);
                  final pts = (snap.data?.data()
                          as Map<String, dynamic>?)?['loyaltyPoints'] ??
                      0;
                  final totalEarned = (snap.data?.data()
                          as Map<String, dynamic>?)?['totalPointsEarned'] ??
                      0;
                  final tier = _tier(pts as int);
                  final tierColor = _tierColor(tier);
                  final nextTier = _nextTierPts(pts);
                  final progress = (pts / nextTier).clamp(0.0, 1.0);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // POINTS HERO CARD
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF1A1000),
                              _gold.withValues(alpha: 0.15),
                              const Color(0xFF0D1000)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: _gold.withValues(alpha: 0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: _gold.withValues(alpha: 0.1),
                                blurRadius: 30,
                                spreadRadius: 0)
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                          color:
                                              tierColor.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Icon(Icons.star_rounded,
                                          color: tierColor, size: 20)),
                                  const SizedBox(width: 10),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('$tier MEMBER',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: tierColor,
                                                letterSpacing: 1.5)),
                                        Text('$totalEarned pts earned total',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5))),
                                      ]),
                                ]),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                      color: _gold.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: _gold.withValues(alpha: 0.3))),
                                  child: const Text('10 pts = ₹1',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _gold)),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            AnimatedBuilder(
                              animation: _countAnim,
                              builder: (_, __) => Text(
                                '${(_countAnim.value * pts).toInt()}',
                                style: const TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    color: _gold,
                                    height: 1),
                              ),
                            ),
                            const Text('POINTS',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _goldSoft,
                                    letterSpacing: 3)),

                            const SizedBox(height: 6),
                            Text('≈ ₹${(pts ~/ 10)} value',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Colors.white.withValues(alpha: 0.6))),

                            const SizedBox(height: 20),

                            // TIER PROGRESS
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Progress to next tier',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white
                                                    .withValues(alpha: 0.5))),
                                        Text('$pts / $nextTier pts',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: tierColor)),
                                      ]),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: AnimatedBuilder(
                                      animation: _countAnim,
                                      builder: (_, __) =>
                                          LinearProgressIndicator(
                                        value: progress * _countAnim.value,
                                        minHeight: 8,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                tierColor),
                                      ),
                                    ),
                                  ),
                                ]),

                            const SizedBox(height: 20),

                            // REDEEM BUTTON
                            if (pts >= 50)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _gold,
                                    foregroundColor: _navy,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _showRedeemSheet(pts),
                                  child: const Text('🎁 REDEEM POINTS',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          letterSpacing: 1)),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // HOW TO EARN SECTION
                      _sectionHeader('How to Earn Points'),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                            color: t.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: t.cardBdr)),
                        child: Column(children: [
                          _earnRow('🛍️', 'Place an Order',
                              '+10 pts bonus + ₹1=1pt'),
                          _divider(),
                          _earnRow('🎯', 'First Order', '+50 pts bonus'),
                          _divider(),
                          _earnRow(
                              '👥', 'Refer a Friend', '+150 pts per referral'),
                          _divider(),
                          _earnRow('🎁', 'Use Referral Code', '+100 pts bonus'),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // REFERRAL SECTION
                      _sectionHeader('Your Referral Code'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [
                                _violet.withValues(alpha: 0.2),
                                _blue.withValues(alpha: 0.1)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _violet.withValues(alpha: 0.3)),
                        ),
                        child: Column(children: [
                          const Text(
                              'Share your code & earn ₹15 for every friend who orders!',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  height: 1.4),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          if (_loadingCode)
                            const CircularProgressIndicator(
                                color: _violet, strokeWidth: 2)
                          else
                            Row(children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                      color: _navy,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              _violet.withValues(alpha: 0.4))),
                                  child: Text(_referralCode ?? 'N/A',
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: _violet,
                                          letterSpacing: 4),
                                      textAlign: TextAlign.center),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () {
                                  if (_referralCode != null) {
                                    Clipboard.setData(
                                        ClipboardData(text: _referralCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('📋 Code copied!'),
                                            backgroundColor: _violet,
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 2)));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: _violet.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color:
                                              _violet.withValues(alpha: 0.4))),
                                  child: const Icon(Icons.copy_rounded,
                                      color: _violet, size: 20),
                                ),
                              ),
                            ]),
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () => _showApplyReferralSheet(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1))),
                              child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.card_giftcard_rounded,
                                        color: Colors.white54, size: 16),
                                    SizedBox(width: 8),
                                    Text('Apply someone\'s code',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white54)),
                                  ]),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 20),

                      // TRANSACTION HISTORY
                      _sectionHeader('Points History'),
                      const SizedBox(height: 12),

                      // History uses local state (not stream) to avoid dual-stream
                      // assertion error on web when redeem writes to same user doc
                      _historyLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: _gold, strokeWidth: 2))
                          : _historyDocs.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                      color: t.card,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: t.cardBdr)),
                                  child: Center(
                                      child: Text(
                                          'No transactions yet. Start ordering to earn points!',
                                          style: TextStyle(
                                              color: t.textDim,
                                              fontSize: 13),
                                          textAlign: TextAlign.center)),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                      color: t.card,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: t.cardBdr)),
                                  child: Column(
                                    children:
                                        _historyDocs.asMap().entries.map((e) {
                                      final t = AppColors.of(context);
                                      final i = e.key;
                                      final d = e.value;
                                      final isEarn =
                                          (d['type'] ?? 'earn') == 'earn';
                                      // ignore: unused_local_variable
                                      final pts = d['points'] ?? 0;
                                      final ts = (d['createdAt'] as Timestamp?)
                                          ?.toDate();
                                      return Column(children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: (isEarn
                                                          ? _green
                                                          : _rose)
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              child: Icon(
                                                  isEarn
                                                      ? Icons.add_circle_rounded
                                                      : Icons
                                                          .remove_circle_rounded,
                                                  color:
                                                      isEarn ? _green : _rose,
                                                  size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                  Text(d['description'] ?? '',
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: t.textHi)),
                                                  if (ts != null)
                                                    Text(
                                                        '${ts.day}/${ts.month}/${ts.year}',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: t.textDim)),
                                                ])),
                                            Text(
                                                '${isEarn ? '+' : '-'}$pts pts',
                                                style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w900,
                                                    color: isEarn
                                                        ? _green
                                                        : _rose)),
                                          ]),
                                        ),
                                        if (i < _historyDocs.length - 1)
                                          Container(
                                              height: 1, color: t.cardBdr),
                                      ]);
                                    }).toList(),
                                  ),
                                ),

                      const SizedBox(height: 30),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    final t = AppColors.of(context);
    return Row(children: [
      Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: t.textHi)),
      const Spacer(),
    ]);
  }

  Widget _earnRow(String emoji, String title, String pts) {
    final t = AppColors.of(context);
    return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: t.textHi))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(pts,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _gold))),
        ]),
      );
  }

  Widget _divider() {
    final t = AppColors.of(context);
    return Container(height: 1, color: t.cardBdr);
  }

  void _showRedeemSheet(int currentPts) {
    int redeemPts = 50;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final discountValue = redeemPts ~/ 10;
          return Container(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const Text('Redeem Points',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('You have $currentPts points available',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: _gold.withValues(alpha: 0.3))),
                    child: Column(children: [
                      Text('$redeemPts',
                          style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: _gold)),
                      Text('POINTS = ₹$redeemPts discount',
                          style:
                              const TextStyle(fontSize: 13, color: _goldSoft)),
                      Text('≈ ₹$discountValue saved',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: redeemPts.toDouble(),
                    min: 50,
                    max: math.min(currentPts, 500).toDouble(),
                    divisions: ((math.min(currentPts, 500) - 50) / 50)
                        .floor()
                        .clamp(1, 100),
                    activeColor: _gold,
                    inactiveColor: Colors.white12,
                    onChanged: (v) => setLocal(() => redeemPts = v.toInt()),
                    label: '$redeemPts pts',
                  ),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('50 pts min',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4))),
                        Text('500 pts max per order',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4))),
                      ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _navy,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0),
                      onPressed: () async {
                        final result = await _firestore.redeemPoints(redeemPts);
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          if (result['success'] == true) {
                            _loadHistory(); // refresh history after redeem
                          }
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(result['success'] == true
                                ? '✅ $redeemPts pts redeemed! ₹${(result['discountAmount'] ?? redeemPts / 10).toStringAsFixed(0)} discount earned'
                                : '❌ ${result['error']}'),
                            backgroundColor:
                                result['success'] == true ? _green : _rose,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      },
                      child: const Text('REDEEM NOW',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showApplyReferralSheet() {
    final ctrl = TextEditingController();
    bool isLoading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
                color: Color(0xFF111827),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const Text('Apply Referral Code',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 6),
                const Text('Enter a friend\'s code to earn +100 points!',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'E.g. LDYABC123',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0,
                        fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFF0D1F3C),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _violet, width: 2)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _violet,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (ctrl.text.trim().isEmpty) return;
                            setLocal(() => isLoading = true);
                            final result = await _firestore
                                .applyReferralCode(ctrl.text.trim());
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(result['success']
                                    ? '🎉 +${result['pointsAwarded']} points added!'
                                    : '❌ ${result['error']}'),
                                backgroundColor:
                                    result['success'] ? _green : _rose,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('APPLY CODE',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
