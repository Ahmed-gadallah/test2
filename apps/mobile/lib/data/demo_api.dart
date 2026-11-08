import 'dart:math';

import 'api.dart';
import 'models.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  DEMO DATA SOURCE — fictional data for showcasing the app without a backend.
/// ─────────────────────────────────────────────────────────────────────────────
/// Mirrors the backend contract and its edge cases (unknown number, duplicate
/// ERP records, institutional account, refunds, missing optional fields). The
/// point deduction on approval simulates what the ERP does; it is not app logic.
///
/// Demo numbers: 0500000001 (2,500 pts) · 0500000002 (empty) ·
///               0500000003 (duplicate ERP records) · 0500000004 (institutional)
/// OTP: 123456
class DemoZaadApi implements ZaadApi {
  static const pointsPerSar = 50;
  final _rand = Random(7);
  final Map<String, _DemoCustomer> _byMobile = {};
  final Map<String, String> _passwords = {}; // mobile → password (demo only)
  final List<Redemption> _redemptions = [];
  final List<AppNotification> _notifications = [];
  late final List<Offer> _offers;
  String? _session;
  bool _outage = false;
  int _seq = 0;

  DemoZaadApi() {
    _byMobile['+966500000001'] = _DemoCustomer.generate('900001', 'محمد عبدالله', 34, 2500, Random(7));
    _byMobile['+966500000002'] = _DemoCustomer.generate('900002', 'سارة أحمد', 0, 0, Random(11));
    final now = DateTime.now();
    _offers = [
      Offer(
        id: 'offer-1',
        titleAr: 'خصم 20% على الفيتامينات والمكملات',
        titleEn: '20% off vitamins & supplements',
        descriptionAr: 'استمتع بخصم 20% على جميع الفيتامينات والمكملات الغذائية في جميع فروع زاد. العرض لفترة محدودة.',
        descriptionEn: 'Enjoy 20% off all vitamins and supplements at every Zaad branch. Limited time.',
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.add(const Duration(days: 12)),
      ),
      Offer(
        id: 'offer-2',
        titleAr: 'نقاط مضاعفة على منتجات العناية بالبشرة',
        titleEn: 'Double points on skincare',
        descriptionAr: 'اكسب ضعف النقاط عند شراء منتجات العناية بالبشرة المشاركة. (عرض تجريبي)',
        descriptionEn: 'Earn double points on participating skincare products. (demo offer)',
        startAt: now.subtract(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 6)),
      ),
      Offer(
        id: 'offer-3',
        titleAr: 'عروض العودة للمدارس',
        titleEn: 'Back-to-school deals',
        descriptionAr: 'خصومات على مستلزمات العناية بالأطفال ومعقمات اليدين.',
        descriptionEn: 'Discounts on kids care essentials and hand sanitizers.',
        startAt: now.subtract(const Duration(days: 5)),
        endAt: now.add(const Duration(days: 20)),
      ),
    ];
  }

  Future<void> _latency() => Future.delayed(Duration(milliseconds: 250 + _rand.nextInt(250)));
  void _erp() {
    if (_outage) throw const ApiFailure('ERP_UNAVAILABLE', status: 503);
  }

  _DemoCustomer get _me {
    final c = _session == null ? null : _byMobile[_session];
    if (c == null) throw const ApiFailure('SESSION_EXPIRED', status: 401);
    return c;
  }

  String _normalize(String raw) {
    final ascii = raw.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${m[0]!.codeUnitAt(0) - 0x0660}').replaceAll(RegExp(r'[^\d]'), '');
    var n = ascii.startsWith('00966') ? ascii.substring(5) : ascii.startsWith('966') ? ascii.substring(3) : ascii;
    if (n.startsWith('0')) n = n.substring(1);
    if (!RegExp(r'^5\d{8}$').hasMatch(n)) throw const ApiFailure('INVALID_MOBILE', status: 400);
    return '+966$n';
  }

  void _eligible(String m) {
    if (_passwords.containsKey(m)) throw const ApiFailure('ACCOUNT_EXISTS', status: 409);
    if (m == '+966500000003') throw const ApiFailure('ACCOUNT_NEEDS_SUPPORT', status: 409);
    if (m == '+966500000004') throw const ApiFailure('ACCOUNT_NOT_ELIGIBLE', status: 403);
    if (!_byMobile.containsKey(m)) throw const ApiFailure('MOBILE_NOT_REGISTERED', status: 404);
  }

  // ── auth ──
  @override
  Future<void> checkMobile(String mobile) async {
    await _latency();
    _eligible(_normalize(mobile));
  }

  @override
  Future<OtpInfo> sendOtp(String mobile, String purpose) async {
    await _latency();
    final m = _normalize(mobile);
    if (purpose == 'register') _eligible(m);
    return const OtpInfo(300, 30);
  }

  @override
  Future<String> verifyOtp(String mobile, String purpose, String code) async {
    await _latency();
    if (code != '123456') throw const ApiFailure('OTP_INVALID', status: 400);
    return 'demo-verification|${_normalize(mobile)}|$purpose';
  }

  @override
  Future<AuthTokens> register(String verificationToken, String password, String language) async {
    await _latency();
    final m = verificationToken.split('|')[1];
    _eligible(m);
    _passwords[m] = password;
    _session = m;
    return AuthTokens('demo-access-$m', 'demo-refresh-$m');
  }

  @override
  Future<AuthTokens> login(String mobile, String password) async {
    await _latency();
    final m = _normalize(mobile);
    // Demo convenience: the regular demo customer can log in directly with "zaad1234".
    final ok = _passwords[m] == password || (m == '+966500000001' && password == 'zaad1234' && !_passwords.containsKey(m));
    if (!ok) throw const ApiFailure('INVALID_CREDENTIALS', status: 401);
    _session = m;
    return AuthTokens('demo-access-$m', 'demo-refresh-$m');
  }

  @override
  Future<void> resetPassword(String verificationToken, String password) async {
    await _latency();
    _passwords[verificationToken.split('|')[1]] = password;
  }

  @override
  Future<void> logout() async => _session = null;

  /// Demo-only: restores the session after an app reload (tokens are in secure storage).
  void restore(String accessToken) {
    if (accessToken.startsWith('demo-access-')) _session = accessToken.substring('demo-access-'.length);
  }

  // ── customer ──
  @override
  Future<Profile> profile() async {
    await _latency();
    _erp();
    return Profile(customerId: _me.id, name: _me.name, mobileNumber: _session!);
  }

  @override
  Future<PointsBalance> points({bool refresh = false}) async {
    await _latency();
    _erp();
    final p = _me.points;
    return PointsBalance(points: p, equivalentSar: p ~/ pointsPerSar, pointsPerSar: pointsPerSar, asOf: DateTime.now());
  }

  PageResult<T> _page<T>(List<T> all, String? cursor) {
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = min(start + 20, all.length);
    return PageResult(all.sublist(start, end), end < all.length ? '$end' : null);
  }

  @override
  Future<PageResult<PointsEntry>> pointsHistory(String? cursor) async {
    await _latency();
    _erp();
    return _page(_me.ledger, cursor);
  }

  @override
  Future<PageResult<InvoiceSummary>> invoices(String? cursor) async {
    await _latency();
    _erp();
    return _page<InvoiceSummary>(_me.invoices, cursor);
  }

  @override
  Future<InvoiceDetail> invoice(String id) async {
    await _latency();
    _erp();
    return _me.invoices.firstWhere((i) => i.invoiceId == id, orElse: () => throw const ApiFailure('NOT_FOUND', status: 404));
  }

  // ── offers & notifications ──
  @override
  Future<List<Offer>> offers() async {
    await _latency();
    return _offers;
  }

  @override
  Future<Offer> offer(String id) async {
    await _latency();
    return _offers.firstWhere((o) => o.id == id, orElse: () => throw const ApiFailure('NOT_FOUND', status: 404));
  }

  @override
  Future<(List<AppNotification>, int)> notifications() async {
    await _latency();
    if (_notifications.isEmpty && _session != null) {
      final o = _offers.first;
      _notifications.add(AppNotification(
          id: 'n-welcome', type: 'offer', titleAr: o.titleAr, titleEn: o.titleEn, bodyAr: o.descriptionAr, bodyEn: o.descriptionEn, deepLink: 'zaad://offers/${o.id}', createdAt: o.startAt, read: false));
    }
    return (List<AppNotification>.of(_notifications), _notifications.where((n) => !n.read).length);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i >= 0) _notifications[i] = _notifications[i].markRead();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].markRead();
    }
  }

  void _notify(String type, String tAr, String tEn, String bAr, String bEn, String link) {
    _notifications.insert(0, AppNotification(id: 'n-${_seq++}', type: type, titleAr: tAr, titleEn: tEn, bodyAr: bAr, bodyEn: bEn, deepLink: link, createdAt: DateTime.now(), read: false));
  }

  // ── redemption ──
  Redemption _refresh(Redemption r) => r.status == RedemptionStatus.pending && r.expiresAt.isBefore(DateTime.now())
      ? Redemption(id: r.id, reference: r.reference, branchName: r.branchName, points: r.points, discountAmount: r.discountAmount, status: RedemptionStatus.expired, expiresAt: r.expiresAt)
      : r;

  @override
  Future<List<Redemption>> pendingRedemptions() async {
    _erp();
    _me;
    for (var i = 0; i < _redemptions.length; i++) {
      _redemptions[i] = _refresh(_redemptions[i]);
    }
    return _redemptions.where((r) => r.status == RedemptionStatus.pending).toList();
  }

  @override
  Future<Redemption> redemption(String id) async {
    await _latency();
    final i = _redemptions.indexWhere((r) => r.id == id);
    if (i < 0) throw const ApiFailure('NOT_FOUND', status: 404);
    return _redemptions[i] = _refresh(_redemptions[i]);
  }

  @override
  Future<Redemption> decideRedemption(String id, bool approve) async {
    await _latency();
    _erp();
    final i = _redemptions.indexWhere((r) => r.id == id);
    if (i < 0) throw const ApiFailure('NOT_FOUND', status: 404);
    final r = _redemptions[i] = _refresh(_redemptions[i]);
    if (r.status == RedemptionStatus.expired) throw const ApiFailure('REDEMPTION_EXPIRED', status: 410);
    if (r.status != RedemptionStatus.pending) throw const ApiFailure('REDEMPTION_ALREADY_DECIDED', status: 409);
    var status = approve ? RedemptionStatus.completed : RedemptionStatus.rejected;
    if (approve) {
      // ↓ Simulates the ERP validating the live balance and deducting.
      if (_me.points < r.points) {
        status = RedemptionStatus.failed;
      } else {
        _me.points -= r.points;
        _me.ledger.insert(
            0,
            PointsEntry(
                id: 'l-${_seq++}', occurredAt: DateTime.now(), type: PointsEntryType.redeemed, pointsDelta: -r.points, balanceAfter: _me.points, branchName: r.branchName, description: r.reference));
      }
    }
    final done = Redemption(
        id: r.id, reference: r.reference, branchName: r.branchName, points: r.points, discountAmount: r.discountAmount, status: status, expiresAt: r.expiresAt, customerDecision: approve ? 'approve' : 'reject');
    _redemptions[i] = done;
    if (status == RedemptionStatus.completed) {
      _notify('redemption_completed', 'تم استبدال النقاط', 'Redemption completed', 'تم خصم ${r.points} نقطة مقابل ${r.discountAmount.toInt()} ر.س.',
          '${r.points} points redeemed for SAR ${r.discountAmount.toInt()}.', 'zaad://redemptions/${r.id}');
    } else {
      _notify('redemption_rejected', 'تم رفض طلب الاستبدال', 'Redemption rejected', 'لم يتم خصم أي نقاط.', 'No points were deducted.', 'zaad://redemptions/${r.id}');
    }
    return done;
  }

  @override
  Future<void> simulateCashierRedemption(String mobile, int points) async {
    _me;
    final sar = points ~/ pointsPerSar;
    final r = Redemption(
      id: 'r-${_seq++}',
      reference: 'RR-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      branchName: 'زاد — فرع النخيل (تجريبي)',
      points: sar * pointsPerSar,
      discountAmount: sar.toDouble(),
      status: RedemptionStatus.pending,
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
    _redemptions.add(r);
    _notify('redemption_request', 'طلب استبدال نقاط', 'Points redemption request', '${r.branchName}: ${r.points} نقطة = $sar ر.س', '${r.branchName}: ${r.points} points = SAR $sar',
        'zaad://redemptions/${r.id}');
  }

  @override
  Future<void> simulateErpOutage(bool on) async => _outage = on;
}

