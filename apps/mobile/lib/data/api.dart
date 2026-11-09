import 'models.dart';

/// Error returned by the backend contract. `code` is stable; the UI maps it to
/// a localized message (see core/error_text.dart). `status == 0` = network error.
class ApiFailure implements Exception {
  final String code;
  final int status;
  final Map<String, dynamic>? details;
  const ApiFailure(this.code, {this.status = 0, this.details});
  @override
  String toString() => 'ApiFailure($code, $status)';
}

/// Everything the app can ask of the backend. Two implementations:
///  - HttpZaadApi: the real backend (apps/backend).
///  - DemoZaadApi: in-memory, for the self-contained demo build only.
abstract class ZaadApi {
  // auth
  Future<void> checkMobile(String mobile);
  Future<OtpInfo> sendOtp(String mobile, String purpose);
  Future<String> verifyOtp(String mobile, String purpose, String code);
  Future<AuthTokens> register(String verificationToken, String password, String language);
  Future<AuthTokens> login(String mobile, String password);
  Future<void> resetPassword(String verificationToken, String password);
  Future<void> logout();

  // customer
  Future<Profile> profile();
  Future<PointsBalance> points({bool refresh = false});
  Future<PageResult<PointsEntry>> pointsHistory(String? cursor);
  Future<PageResult<InvoiceSummary>> invoices(String? cursor);
  Future<InvoiceDetail> invoice(String id);

  // offers & notifications
  Future<List<Offer>> offers();
  Future<Offer> offer(String id);

  /// Active Zaad branches (Branch Locator). Public: works before login too.
  Future<List<Branch>> branches();
  Future<(List<AppNotification>, int unread)> notifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();

  // redemption
  Future<List<Redemption>> pendingRedemptions();
  Future<Redemption> redemption(String id);
  Future<Redemption> decideRedemption(String id, bool approve);

  // demo / dev tools (no-ops in production builds)
  Future<void> simulateCashierRedemption(String mobile, int points);
  Future<void> simulateErpOutage(bool on);
}
