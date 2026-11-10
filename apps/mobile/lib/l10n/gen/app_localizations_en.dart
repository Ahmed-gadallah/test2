// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Zaad Pharmacies';

  @override
  String get demoBanner => 'Demo mode — sample data, not connected to the ERP';

  @override
  String get welcomeTitle =>
      'Your points, invoices and offers.. all in one place!';

  @override
  String get welcomeSubtitle =>
      'Everything you need as a Zaad Pharmacies customer, in one app.';

  @override
  String get createAccount => 'Create account';

  @override
  String get login => 'Log in';

  @override
  String get mobileNumber => 'Mobile number';

  @override
  String get mobileHint => '05XXXXXXXX';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get continueLabel => 'Continue';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle =>
      'Enter the mobile number registered at Zaad branches';

  @override
  String get otpTitle => 'Verification code';

  @override
  String otpSubtitle(String mobile) {
    return 'Enter the 6-digit code sent to $mobile';
  }

  @override
  String get otpDemoHint => 'Demo code: 123456';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get verify => 'Verify';

  @override
  String get createPasswordTitle => 'Create a password';

  @override
  String get createPasswordSubtitle =>
      'At least 8 characters with a letter and a number';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get passwordRule => 'At least 8 characters with a letter and a number';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordUpdated => 'Password updated. Please log in.';

  @override
  String get privacyConsent =>
      'I agree to the Privacy Policy and the processing of my data to provide loyalty services.';

  @override
  String get privacyRequired => 'Please accept the privacy policy to continue';

  @override
  String hello(String name) {
    return 'Hello, $name';
  }

  @override
  String get helloNoName => 'Welcome';

  @override
  String get availablePoints => 'Available points';

  @override
  String get pointsUnit => 'points';

  @override
  String equivalentValue(String amount) {
    return 'Equivalent to $amount';
  }

  @override
  String rateExplanation(int points) {
    return 'Every $points points = 1 SAR';
  }

  @override
  String updatedAt(String time) {
    return 'Updated $time';
  }

  @override
  String get quickActions => 'Quick actions';

  @override
  String get myInvoices => 'My invoices';

  @override
  String get myPoints => 'My points';

  @override
  String get offers => 'Offers';

  @override
  String get myProfile => 'My profile';

  @override
  String get shopOnline => 'Shop online';

  @override
  String get latestOffers => 'Latest offers';

  @override
  String get seeAll => 'See all';

  @override
  String get navHome => 'Home';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navOffers => 'Offers';

  @override
  String get navProfile => 'Profile';

  @override
  String get pendingRedemptionBanner => 'Redemption request waiting for you';

  @override
  String get pendingRedemptionAction => 'Review';

  @override
  String get redemptionTitle => 'Loyalty redemption request';

  @override
  String get branch => 'Branch';

  @override
  String get pointsToRedeem => 'Points to redeem';

  @override
  String get discountValue => 'Discount value';

  @override
  String get reference => 'Reference';

  @override
  String get expiresIn => 'Expires in';

  @override
  String get confirmRedemption => 'Confirm redemption';

  @override
  String get rejectRequest => 'Reject request';

  @override
  String get confirmRedemptionReason => 'Confirm points redemption';

  @override
  String get redemptionCompleted => 'Redemption completed';

  @override
  String redemptionCompletedBody(String points, String amount) {
    return '$points points were redeemed for $amount.';
  }

  @override
  String get redemptionRejected => 'Request rejected';

  @override
  String get redemptionRejectedBody => 'No points were deducted.';

  @override
  String get redemptionExpired => 'This redemption request has expired.';

  @override
  String get redemptionFailed =>
      'The redemption could not be completed. No points were deducted. Please check with the cashier.';

  @override
  String get redemptionPending =>
      'Your decision was recorded. Waiting for confirmation from the branch system…';

  @override
  String get redemptionAlreadyDecided => 'This request was already handled.';

  @override
  String get rejectConfirmTitle => 'Reject this request?';

  @override
  String get rejectConfirmBody =>
      'The cashier will not apply the points discount.';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get pointsBalanceTitle => 'Points balance';

  @override
  String get pointsHistory => 'Points history';

  @override
  String get txEarned => 'Points earned';

  @override
  String get txRedeemed => 'Points redeemed';

  @override
  String get txRefund => 'Return adjustment';

  @override
  String get txManual => 'Points adjusted';

  @override
  String invoiceRef(String number) {
    return 'Invoice #$number';
  }

  @override
  String balanceAfter(String points) {
    return 'Balance: $points';
  }

  @override
  String get noPoints => 'You currently have no available loyalty points.';

  @override
  String get noHistory => 'No points activity yet.';

  @override
  String get onlineStoreNote =>
      'Online store purchases are not linked to loyalty points yet.';

  @override
  String get invoicesTitle => 'My invoices';

  @override
  String get noInvoices => 'You don\'t have any invoices yet.';

  @override
  String get invoiceNumber => 'Invoice number';

  @override
  String get date => 'Date';

  @override
  String get total => 'Total';

  @override
  String get statusFinished => 'Completed';

  @override
  String get statusRefunded => 'Returned';

  @override
  String get statusPartiallyRefunded => 'Partially returned';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get items => 'Items';

  @override
  String qty(int qty) {
    return 'Qty $qty';
  }

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discounts => 'Discounts';

  @override
  String get voucherDiscount => 'Voucher discount';

  @override
  String get pointsDiscount => 'Points discount';

  @override
  String get tax => 'VAT';

  @override
  String get pointsEarned => 'Points earned';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get payCash => 'Cash';

  @override
  String get payCard => 'Card';

  @override
  String get payMixed => 'Cash and card';

  @override
  String get offersTitle => 'Offers';

  @override
  String get noOffers => 'No offers right now. Check back soon.';

  @override
  String validUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String validFromTo(String from, String to) {
    return '$from – $to';
  }

  @override
  String get offerEnded => 'This offer has ended.';

  @override
  String get viewDetails => 'View details';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get profileTitle => 'My profile';

  @override
  String get fullName => 'Full name';

  @override
  String get customerId => 'Customer ID';

  @override
  String get profileReadOnly =>
      'To update your details, please visit any Zaad branch.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get biometricUnlock => 'Unlock with Face ID / fingerprint';

  @override
  String get biometricUnavailable => 'Not available on this device';

  @override
  String get logout => 'Log out';

  @override
  String get logoutConfirm => 'Log out of this device?';

  @override
  String get unlockTitle => 'Unlock Zaad';

  @override
  String get unlockAction => 'Unlock';

  @override
  String get demoTools => 'Demo tools';

  @override
  String get simulateCashier => 'Simulate cashier redemption (1,000 points)';

  @override
  String get simulateOutage => 'Simulate ERP outage';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errNetwork => 'No connection. Check your internet and try again.';

  @override
  String get errErpUnavailable =>
      'We\'re unable to retrieve your information right now. Please try again later.';

  @override
  String get errErpNotConfigured => 'This service is not connected yet.';

  @override
  String get errSessionExpired =>
      'Your session has expired. Please log in again.';

  @override
  String get errInvalidMobile =>
      'Enter a valid Saudi mobile number (05XXXXXXXX).';

  @override
  String get errNotRegistered =>
      'This mobile number is not registered with Zaad Pharmacies. Please visit one of our branches to register.';

  @override
  String get errAccountExists =>
      'An account already exists for this number. Please log in.';

  @override
  String get errNeedsSupport =>
      'We need to verify your account. Please visit a branch or contact customer service.';

  @override
  String get errNotEligible => 'This account type cannot use the app.';

  @override
  String get errOtpInvalid => 'Incorrect code.';

  @override
  String get errOtpExpired => 'The code has expired. Request a new one.';

  @override
  String get errOtpTooMany => 'Too many attempts. Request a new code.';

  @override
  String get errRateLimited => 'Too many requests. Please wait and try again.';

  @override
  String get errAccountLocked =>
      'Too many failed attempts. Try again in a few minutes, or reset your password.';

  @override
  String get errInvalidCredentials => 'Incorrect mobile number or password.';

  @override
  String get errPermission => 'You don\'t have permission to do this.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get retry => 'Retry';

  @override
  String get branchesTitle => 'Our Branches';

  @override
  String get branchesHomeSubtitle => 'Addresses, phone numbers and locations';

  @override
  String get branchesSearchHint => 'Search by name, city, district or address';

  @override
  String branchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count branches',
      one: '1 branch',
      zero: 'No branches',
    );
    return '$_temp0';
  }

  @override
  String get branchesNoResults => 'No branches match your search.';

  @override
  String get branchesEmpty => 'No branches are available right now.';

  @override
  String get viewLocation => 'View location';

  @override
  String get callBranch => 'Call branch';

  @override
  String get getDirections => 'Get directions';

  @override
  String get branchPhone => 'Branch phone';

  @override
  String get branchPhoneHint => 'For calls and delivery';

  @override
  String get branchAddress => 'Address';

  @override
  String get branchCity => 'City';

  @override
  String get branchDistrict => 'District';

  @override
  String get branchNotes => 'Notes';

  @override
  String get phoneUnavailable => 'Phone number not available';

  @override
  String get locationUnavailable => 'Location not available';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get branchLocation => 'Location';

  @override
  String get navBranches => 'Branches';

  @override
  String get copyNumber => 'Copy number';

  @override
  String get numberCopied => 'Number copied';

  @override
  String get copyFailed =>
      'Couldn\'t copy — long-press the number to select and copy it';

  @override
  String get callFromBrowserNote =>
      'Direct calling works in the Zaad app. In a browser, copy the number and call it from your phone app.';

  @override
  String get openInGoogleMaps => 'Open the branch location in Google Maps';

  @override
  String get noPhoneShort => 'No phone';

  @override
  String get noLocationShort => 'No location';
}
