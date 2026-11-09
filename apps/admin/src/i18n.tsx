import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

const ar = {
  appName: 'لوحة إدارة صيدليات زاد',
  demoBanner: 'وضع العرض — بيانات تجريبية غير مرتبطة بنظام ERP',
  language: 'English',
  signIn: 'تسجيل الدخول',
  signInTitle: 'تسجيل دخول الإدارة',
  signInSub: 'لموظفي صيدليات زاد المصرّح لهم فقط',
  email: 'البريد الإلكتروني',
  password: 'كلمة المرور',
  demoAccounts: 'حسابات العرض (كلمة المرور: Demo12345678)',
  logout: 'تسجيل الخروج',
  nav: {
    overview: 'نظرة عامة', offers: 'العروض', campaigns: 'الحملات والإشعارات', customers: 'العملاء',
    redemptions: 'طلبات الاستبدال', branches: 'الفروع', admins: 'المشرفون', audit: 'سجل العمليات',
  },
  roles: { super_admin: 'مدير النظام', marketing_admin: 'مسؤول تسويق', customer_support: 'خدمة العملاء' },
  overview: {
    title: 'نظرة عامة', registered: 'العملاء المسجّلون', new7d: 'جدد آخر 7 أيام', activeOffers: 'عروض نشطة', scheduled: 'مجدولة', drafts: 'مسودات',
    pendingRedemptions: 'طلبات استبدال معلّقة', completedRedemptions: 'استبدالات مكتملة', recentCampaigns: 'آخر الحملات', recentRedemptions: 'آخر طلبات الاستبدال',
    erpNote: 'كل أرقام النقاط والفواتير تأتي من نظام ERP مباشرة؛ اللوحة لا تحسب ولا تعدّل أي نقاط.',
  },
  offers: {
    title: 'العروض', new: 'عرض جديد', edit: 'تعديل العرض', all: 'الكل', empty: 'لا توجد عروض بعد.',
    titleAr: 'العنوان (عربي)', titleEn: 'العنوان (إنجليزي)', descAr: 'الوصف (عربي)', descEn: 'الوصف (إنجليزي)', start: 'يبدأ', end: 'ينتهي',
    image: 'رابط الصورة (اختياري)', ctaAr: 'نص الزر (عربي، اختياري)', ctaEn: 'نص الزر (إنجليزي، اختياري)', link: 'رابط الزر (اختياري)',
    hostsNote: 'الروابط والصور مسموحة من نطاقات زاد المعتمدة فقط (مثل zaadonline.com).',
    save: 'حفظ كمسودة', saveChanges: 'حفظ التعديلات', publish: 'نشر', archive: 'أرشفة', resend: 'إعادة إرسال الإشعار', preview: 'معاينة في التطبيق',
    publishConfirm: 'نشر هذا العرض؟', publishBodyNow: 'سيظهر العرض للعملاء فورًا وسيُرسل إشعار لكل العملاء المسجّلين. لا يمكن إلغاء الإشعار بعد إرساله.',
    publishBodyLater: 'العرض مجدول؛ سيظهر ويُرسل الإشعار تلقائيًا عند موعد البدء.',
    archiveConfirm: 'أرشفة هذا العرض؟', archiveBody: 'سيختفي العرض من التطبيق. لا يمكن تعديله بعد الأرشفة.',
    resendConfirm: 'إعادة إرسال الإشعار؟', resendBody: 'سيصل إشعار جديد لكل العملاء المسجّلين. استخدمها بحذر لتجنب إزعاج العملاء.',
    editNote: 'تعديل عرض منشور لا يعيد إرسال الإشعار.', validity: 'الصلاحية', notified: 'أُرسل الإشعار', notNotified: 'لم يُرسل إشعار',
    sent: 'تم إرسال الإشعار إلى {n} عميل', published: 'تم النشر', saved: 'تم الحفظ', archived: 'تمت الأرشفة',
  },
  status: { draft: 'مسودة', scheduled: 'مجدول', active: 'نشط', expired: 'منتهي', archived: 'مؤرشف' },
  campaigns: {
    title: 'الحملات والإشعارات', offer: 'العرض', kind: 'النوع', publishKind: 'نشر', resendKind: 'إعادة إرسال', date: 'التاريخ',
    recipients: 'المستلمون', accepted: 'قبلها مزوّد الإشعارات', failed: 'فشل الإرسال', opened: 'فُتحت',
    note: 'تنبيه: "قبلها المزوّد" تعني أن خدمة الإشعارات استلمت الرسالة، وليست تأكيدًا بوصولها للجهاز. "فُتحت" تُحسب عند فتح العميل للإشعار داخل التطبيق.',
    empty: 'لا توجد حملات بعد.', openRate: 'نسبة الفتح',
  },
  customers: {
    title: 'العملاء', searchBy: 'ابحث برقم الجوال أو رقم العميل', mobile: 'رقم الجوال', id: 'رقم العميل', search: 'بحث',
    noResults: 'لا يوجد عميل بهذا الرقم في نظام ERP.', multiple: 'أكثر من سجل يطابق هذا الرقم — التسجيل في التطبيق موقوف لهذا الرقم حتى تتم المراجعة.',
    appAccount: 'حساب التطبيق', registered: 'مسجّل', notRegistered: 'غير مسجّل', notEligible: 'حساب مؤسسي — غير مؤهل للتطبيق',
    readOnly: 'عرض فقط — تعديل بيانات العميل أو النقاط يتم من نظام ERP.', points: 'النقاط', invoices: 'الفواتير', balance: 'الرصيد الحالي',
    ledger: 'سجل النقاط', balanceAfter: 'الرصيد بعد الحركة', loadMore: 'تحميل المزيد', open: 'عرض', back: 'رجوع',
    tx: { earned: 'مكتسبة', redeemed: 'مستبدلة', refund_adjustment: 'تعديل مرتجع', manual_adjustment: 'تعديل يدوي' },
    invoice: 'فاتورة', branch: 'الفرع', total: 'الإجمالي', items: 'الأصناف', qty: 'الكمية', price: 'السعر', pointsEarned: 'النقاط المكتسبة',
    payment: 'طريقة الدفع', pay: { cash: 'نقدًا', card: 'بطاقة', cash_and_card: 'نقدًا وبطاقة' },
    inv: { finished: 'مكتملة', refunded: 'مرتجعة', partially_refunded: 'مرتجعة جزئيًا', cancelled: 'ملغاة' },
  },
  redemptions: {
    title: 'طلبات الاستبدال', ref: 'رقم الطلب', customer: 'العميل', points: 'النقاط', value: 'القيمة', status: 'الحالة', created: 'وقت الطلب', all: 'الكل',
    st: { pending: 'معلّق', approved: 'موافق عليه', rejected: 'مرفوض', expired: 'منتهي', completed: 'مكتمل', failed: 'فشل' },
    note: 'الخصم الفعلي للنقاط يتم في نظام ERP فقط. هذه الشاشة للمتابعة.', empty: 'لا توجد طلبات.',
  },
  admins: {
    title: 'المشرفون', add: 'إضافة مشرف', name: 'الاسم', role: 'الصلاحية', status: 'الحالة', active: 'نشط', inactive: 'موقوف',
    deactivate: 'إيقاف', activate: 'تفعيل', created: 'تمت إضافة المشرف', you: '(أنت)', pwRule: '12 حرفًا على الأقل، حروف وأرقام',
    permissions: {
      super_admin: 'كل الصلاحيات، بما فيها إدارة المشرفين وسجل العمليات.',
      marketing_admin: 'العروض والحملات والإشعارات وبيانات الفروع فقط. لا يرى بيانات العملاء.',
      customer_support: 'عرض بيانات العملاء والنقاط والفواتير وطلبات الاستبدال — قراءة فقط.',
    },
  },
  branches: {
    title: 'الفروع', sub: 'بيانات "فروع زاد" التي تظهر للعملاء في التطبيق. الفروع غير النشطة لا تظهر للعملاء.',
    add: 'إضافة فرع', edit: 'تعديل الفرع', import: 'استيراد من Excel', total: 'كل الفروع', active: 'نشط', inactive: 'غير نشط',
    noPhone: 'بدون رقم هاتف', noLocation: 'بدون رابط موقع', all: 'الكل', missing: 'بيانات ناقصة', search: 'ابحث بالاسم أو الرقم أو المدينة أو الحي',
    id: 'رقم الفرع', idHint: 'Branch ID من ملف الفروع (نفس رقم الفرع في ERP). لا يمكن تغييره لاحقًا.',
    nameAr: 'اسم الفرع (عربي)', nameEn: 'اسم الفرع (إنجليزي)', city: 'المدينة', district: 'الحي / المنطقة',
    addressAr: 'العنوان بالتفصيل (عربي)', addressEn: 'العنوان (إنجليزي)', phone: 'رقم هاتف الفرع', phoneHint: 'رقم واحد فقط للاتصال والتوصيل. اتركه فارغًا إن لم يوجد.',
    maps: 'رابط الموقع (Google Maps)', mapsHint: 'رابط https من Google Maps كما هو. لا يتم استنتاج أي موقع بديل.', notes: 'ملاحظات (اختياري)',
    status: 'الحالة', location: 'الموقع', open: 'فتح', empty: 'لا توجد فروع بعد. ابدأ باستيراد ملف الفروع.', noResults: 'لا توجد نتائج.',
    activate: 'تفعيل', deactivate: 'إيقاف', saved: 'تم حفظ الفرع', created: 'تمت إضافة الفرع',
    importTitle: 'استيراد ملف الفروع', importNote: 'ارفع ملف Excel (قالب فروع زاد). يتم الاستيراد برقم الفرع: إعادة رفع نفس الملف لا تكرر الفروع. أي خطأ في صف يوقف الاستيراد كله.',
    chooseFile: 'اختر ملف .xlsx', check: 'فحص الملف', apply: 'تطبيق الاستيراد', applied: 'تم الاستيراد',
    willCreate: 'فروع جديدة', willUpdate: 'فروع ستُحدَّث', unchanged: 'بدون تغيير', notInFile: 'موجودة في النظام وليست في الملف (لن تُحذف)',
    errors: 'أخطاء — يجب تصحيحها في الملف', warnings: 'تنبيهات — سيتم الاستيراد مع ترك الحقل فارغًا', row: 'صف', reimportNote: 'ملاحظة: الاستيراد يكتب فوق أي تعديل يدوي على نفس الفرع، لأن الملف هو المصدر المعتمد.',
  },
  audit: { title: 'سجل العمليات', when: 'الوقت', actor: 'المنفّذ', action: 'العملية', resource: 'العنصر', system: 'النظام', customer: 'عميل' },
  common: { cancel: 'إلغاء', confirm: 'تأكيد', loading: 'جارٍ التحميل…', retry: 'إعادة المحاولة', close: 'إغلاق', create: 'إنشاء', sar: 'ر.س', actions: 'إجراءات' },
  errors: {
    NETWORK: 'تعذّر الاتصال بالخادم. تأكد أن الـ backend يعمل.', INVALID_CREDENTIALS: 'البريد أو كلمة المرور غير صحيحة.',
    ACCOUNT_LOCKED: 'تم إيقاف الحساب مؤقتًا بعد محاولات خاطئة. حاول بعد 15 دقيقة.', RATE_LIMITED: 'طلبات كثيرة. انتظر قليلًا.',
    FORBIDDEN: 'ليس لديك صلاحية لهذا الإجراء.', NOT_FOUND: 'غير موجود.', ERP_UNAVAILABLE: 'نظام ERP غير متاح حاليًا.',
    OFFER_INVALID_STATE: 'لا يمكن تنفيذ هذا الإجراء على العرض في حالته الحالية.', ACCOUNT_EXISTS: 'يوجد مشرف بهذا البريد.',
    INVALID_MOBILE: 'رقم جوال غير صحيح.', SESSION_EXPIRED: 'انتهت الجلسة. سجّل الدخول مجددًا.', UNAUTHENTICATED: 'انتهت الجلسة. سجّل الدخول مجددًا.',
    VALIDATION_FAILED: 'بيانات غير صحيحة', DEMO_IMPORT: 'استيراد ملف Excel يحتاج الخادم الحقيقي — غير متاح في وضع العرض. يمكنك تعديل الفروع وتفعيلها هنا.', generic: 'حدث خطأ غير متوقع.',
  },
};