class _DemoCustomer {
  final String id;
  final String name;
  int points;
  final List<PointsEntry> ledger;
  final List<InvoiceDetail> invoices;
  _DemoCustomer(this.id, this.name, this.points, this.ledger, this.invoices);

  static const _branches = ['زاد — فرع النخيل (تجريبي)', 'زاد — فرع الربوة (تجريبي)', 'زاد — فرع الملقا (تجريبي)', 'زاد — فرع السلي (تجريبي)'];
  static const _products = [
    ('Paracetamol 500mg 24 Tab', 9.5),
    ('Vitamin D3 1000IU 60 Cap', 42.0),
    ('Omega 3 Fish Oil 90 Softgel', 79.0),
    ('Baby Diapers Size 4 (44)', 65.25),
    ('Sunscreen SPF50 50ml', 88.0),
    ('Hand Sanitizer 500ml', 18.75),
    ('Multivitamin Kids Syrup 150ml', 36.5),
    ('Moisturizing Cream 200ml', 54.0),
  ];

  static double _r2(double v) => (v * 100).roundToDouble() / 100;

  factory _DemoCustomer.generate(String id, String name, int count, int finalBalance, Random rnd) {
    final invoices = <InvoiceDetail>[];
    final ledger = <PointsEntry>[];
    final now = DateTime.now();
    var earned = 0;
    for (var i = 0; i < count; i++) {
      final branch = _branches[rnd.nextInt(_branches.length)];
      final at = now.subtract(Duration(hours: ((count - i) * 89) + rnd.nextInt(10)));
      final lines = <InvoiceLine>[];
      for (var l = 0; l < 1 + rnd.nextInt(4); l++) {
        final (pName, price) = _products[rnd.nextInt(_products.length)];
        final q = 1 + rnd.nextInt(2);
        final disc = rnd.nextDouble() < 0.3 ? _r2(price * q * 0.1) : null;
        final net = price * q - (disc ?? 0);
        lines.add(InvoiceLine(name: pName, quantity: q, unitPrice: price, discount: disc, lineTotal: _r2(net * 1.15)));
      }
      final total = _r2(lines.fold(0.0, (s, l) => s + l.lineTotal));
      final status = i == count - 3 ? InvoiceStatus.refunded : i == count - 6 ? InvoiceStatus.partiallyRefunded : InvoiceStatus.finished;
      final pts = total.floor();
      final number = '${1650000 + int.parse(id.substring(4)) * 1000 + i}';
      final disc = lines.fold(0.0, (s, l) => s + (l.discount ?? 0));
      invoices.add(InvoiceDetail(
        invoiceId: '$id-${1000 + i}',
        invoiceNumber: number,
        issuedAt: at,
        branchName: branch,
        total: total,
        status: status,
        lines: lines,
        subTotal: _r2(lines.fold(0.0, (s, l) => s + l.unitPrice * l.quantity)),
        discountTotal: disc > 0 ? _r2(disc) : null,
        taxTotal: _r2(total - total / 1.15),
        pointsEarned: pts,
        paymentMethod: i % 5 == 4 ? null : PaymentMethod.values[rnd.nextInt(3)],
      ));
      earned += pts;
      ledger.add(PointsEntry(id: 'e$i', occurredAt: at, type: PointsEntryType.earned, pointsDelta: pts, invoiceNumber: number, branchName: branch));
      if (status != InvoiceStatus.finished) {
        final d = status == InvoiceStatus.refunded ? pts : pts ~/ 2;
        earned -= d;
        ledger.add(PointsEntry(id: 'r$i', occurredAt: at.add(const Duration(days: 2)), type: PointsEntryType.refundAdjustment, pointsDelta: -d, invoiceNumber: number, branchName: branch));
      }
    }
    final diff = finalBalance - earned;
    if (diff != 0 && invoices.isNotEmpty) {
      final mid = invoices[invoices.length ~/ 2];
      ledger.add(PointsEntry(
          id: 'adj',
          occurredAt: mid.issuedAt.add(const Duration(hours: 1)),
          type: diff < 0 ? PointsEntryType.redeemed : PointsEntryType.manualAdjustment,
          pointsDelta: diff,
          invoiceNumber: diff < 0 ? mid.invoiceNumber : null,
          branchName: diff < 0 ? mid.branchName : null));
    }
    ledger.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    var running = 0;
    final withBalance = [
      for (final e in ledger)
        PointsEntry(
            id: e.id,
            occurredAt: e.occurredAt,
            type: e.type,
            pointsDelta: e.pointsDelta,
            balanceAfter: running += e.pointsDelta,
            invoiceNumber: e.invoiceNumber,
            branchName: e.branchName),
    ];
    return _DemoCustomer(id, name, finalBalance, withBalance.reversed.toList(), invoices.reversed.toList());
  }
}
