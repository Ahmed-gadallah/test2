/// Build-time configuration via --dart-define.
///
///   DATA_SOURCE=demo   → self-contained demo data inside the app (for showcasing
///                        without a backend). A banner is always shown.
///   DATA_SOURCE=api    → talks to the Zaad backend at API_BASE_URL.
///   DEMO_TOOLS=true    → shows "simulate cashier" controls (dev/demo builds only).
class AppConfig {
  static const dataSource = String.fromEnvironment('DATA_SOURCE', defaultValue: 'demo');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');
  static const demoTools = bool.fromEnvironment('DEMO_TOOLS', defaultValue: true);

  static bool get isDemo => dataSource == 'demo';

  /// Polling interval for pending redemption requests while the app is open.
  /// Push is not guaranteed (spec §13.3), so the app never relies on it alone.
  static const redemptionPollInterval = Duration(seconds: 5);
}
