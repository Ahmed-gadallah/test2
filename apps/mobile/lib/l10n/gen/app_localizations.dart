import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Zaad Pharmacies'**
  String get appName;

  /// No description provided for @demoBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo mode — sample data, not connected to the ERP'**
  String get demoBanner;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your points, invoices and offers.. all in one place!'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Everything you need as a Zaad Pharmacies customer, in one app.'**
  String get welcomeSubtitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get mobileNumber;

  /// No description provided for @mobileHint.
  ///
  /// In en, this message translates to:
  /// **'05XXXXXXXX'**
  String get mobileHint;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the mobile number registered at Zaad branches'**
  String get registerSubtitle;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpTitle;

  /// No description provided for @otpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {mobile}'**
  String otpSubtitle(String mobile);

  /// No description provided for @otpDemoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo code: 123456'**
  String get otpDemoHint;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @createPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a password'**
  String get createPasswordTitle;

  /// No description provided for @createPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with a letter and a number'**
  String get createPasswordSubtitle;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with a letter and a number'**
  String get passwordRule;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please log in.'**
  String get passwordUpdated;

  /// No description provided for @privacyConsent.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Privacy Policy and the processing of my data to provide loyalty services.'**
  String get privacyConsent;

  /// No description provided for @privacyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please accept the privacy policy to continue'**
  String get privacyRequired;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String hello(String name);

  /// No description provided for @helloNoName.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get helloNoName;

  /// No description provided for @availablePoints.
  ///
  /// In en, this message translates to:
  /// **'Available points'**
  String get availablePoints;

  /// No description provided for @pointsUnit.
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsUnit;

  /// No description provided for @equivalentValue.
  ///
  /// In en, this message translates to:
  /// **'Equivalent to {amount}'**
  String equivalentValue(String amount);

  /// No description provided for @rateExplanation.
  ///
  /// In en, this message translates to:
  /// **'Every {points} points = 1 SAR'**
  String rateExplanation(int points);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAt(String time);

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @myInvoices.
  ///
  /// In en, this message translates to:
  /// **'My invoices'**
  String get myInvoices;

  /// No description provided for @myPoints.
  ///
  /// In en, this message translates to:
  /// **'My points'**
  String get myPoints;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get myProfile;

  /// No description provided for @shopOnline.
  ///
  /// In en, this message translates to:
  /// **'Shop online'**
  String get shopOnline;

  /// No description provided for @latestOffers.
  ///
  /// In en, this message translates to:
  /// **'Latest offers'**
  String get latestOffers;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @navOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get navOffers;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @pendingRedemptionBanner.
  ///
  /// In en, this message translates to:
  /// **'Redemption request waiting for you'**
  String get pendingRedemptionBanner;

  /// No description provided for @pendingRedemptionAction.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get pendingRedemptionAction;

  /// No description provided for @redemptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Loyalty redemption request'**
  String get redemptionTitle;

  /// No description provided for @branch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branch;

  /// No description provided for @pointsToRedeem.
  ///
  /// In en, this message translates to:
  /// **'Points to redeem'**
  String get pointsToRedeem;

  /// No description provided for @discountValue.
  ///
  /// In en, this message translates to:
  /// **'Discount value'**
  String get discountValue;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @expiresIn.
  ///
  /// In en, this message translates to:
  /// **'Expires in'**
  String get expiresIn;

  /// No description provided for @confirmRedemption.
  ///
  /// In en, this message translates to:
  /// **'Confirm redemption'**
  String get confirmRedemption;

  /// No description provided for @rejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Reject request'**
  String get rejectRequest;

  /// No description provided for @confirmRedemptionReason.
  ///
  /// In en, this message translates to:
  /// **'Confirm points redemption'**
  String get confirmRedemptionReason;

  /// No description provided for @redemptionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Redemption completed'**
  String get redemptionCompleted;

  /// No description provided for @redemptionCompletedBody.
  ///
  /// In en, this message translates to:
  /// **'{points} points were redeemed for {amount}.'**
  String redemptionCompletedBody(String points, String amount);

  /// No description provided for @redemptionRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get redemptionRejected;

  /// No description provided for @redemptionRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'No points were deducted.'**
  String get redemptionRejectedBody;

  /// No description provided for @redemptionExpired.
  ///
  /// In en, this message translates to:
  /// **'This redemption request has expired.'**
  String get redemptionExpired;

  /// No description provided for @redemptionFailed.
  ///
  /// In en, this message translates to:
  /// **'The redemption could not be completed. No points were deducted. Please check with the cashier.'**
  String get redemptionFailed;

  /// No description provided for @redemptionPending.
  ///
  /// In en, this message translates to:
  /// **'Your decision was recorded. Waiting for confirmation from the branch system…'**
  String get redemptionPending;

  /// No description provided for @redemptionAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'This request was already handled.'**
  String get redemptionAlreadyDecided;

  /// No description provided for @rejectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject this request?'**
  String get rejectConfirmTitle;

  /// No description provided for @rejectConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The cashier will not apply the points discount.'**
  String get rejectConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @pointsBalanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Points balance'**
  String get pointsBalanceTitle;

  /// No description provided for @pointsHistory.
  ///
  /// In en, this message translates to:
  /// **'Points history'**
  String get pointsHistory;

  /// No description provided for @txEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get txEarned;

  /// No description provided for @txRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Points redeemed'**
  String get txRedeemed;

  /// No description provided for @txRefund.
  ///
  /// In en, this message translates to:
  /// **'Return adjustment'**
  String get txRefund;

  /// No description provided for @txManual.
  ///
  /// In en, this message translates to:
  /// **'Points adjusted'**
  String get txManual;

  /// No description provided for @invoiceRef.
  ///
  /// In en, this message translates to:
  /// **'Invoice #{number}'**
  String invoiceRef(String number);

  /// No description provided for @balanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance: {points}'**
  String balanceAfter(String points);

  /// No description provided for @noPoints.
  ///
  /// In en, this message translates to:
  /// **'You currently have no available loyalty points.'**
  String get noPoints;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No points activity yet.'**
  String get noHistory;

  /// No description provided for @onlineStoreNote.
  ///
  /// In en, this message translates to:
  /// **'Online store purchases are not linked to loyalty points yet.'**
  String get onlineStoreNote;

  /// No description provided for @invoicesTitle.
  ///
  /// In en, this message translates to:
  /// **'My invoices'**
  String get invoicesTitle;

  /// No description provided for @noInvoices.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any invoices yet.'**
  String get noInvoices;

  /// No description provided for @invoiceNumber.
  ///
  /// In en, this message translates to:
  /// **'Invoice number'**
  String get invoiceNumber;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @statusFinished.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusFinished;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statusRefunded;

  /// No description provided for @statusPartiallyRefunded.
  ///
  /// In en, this message translates to:
  /// **'Partially returned'**
  String get statusPartiallyRefunded;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @qty.
  ///
  /// In en, this message translates to:
  /// **'Qty {qty}'**
  String qty(int qty);

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discounts.
  ///
  /// In en, this message translates to:
  /// **'Discounts'**
  String get discounts;

  /// No description provided for @voucherDiscount.
  ///
  /// In en, this message translates to:
  /// **'Voucher discount'**
  String get voucherDiscount;

  /// No description provided for @pointsDiscount.
  ///
  /// In en, this message translates to:
  /// **'Points discount'**
  String get pointsDiscount;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'VAT'**
  String get tax;

  /// No description provided for @pointsEarned.
  ///
  /// In en, this message translates to:
  /// **'Points earned'**
  String get pointsEarned;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethod;

  /// No description provided for @payCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payCash;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payMixed.
  ///
  /// In en, this message translates to:
  /// **'Cash and card'**
  String get payMixed;

  /// No description provided for @offersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offersTitle;

  /// No description provided for @noOffers.
  ///
  /// In en, this message translates to:
  /// **'No offers right now. Check back soon.'**
  String get noOffers;

  /// No description provided for @validUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String validUntil(String date);

  /// No description provided for @validFromTo.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String validFromTo(String from, String to);

  /// No description provided for @offerEnded.
  ///
  /// In en, this message translates to:
  /// **'This offer has ended.'**
  String get offerEnded;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profileTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @customerId.
  ///
  /// In en, this message translates to:
  /// **'Customer ID'**
  String get customerId;

  /// No description provided for @profileReadOnly.
  ///
  /// In en, this message translates to:
  /// **'To update your details, please visit any Zaad branch.'**
  String get profileReadOnly;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID / fingerprint'**
  String get biometricUnlock;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get biometricUnavailable;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out of this device?'**
  String get logoutConfirm;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Zaad'**
  String get unlockTitle;

  /// No description provided for @unlockAction.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlockAction;

  /// No description provided for @demoTools.
  ///
  /// In en, this message translates to:
  /// **'Demo tools'**
  String get demoTools;

  /// No description provided for @simulateCashier.
  ///
  /// In en, this message translates to:
  /// **'Simulate cashier redemption (1,000 points)'**
  String get simulateCashier;

  /// No description provided for @simulateOutage.
  ///
  /// In en, this message translates to:
  /// **'Simulate ERP outage'**
  String get simulateOutage;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get errNetwork;

  /// No description provided for @errErpUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We\'re unable to retrieve your information right now. Please try again later.'**
  String get errErpUnavailable;

  /// No description provided for @errErpNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'This service is not connected yet.'**
  String get errErpNotConfigured;

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please log in again.'**
  String get errSessionExpired;

  /// No description provided for @errInvalidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Saudi mobile number (05XXXXXXXX).'**
  String get errInvalidMobile;

  /// No description provided for @errNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'This mobile number is not registered with Zaad Pharmacies. Please visit one of our branches to register.'**
  String get errNotRegistered;

  /// No description provided for @errAccountExists.
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this number. Please log in.'**
  String get errAccountExists;

  /// No description provided for @errNeedsSupport.
  ///
  /// In en, this message translates to:
  /// **'We need to verify your account. Please visit a branch or contact customer service.'**
  String get errNeedsSupport;

  /// No description provided for @errNotEligible.
  ///
  /// In en, this message translates to:
  /// **'This account type cannot use the app.'**
  String get errNotEligible;

  /// No description provided for @errOtpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Incorrect code.'**
  String get errOtpInvalid;

  /// No description provided for @errOtpExpired.
  ///
  /// In en, this message translates to:
  /// **'The code has expired. Request a new one.'**
  String get errOtpExpired;

  /// No description provided for @errOtpTooMany.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Request a new code.'**
  String get errOtpTooMany;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait and try again.'**
  String get errRateLimited;

  /// No description provided for @errAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Try again in a few minutes, or reset your password.'**
  String get errAccountLocked;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect mobile number or password.'**
  String get errInvalidCredentials;

  /// No description provided for @errPermission.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get errPermission;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @branchesTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Branches'**
  String get branchesTitle;

  /// No description provided for @branchesHomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Addresses, phone numbers and locations'**
  String get branchesHomeSubtitle;

  /// No description provided for @branchesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, city, district or address'**
  String get branchesSearchHint;

  /// No description provided for @branchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No branches} =1{1 branch} other{{count} branches}}'**
  String branchesCount(int count);

  /// No description provided for @branchesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No branches match your search.'**
  String get branchesNoResults;

  /// No description provided for @branchesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No branches are available right now.'**
  String get branchesEmpty;

  /// No description provided for @viewLocation.
  ///
  /// In en, this message translates to:
  /// **'View location'**
  String get viewLocation;

  /// No description provided for @callBranch.
  ///
  /// In en, this message translates to:
  /// **'Call branch'**
  String get callBranch;

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get directions'**
  String get getDirections;

  /// No description provided for @branchPhone.
  ///
  /// In en, this message translates to:
  /// **'Branch phone'**
  String get branchPhone;

  /// No description provided for @branchPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'For calls and delivery'**
  String get branchPhoneHint;

  /// No description provided for @branchAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get branchAddress;

  /// No description provided for @branchCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get branchCity;

  /// No description provided for @branchDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get branchDistrict;

  /// No description provided for @branchNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get branchNotes;

  /// No description provided for @phoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Phone number not available'**
  String get phoneUnavailable;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location not available'**
  String get locationUnavailable;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @branchLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get branchLocation;

  /// No description provided for @navBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get navBranches;

  /// No description provided for @copyNumber.
  ///
  /// In en, this message translates to:
  /// **'Copy number'**
  String get copyNumber;

  /// No description provided for @numberCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get numberCopied;

  /// No description provided for @copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t copy — long-press the number to select and copy it'**
  String get copyFailed;

  /// No description provided for @callFromBrowserNote.
  ///
  /// In en, this message translates to:
  /// **'Direct calling works in the Zaad app. In a browser, copy the number and call it from your phone app.'**
  String get callFromBrowserNote;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
