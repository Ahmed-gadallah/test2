// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'صيدليات زاد';

  @override
  String get demoBanner => 'وضع العرض — بيانات تجريبية غير مرتبطة بنظام ERP';

  @override
  String get welcomeTitle => 'نقاطك وفواتيرك وعروضك.. كلها في مكان واحد!';

  @override
  String get welcomeSubtitle =>
      'كل اللي تحتاجه كعميل لصيدليات زاد، في تطبيق واحد.';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get mobileNumber => 'رقم الجوال';

  @override
  String get mobileHint => '05XXXXXXXX';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get registerTitle => 'إنشاء حسابك';

  @override
  String get registerSubtitle => 'أدخل رقم الجوال المسجّل لدى فروع زاد';

  @override
  String get otpTitle => 'رمز التحقق';

  @override
  String otpSubtitle(String mobile) {
    return 'أدخل الرمز المكوّن من 6 أرقام المرسل إلى $mobile';
  }

  @override
  String get otpDemoHint => 'رمز العرض: 123456';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ث';
  }

  @override
  String get resendCode => 'إعادة إرسال الرمز';

  @override
  String get verify => 'تحقق';

  @override
  String get createPasswordTitle => 'أنشئ كلمة مرور';

  @override
  String get createPasswordSubtitle => '8 أحرف على الأقل وتتضمن حرفًا ورقمًا';

  @override
  String get passwordsDontMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get passwordRule => '8 أحرف على الأقل وتتضمن حرفًا ورقمًا';

  @override
  String get resetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordUpdated => 'تم تحديث كلمة المرور. يرجى تسجيل الدخول.';

  @override
  String get privacyConsent =>
      'أوافق على سياسة الخصوصية ومعالجة بياناتي لتقديم خدمات برنامج الولاء.';

  @override
  String get privacyRequired => 'يرجى الموافقة على سياسة الخصوصية للمتابعة';

  @override
  String hello(String name) {
    return 'أهلاً، $name';
  }

  @override
  String get helloNoName => 'أهلاً بك';

  @override
  String get availablePoints => 'النقاط المتاحة';

  @override
  String get pointsUnit => 'نقطة';

  @override
  String equivalentValue(String amount) {
    return 'تعادل $amount';
  }

  @override
  String rateExplanation(int points) {
    return 'كل $points نقطة = 1 ريال';
  }

  @override
  String updatedAt(String time) {
    return 'آخر تحديث $time';
  }

  @override
  String get quickActions => 'الوصول السريع';

  @override
  String get myInvoices => 'فواتيري';

  @override
  String get myPoints => 'نقاطي';

  @override
  String get offers => 'العروض';

  @override
  String get myProfile => 'ملفي';

  @override
  String get shopOnline => 'تسوّق أونلاين';

  @override
  String get latestOffers => 'أحدث العروض';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navInvoices => 'الفواتير';

  @override
  String get navOffers => 'العروض';

  @override
  String get navProfile => 'حسابي';

  @override
  String get pendingRedemptionBanner => 'لديك طلب استبدال نقاط بانتظار موافقتك';

  @override
  String get pendingRedemptionAction => 'مراجعة';

  @override
  String get redemptionTitle => 'طلب استبدال نقاط الولاء';

  @override
  String get branch => 'الفرع';

  @override
  String get pointsToRedeem => 'النقاط المطلوب استبدالها';

  @override
  String get discountValue => 'قيمة الخصم';

  @override
  String get reference => 'رقم الطلب';

  @override
  String get expiresIn => 'ينتهي خلال';

  @override
  String get confirmRedemption => 'تأكيد الاستبدال';

  @override
  String get rejectRequest => 'رفض الطلب';

  @override
  String get confirmRedemptionReason => 'تأكيد استبدال النقاط';

  @override
  String get redemptionCompleted => 'تم الاستبدال بنجاح';

  @override
  String redemptionCompletedBody(String points, String amount) {
    return 'تم استبدال $points نقطة مقابل $amount.';
  }

  @override
  String get redemptionRejected => 'تم رفض الطلب';

  @override
  String get redemptionRejectedBody => 'لم يتم خصم أي نقاط.';

  @override
  String get redemptionExpired => 'انتهت صلاحية طلب الاستبدال.';

  @override
  String get redemptionFailed =>
      'تعذّر إتمام الاستبدال ولم يتم خصم أي نقاط. يرجى مراجعة الكاشير.';

  @override
  String get redemptionPending =>
      'تم تسجيل قرارك. بانتظار التأكيد من نظام الفرع…';

  @override
  String get redemptionAlreadyDecided => 'تمت معالجة هذا الطلب مسبقًا.';

  @override
  String get rejectConfirmTitle => 'رفض هذا الطلب؟';

  @override
  String get rejectConfirmBody => 'لن يطبّق الكاشير خصم النقاط.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get done => 'تم';

  @override
  String get pointsBalanceTitle => 'رصيد النقاط';

  @override
  String get pointsHistory => 'سجل النقاط';

  @override
  String get txEarned => 'نقاط مكتسبة';

  @override
  String get txRedeemed => 'نقاط مستبدلة';

  @override
  String get txRefund => 'تعديل بسبب مرتجع';

  @override
  String get txManual => 'تعديل على النقاط';

  @override
  String invoiceRef(String number) {
    return 'فاتورة #$number';
  }

  @override
  String balanceAfter(String points) {
    return 'الرصيد: $points';
  }

  @override
  String get noPoints => 'لا توجد لديك نقاط ولاء متاحة حاليًا.';

  @override
  String get noHistory => 'لا توجد حركات نقاط بعد.';

  @override
  String get onlineStoreNote =>
      'مشتريات المتجر الإلكتروني غير مرتبطة بنقاط الولاء حاليًا.';

  @override
  String get invoicesTitle => 'فواتيري';

  @override
  String get noInvoices => 'لا توجد لديك فواتير بعد.';

  @override
  String get invoiceNumber => 'رقم الفاتورة';

  @override
  String get date => 'التاريخ';

  @override
  String get total => 'الإجمالي';

  @override
  String get statusFinished => 'مكتملة';

  @override
  String get statusRefunded => 'مرتجعة';

  @override
  String get statusPartiallyRefunded => 'مرتجعة جزئيًا';

  @override
  String get statusCancelled => 'ملغاة';

  @override
  String get items => 'الأصناف';

  @override
  String qty(int qty) {
    return 'الكمية $qty';
  }

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get discounts => 'الخصومات';

  @override
  String get voucherDiscount => 'خصم القسيمة';

  @override
  String get pointsDiscount => 'خصم النقاط';

  @override
  String get tax => 'ضريبة القيمة المضافة';

  @override
  String get pointsEarned => 'النقاط المكتسبة';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get payCash => 'نقدًا';

  @override
  String get payCard => 'بطاقة';

  @override
  String get payMixed => 'نقدًا وبطاقة';

  @override
  String get offersTitle => 'العروض';

  @override
  String get noOffers => 'لا توجد عروض حاليًا. تابعنا قريبًا.';

  @override
  String validUntil(String date) {
    return 'ساري حتى $date';
  }

  @override
  String validFromTo(String from, String to) {
    return '$from – $to';
  }

  @override
  String get offerEnded => 'انتهى هذا العرض.';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get noNotifications => 'لا توجد إشعارات بعد.';

  @override
  String get markAllRead => 'تحديد الكل كمقروء';

  @override
  String get profileTitle => 'ملفي';

  @override
  String get fullName => 'الاسم';

  @override
  String get customerId => 'رقم العميل';

  @override
  String get profileReadOnly => 'لتحديث بياناتك يرجى زيارة أي فرع من فروع زاد.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get biometricUnlock => 'فتح التطبيق بالبصمة / Face ID';

  @override
  String get biometricUnavailable => 'غير متاح على هذا الجهاز';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutConfirm => 'تسجيل الخروج من هذا الجهاز؟';

  @override
  String get unlockTitle => 'فتح تطبيق زاد';

  @override
  String get unlockAction => 'فتح';

  @override
  String get demoTools => 'أدوات العرض';

  @override
  String get simulateCashier => 'محاكاة طلب استبدال من الكاشير (1,000 نقطة)';

  @override
  String get simulateOutage => 'محاكاة تعطل نظام ERP';

  @override
  String get errGeneric => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';

  @override
  String get errNetwork => 'لا يوجد اتصال. تحقق من الإنترنت وحاول مجددًا.';

  @override
  String get errErpUnavailable =>
      'تعذّر استرجاع معلوماتك حاليًا. يرجى المحاولة لاحقًا.';

  @override
  String get errErpNotConfigured => 'هذه الخدمة غير مرتبطة بعد.';

  @override
  String get errSessionExpired => 'انتهت الجلسة. يرجى تسجيل الدخول مجددًا.';

  @override
  String get errInvalidMobile => 'أدخل رقم جوال سعودي صحيح (05XXXXXXXX).';

  @override
  String get errNotRegistered =>
      'رقم الجوال هذا غير مسجّل لدى صيدليات زاد. يرجى زيارة أحد فروعنا للتسجيل.';

  @override
  String get errAccountExists =>
      'يوجد حساب مسجّل بهذا الرقم. يرجى تسجيل الدخول.';

  @override
  String get errNeedsSupport =>
      'نحتاج للتحقق من حسابك. يرجى زيارة أحد الفروع أو التواصل مع خدمة العملاء.';

  @override
  String get errNotEligible => 'نوع هذا الحساب لا يمكنه استخدام التطبيق.';

  @override
  String get errOtpInvalid => 'الرمز غير صحيح.';

  @override
  String get errOtpExpired => 'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.';

  @override
  String get errOtpTooMany => 'محاولات كثيرة. اطلب رمزًا جديدًا.';

  @override
  String get errRateLimited => 'طلبات كثيرة. يرجى الانتظار ثم المحاولة.';

  @override
  String get errAccountLocked =>
      'محاولات خاطئة كثيرة. حاول بعد دقائق أو أعد تعيين كلمة المرور.';

  @override
  String get errInvalidCredentials => 'رقم الجوال أو كلمة المرور غير صحيحة.';

  @override
  String get errPermission => 'ليس لديك صلاحية لهذا الإجراء.';

  @override
  String get errNotFound => 'غير موجود.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get branchesTitle => 'فروع زاد';

  @override
  String get branchesHomeSubtitle => 'العناوين وأرقام التواصل ومواقع الفروع';

  @override
  String get branchesSearchHint => 'ابحث بالاسم أو المدينة أو الحي أو العنوان';

  @override
  String branchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرع',
      many: '$count فرعًا',
      few: '$count فروع',
      two: 'فرعان',
      one: 'فرع واحد',
      zero: 'لا توجد فروع',
    );
    return '$_temp0';
  }

  @override
  String get branchesNoResults => 'لا توجد فروع مطابقة لبحثك.';

  @override
  String get branchesEmpty => 'لا توجد فروع متاحة حاليًا.';

  @override
  String get viewLocation => 'عرض الموقع';

  @override
  String get callBranch => 'اتصال بالفرع';

  @override
  String get getDirections => 'الاتجاهات';

  @override
  String get branchPhone => 'رقم الفرع';

  @override
  String get branchPhoneHint => 'للاتصال والتوصيل';

  @override
  String get branchAddress => 'العنوان';

  @override
  String get branchCity => 'المدينة';

  @override
  String get branchDistrict => 'الحي';

  @override
  String get branchNotes => 'ملاحظات';

  @override
  String get phoneUnavailable => 'رقم الهاتف غير متوفر';

  @override
  String get locationUnavailable => 'الموقع غير متوفر';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get branchLocation => 'الموقع';

  @override
  String get navBranches => 'الفروع';
}
