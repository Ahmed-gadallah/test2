import 'package:flutter/foundation.dart';

/// Build-time configuration via --dart-define.
///
///   DATA_SOURCE=api    (default) talks to the Zaad backend at API_BASE_URL.
///   DATA_SOURCE=demo   self-contained fictional data, for showcasing only. Must be
///                      requested explicitly; a banner is always shown.
///   DEMO_TOOLS=true    shows "simulate cashier" controls. Ignored in release API builds.
///
/// Safe by default: a build without flags is a real API build, and a release API
/// build refuses to start unless API_BASE_URL is HTTPS (see [configError]).
class AppConfig {
  static const dataSource = String.fromEnvironment('DATA_SOURCE', defaultValue: 'api');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000/api/v1');
  static const _demoTools = bool.fromEnvironment('DEMO_TOOLS', defaultValue: false);

  static bool get isDemo => dataSource == 'demo';

  /// Dev/demo controls never appear in a release build that talks to a real backend.
  static bool get demoTools => _demoTools && (isDemo || !kReleaseMode);

  /// Polling interval for pending redemption requests while the app is open.
  /// Push is not guaranteed (spec §13.3), so the app never relies on it alone.
  static const redemptionPollInterval = Duration(seconds: 5);

  /// Non-null when this build must not run. Checked once at startup.
  static String? get configError {
    if (dataSource != 'api' && dataSource != 'demo') return 'Unknown DATA_SOURCE "$dataSource"';
    if (!isDemo && kReleaseMode && !apiBaseUrl.startsWith('https://')) {
      return 'Release builds require an https:// API_BASE_URL';
    }
    return null;
  }
}