type Dict = typeof ar;

const en: Dict = {
  appName: 'Zaad Pharmacies Admin',
  demoBanner: 'Demo mode — sample data, not connected to the ERP',
  language: 'العربية',
  signIn: 'Sign in',
  signInTitle: 'Admin sign in',
  signInSub: 'For authorised Zaad Pharmacies staff only',
  email: 'Email',
  password: 'Password',
  demoAccounts: 'Demo accounts (password: Demo12345678)',
  logout: 'Sign out',
  nav: { overview: 'Overview', offers: 'Offers', campaigns: 'Campaigns & notifications', customers: 'Customers', redemptions: 'Redemptions', branches: 'Branches', admins: 'Administrators', audit: 'Audit log' },
  roles: { super_admin: 'Super admin', marketing_admin: 'Marketing admin', customer_support: 'Customer support' },
  overview: {
    title: 'Overview', registered: 'Registered customers', new7d: 'New in last 7 days', activeOffers: 'Active offers', scheduled: 'Scheduled', drafts: 'Drafts',
    pendingRedemptions: 'Pending redemptions', completedRedemptions: 'Completed redemptions', recentCampaigns: 'Recent campaigns', recentRedemptions: 'Recent redemptions',
    erpNote: 'All points and invoice figures come directly from the ERP; this dashboard never calculates or changes points.',
  },
  offers: {
    title: 'Offers', new: 'New offer', edit: 'Edit offer', all: 'All', empty: 'No offers yet.',
    titleAr: 'Title (Arabic)', titleEn: 'Title (English)', descAr: 'Description (Arabic)', descEn: 'Description (English)', start: 'Starts', end: 'Ends',
    image: 'Image URL (optional)', ctaAr: 'Button label (Arabic, optional)', ctaEn: 'Button label (English, optional)', link: 'Button link (optional)',
    hostsNote: 'Links and images are only allowed from approved Zaad domains (e.g. zaadonline.com).',
    save: 'Save as draft', saveChanges: 'Save changes', publish: 'Publish', archive: 'Archive', resend: 'Resend notification', preview: 'In-app preview',
    publishConfirm: 'Publish this offer?', publishBodyNow: 'Customers will see it immediately and every registered customer gets a push notification. A sent notification cannot be recalled.',
    publishBodyLater: 'This offer is scheduled; it goes live and notifies customers automatically at its start time.',
    archiveConfirm: 'Archive this offer?', archiveBody: 'It disappears from the app and can no longer be edited.',
    resendConfirm: 'Resend the notification?', resendBody: 'Every registered customer gets a new notification. Use sparingly to avoid annoying customers.',
    editNote: 'Editing a published offer does not resend its notification.', validity: 'Validity', notified: 'Notification sent', notNotified: 'Not notified',
    sent: 'Notification sent to {n} customers', published: 'Published', saved: 'Saved', archived: 'Archived',
  },
  status: { draft: 'Draft', scheduled: 'Scheduled', active: 'Active', expired: 'Expired', archived: 'Archived' },
  campaigns: {
    title: 'Campaigns & notifications', offer: 'Offer', kind: 'Type', publishKind: 'Publish', resendKind: 'Resend', date: 'Date',
    recipients: 'Recipients', accepted: 'Accepted by provider', failed: 'Failed', opened: 'Opened',
    note: 'Note: "accepted by provider" means the push service received the message — it is not confirmation of delivery to the device. "Opened" counts customers who opened the notification in the app.',
    empty: 'No campaigns yet.', openRate: 'Open rate',
  },
  customers: {
    title: 'Customers', searchBy: 'Search by mobile number or customer ID', mobile: 'Mobile', id: 'Customer ID', search: 'Search',
    noResults: 'No customer with this number in the ERP.', multiple: 'More than one record matches this number — app registration is blocked for it until reviewed.',
    appAccount: 'App account', registered: 'Registered', notRegistered: 'Not registered', notEligible: 'Institutional account — not eligible for the app',
    readOnly: 'Read only — customer data and points are changed in the ERP.', points: 'Points', invoices: 'Invoices', balance: 'Current balance',
    ledger: 'Points ledger', balanceAfter: 'Balance after', loadMore: 'Load more', open: 'View', back: 'Back',
    tx: { earned: 'Earned', redeemed: 'Redeemed', refund_adjustment: 'Refund adjustment', manual_adjustment: 'Manual adjustment' },
    invoice: 'Invoice', branch: 'Branch', total: 'Total', items: 'Items', qty: 'Qty', price: 'Price', pointsEarned: 'Points earned',
    payment: 'Payment', pay: { cash: 'Cash', card: 'Card', cash_and_card: 'Cash and card' },
    inv: { finished: 'Completed', refunded: 'Refunded', partially_refunded: 'Partially refunded', cancelled: 'Cancelled' },
  },
  redemptions: {
    title: 'Redemption requests', ref: 'Reference', customer: 'Customer', points: 'Points', value: 'Value', status: 'Status', created: 'Requested', all: 'All',
    st: { pending: 'Pending', approved: 'Approved', rejected: 'Rejected', expired: 'Expired', completed: 'Completed', failed: 'Failed' },
    note: 'Points are only ever deducted by the ERP. This screen is for monitoring.', empty: 'No requests.',
  },
  admins: {
    title: 'Administrators', add: 'Add administrator', name: 'Name', role: 'Role', status: 'Status', active: 'Active', inactive: 'Deactivated',
    deactivate: 'Deactivate', activate: 'Activate', created: 'Administrator added', you: '(you)', pwRule: 'At least 12 characters, letters and digits',
    permissions: {
      super_admin: 'Everything, including administrators and the audit log.',
      marketing_admin: 'Offers, campaigns, notifications and branch details only. Cannot see customer data.',
      customer_support: 'View customers, points, invoices and redemptions — read only.',
    },
  },
  branches: {
    title: 'Branches', sub: 'The "Our Branches" directory customers see in the app. Inactive branches are hidden from customers.',
    add: 'Add branch', edit: 'Edit branch', import: 'Import from Excel', total: 'All branches', active: 'Active', inactive: 'Inactive',
    noPhone: 'No phone number', noLocation: 'No location link', all: 'All', missing: 'Missing data', search: 'Search by name, ID, city or district',
    id: 'Branch ID', idHint: 'Branch ID from the branches sheet (same as the ERP branch id). Cannot be changed later.',
    nameAr: 'Branch name (Arabic)', nameEn: 'Branch name (English)', city: 'City', district: 'District / area',
    addressAr: 'Full address (Arabic)', addressEn: 'Address (English)', phone: 'Branch phone', phoneHint: 'ONE number for calls and delivery. Leave empty if there is none.',
    maps: 'Location link (Google Maps)', mapsHint: 'An https Google Maps link, stored as-is. No other location is ever derived.', notes: 'Notes (optional)',
    status: 'Status', location: 'Location', open: 'Open', empty: 'No branches yet. Start by importing the branches sheet.', noResults: 'No results.',
    activate: 'Activate', deactivate: 'Deactivate', saved: 'Branch saved', created: 'Branch added',
    importTitle: 'Import the branches sheet', importNote: 'Upload the Excel file (Zaad branches template). Rows are matched by Branch ID: uploading the same file again never duplicates branches. Any row error stops the whole import.',
    chooseFile: 'Choose an .xlsx file', check: 'Check file', apply: 'Apply import', applied: 'Import applied',
    willCreate: 'New branches', willUpdate: 'Branches to update', unchanged: 'Unchanged', notInFile: 'In the system but not in the file (kept, not deleted)',
    errors: 'Errors — fix these in the file', warnings: 'Warnings — imported with the field left empty', row: 'Row', reimportNote: 'Note: importing overwrites manual edits to the same branch, because the sheet is the source of truth.',
  },
  audit: { title: 'Audit log', when: 'Time', actor: 'Actor', action: 'Action', resource: 'Resource', system: 'System', customer: 'Customer' },
  common: { cancel: 'Cancel', confirm: 'Confirm', loading: 'Loading…', retry: 'Retry', close: 'Close', create: 'Create', sar: 'SAR', actions: 'Actions' },
  errors: {
    NETWORK: 'Cannot reach the server. Make sure the backend is running.', INVALID_CREDENTIALS: 'Incorrect email or password.',
    ACCOUNT_LOCKED: 'Account temporarily locked after failed attempts. Try again in 15 minutes.', RATE_LIMITED: 'Too many requests. Please wait.',
    FORBIDDEN: 'You do not have permission for this action.', NOT_FOUND: 'Not found.', ERP_UNAVAILABLE: 'The ERP is unavailable right now.',
    OFFER_INVALID_STATE: 'This action is not allowed for the offer in its current state.', ACCOUNT_EXISTS: 'An administrator with this email already exists.',
    INVALID_MOBILE: 'Invalid mobile number.', SESSION_EXPIRED: 'Session expired. Please sign in again.', UNAUTHENTICATED: 'Session expired. Please sign in again.',
    VALIDATION_FAILED: 'Invalid data', DEMO_IMPORT: 'Importing an Excel file needs the real backend — not available in the demo. You can still edit and activate branches here.', generic: 'Something went wrong.',
  },
};

