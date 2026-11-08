import '../data/api.dart';
import '../l10n/gen/app_localizations.dart';

/// Maps backend error codes to localized messages. Raw server text is never shown.
String errorText(AppLocalizations t, Object error) {
  if (error is! ApiFailure) return t.errGeneric;
  return switch (error.code) {
    'NETWORK' => t.errNetwork,
    'ERP_UNAVAILABLE' => t.errErpUnavailable,
    'ERP_NOT_CONFIGURED' => t.errErpNotConfigured,
    'SESSION_EXPIRED' || 'UNAUTHENTICATED' => t.errSessionExpired,
    'INVALID_MOBILE' => t.errInvalidMobile,
    'MOBILE_NOT_REGISTERED' => t.errNotRegistered,
    'ACCOUNT_EXISTS' => t.errAccountExists,
    'ACCOUNT_NEEDS_SUPPORT' => t.errNeedsSupport,
    'ACCOUNT_NOT_ELIGIBLE' => t.errNotEligible,
    'OTP_INVALID' => t.errOtpInvalid,
    'OTP_EXPIRED' => t.errOtpExpired,
    'OTP_TOO_MANY_ATTEMPTS' => t.errOtpTooMany,
    'RATE_LIMITED' || 'OTP_COOLDOWN' => t.errRateLimited,
    'INVALID_CREDENTIALS' => t.errInvalidCredentials,
    'FORBIDDEN' => t.errPermission,
    'NOT_FOUND' => t.errNotFound,
    'REDEMPTION_EXPIRED' => t.redemptionExpired,
    'REDEMPTION_ALREADY_DECIDED' => t.redemptionAlreadyDecided,
    'REDEMPTION_DECISION_PENDING' => t.redemptionPending,
    _ => t.errGeneric,
  };
}
