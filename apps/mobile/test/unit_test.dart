import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zaad/core/format.dart';
import 'package:zaad/data/api.dart';
import 'package:zaad/data/demo_api.dart';
import 'package:zaad/data/models.dart';
import 'package:zaad/features/notifications/notifications_screen.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  group('formatting', () {
    test('SAR in both languages with western digits', () {
      expect(const Fmt('ar').sar(50), '50 ر.س');
      expect(const Fmt('en').sar(1234.5), 'SAR 1,234.50');
      expect(const Fmt('ar').number(2500), '2,500');
      expect(const Fmt('ar').date(DateTime(2026, 11, 8)), contains('2026'));
      expect(const Fmt('ar').date(DateTime(2026, 11, 8)), isNot(contains('٢')));
    });
    test('mobile display', () => expect(const Fmt('ar').mobile('+966500000001'), '050 000 0001'));
    test('countdown never negative', () => expect(const Fmt('en').countdown(const Duration(seconds: -5)), '00:00'));
  });

  group('deep links', () {
    test('offer and redemption links', () {
      expect(routeForDeepLink('zaad://offers/abc'), '/offers/abc');
      expect(routeForDeepLink('zaad://redemptions/r1'), '/redemption/r1');
      expect(routeForDeepLink('https://evil.example/offers/abc'), isNull);
      expect(routeForDeepLink('zaad://unknown/x'), isNull);
    });
  });

  group('demo data source mirrors backend rules', () {
    Future<Object?> err(Future<void> Function() f) async {
      try {
        await f();
        return null;
      } on ApiFailure catch (e) {
        return e.code;
      }
    }

    test('registration edge cases', () async {
      final api = DemoZaadApi();
      expect(await err(() => api.checkMobile('0599999999')), 'MOBILE_NOT_REGISTERED');
      expect(await err(() => api.checkMobile('0500000003')), 'ACCOUNT_NEEDS_SUPPORT');
      expect(await err(() => api.checkMobile('0500000004')), 'ACCOUNT_NOT_ELIGIBLE');
      expect(await err(() => api.checkMobile('12')), 'INVALID_MOBILE');
      expect(await err(() => api.checkMobile('٠٥٠٠٠٠٠٠٠١')), isNull);
      expect(await err(() => api.verifyOtp('0500000001', 'register', '000000')), 'OTP_INVALID');
    });

    test('balance, SAR equivalent, history and redemption', () async {
      final api = DemoZaadApi();
      await api.login('0500000001', 'zaad1234');
      final b = await api.points();
      expect(b.points, 2500);
      expect(b.equivalentSar, 50);
      final h = await api.pointsHistory(null);
      expect(h.items.any((e) => e.type == PointsEntryType.refundAdjustment), isTrue);
      expect(h.items.first.balanceAfter, 2500);

      await api.simulateCashierRedemption('+966500000001', 1000);
      final pending = await api.pendingRedemptions();
      expect(pending.single.discountAmount, 20);
      final done = await api.decideRedemption(pending.single.id, true);
      expect(done.status, RedemptionStatus.completed);
      expect((await api.points()).points, 1500);
      expect(await err(() => api.decideRedemption(pending.single.id, true)), 'REDEMPTION_ALREADY_DECIDED');
      expect((await api.points()).points, 1500);
    });

    test('ERP outage surfaces as an error, not data', () async {
      final api = DemoZaadApi();
      await api.login('0500000001', 'zaad1234');
      await api.simulateErpOutage(true);
      expect(await err(() => api.points()), 'ERP_UNAVAILABLE');
    });

    test('empty customer has no invoices', () async {
      final api = DemoZaadApi();
      await api.sendOtp('0500000002', 'register');
      final v = await api.verifyOtp('0500000002', 'register', '123456');
      await api.register(v, 'pass1234', 'ar');
      expect((await api.invoices(null)).items, isEmpty);
      expect((await api.points()).points, 0);
    });
  });
}