export type Lang = 'ar' | 'en';

interface I18n {
  lang: Lang;
  t: Dict;
  setLang: (l: Lang) => void;
  num: (n: number) => string;
  sar: (n: number) => string;
  date: (s: string | null | undefined) => string;
  dateTime: (s: string | null | undefined) => string;
  /** Arrow glyphs that point the right way for the reading direction. */
  fwd: string;
  back: string;
}

const Ctx = createContext<I18n | null>(null);
const latin = (s: string) => s.replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));

export function I18nProvider({ children }: { children: ReactNode }) {
  const [lang, setLangState] = useState<Lang>(() => {
    try {
      return (localStorage.getItem('zaad.admin.lang') as Lang) || 'ar';
    } catch {
      return 'ar';
    }
  });
  useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
  }, [lang]);
  const value = useMemo<I18n>(() => {
    const locale = lang === 'ar' ? 'ar-SA-u-nu-latn-ca-gregory' : 'en-GB';
    return {
      lang,
      t: lang === 'ar' ? ar : en,
      setLang: (l) => {
        try {
          localStorage.setItem('zaad.admin.lang', l);
        } catch {
          /* private mode */
        }
        setLangState(l);
      },
      fwd: lang === 'ar' ? '‹' : '›',
      back: lang === 'ar' ? '›' : '‹',
      num: (n) => new Intl.NumberFormat('en-US').format(n),
      sar: (n) => {
        const v = new Intl.NumberFormat('en-US', { minimumFractionDigits: n % 1 ? 2 : 0, maximumFractionDigits: 2 }).format(n);
        return lang === 'ar' ? `${v} ر.س` : `SAR ${v}`;
      },
      date: (s) => (s ? latin(new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short', year: 'numeric' }).format(new Date(s))) : '—'),
      dateTime: (s) => (s ? latin(new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(s))) : '—'),
    };
  }, [lang]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useI18n() {
  const v = useContext(Ctx);
  if (!v) throw new Error('I18nProvider missing');
  return v;
}

export function errorText(t: Dict, e: unknown): string {
  const code = (e as { code?: string })?.code;
  const msg = (e as { message?: string })?.message;
  if (code === 'VALIDATION_FAILED' && msg && /allowed list/.test(msg)) return t.offers.hostsNote;
  if (code === 'VALIDATION_FAILED' && msg && msg !== code) return `${t.errors.VALIDATION_FAILED}: ${msg}`;
  return (code && (t.errors as Record<string, string>)[code]) || t.errors.generic;
}
