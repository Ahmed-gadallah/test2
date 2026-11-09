// Data models mirroring the backend API contract (apps/backend). Optional ERP
// fields are nullable and the UI hides them when absent — never fabricated.

DateTime _dt(Object? v) => DateTime.parse(v as String).toLocal();
double _d(Object? v) => (v as num).toDouble();
double? _dn(Object? v) => v == null ? null : (v as num).toDouble();

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  const AuthTokens(this.accessToken, this.refreshToken);
  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(j['accessToken'] as String, j['refreshToken'] as String);
}

class OtpInfo {
  final int expiresInSeconds;
  final int resendAfterSeconds;
  const OtpInfo(this.expiresInSeconds, this.resendAfterSeconds);
  factory OtpInfo.fromJson(Map<String, dynamic> j) => OtpInfo(j['expiresInSeconds'] as int, j['resendAfterSeconds'] as int);
}

class Profile {
  final String customerId;
  final String? name;
  final String mobileNumber;
  const Profile({required this.customerId, required this.name, required this.mobileNumber});
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(customerId: j['customerId'] as String, name: j['name'] as String?, mobileNumber: j['mobileNumber'] as String);
}

class PointsBalance {
  final int points;
  final int equivalentSar;
  final int pointsPerSar;
  final DateTime asOf;
  const PointsBalance({required this.points, required this.equivalentSar, required this.pointsPerSar, required this.asOf});
  factory PointsBalance.fromJson(Map<String, dynamic> j) => PointsBalance(
        points: j['points'] as int,
        equivalentSar: j['equivalentSar'] as int,
        pointsPerSar: j['pointsPerSar'] as int,
        asOf: _dt(j['asOf']),
      );
}

enum PointsEntryType { earned, redeemed, refundAdjustment, manualAdjustment }

class PointsEntry {
  final String id;
  final DateTime occurredAt;
  final PointsEntryType type;
  final int pointsDelta;
  final int? balanceAfter;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? branchName;
  final String? description;
  const PointsEntry({
    required this.id,
    required this.occurredAt,
    required this.type,
    required this.pointsDelta,
    this.balanceAfter,
    this.invoiceId,
    this.invoiceNumber,
    this.branchName,
    this.description,
  });
  factory PointsEntry.fromJson(Map<String, dynamic> j) => PointsEntry(
        id: j['id'] as String,
        occurredAt: _dt(j['occurredAt']),
        type: switch (j['type']) {
          'earned' => PointsEntryType.earned,
          'redeemed' => PointsEntryType.redeemed,
          'refund_adjustment' => PointsEntryType.refundAdjustment,
          _ => PointsEntryType.manualAdjustment,
        },
        pointsDelta: j['pointsDelta'] as int,
        balanceAfter: j['balanceAfter'] as int?,
        invoiceId: j['invoiceId'] as String?,
        invoiceNumber: j['invoiceNumber'] as String?,
        branchName: j['branchName'] as String?,
        description: j['description'] as String?,
      );
}

enum InvoiceStatus { finished, refunded, partiallyRefunded, cancelled }

InvoiceStatus _status(Object? s) => switch (s) {
      'refunded' => InvoiceStatus.refunded,
      'partially_refunded' => InvoiceStatus.partiallyRefunded,
      'cancelled' => InvoiceStatus.cancelled,
      _ => InvoiceStatus.finished,
    };

class InvoiceSummary {
  final String invoiceId;
  final String invoiceNumber;
  final DateTime issuedAt;
  final String branchName;
  final double total;
  final InvoiceStatus status;
  const InvoiceSummary({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.issuedAt,
    required this.branchName,
    required this.total,
    required this.status,
  });
  factory InvoiceSummary.fromJson(Map<String, dynamic> j) => InvoiceSummary(
        invoiceId: j['invoiceId'] as String,
        invoiceNumber: j['invoiceNumber'] as String,
        issuedAt: _dt(j['issuedAt']),
        branchName: j['branchName'] as String,
        total: _d(j['total']),
        status: _status(j['status']),
      );
}

class InvoiceLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final double? discount;
  final double lineTotal;
  const InvoiceLine({required this.name, required this.quantity, required this.unitPrice, this.discount, required this.lineTotal});
  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        name: j['name'] as String,
        quantity: j['quantity'] as int,
        unitPrice: _d(j['unitPrice']),
        discount: _dn(j['discount']),
        lineTotal: _d(j['lineTotal']),
      );
}

enum PaymentMethod { cash, card, cashAndCard }

class InvoiceDetail extends InvoiceSummary {
  final List<InvoiceLine> lines;
  final double? subTotal;
  final double? discountTotal;
  final double? voucherDiscount;
  final double? pointsValue;
  final double? taxTotal;
  final int? pointsEarned;
  final PaymentMethod? paymentMethod;
  const InvoiceDetail({
    required super.invoiceId,
    required super.invoiceNumber,
    required super.issuedAt,
    required super.branchName,
    required super.total,
    required super.status,
    required this.lines,
    this.subTotal,
    this.discountTotal,
    this.voucherDiscount,
    this.pointsValue,
    this.taxTotal,
    this.pointsEarned,
    this.paymentMethod,
  });
  factory InvoiceDetail.fromJson(Map<String, dynamic> j) {
    final s = InvoiceSummary.fromJson(j);
    return InvoiceDetail(
      invoiceId: s.invoiceId,
      invoiceNumber: s.invoiceNumber,
      issuedAt: s.issuedAt,
      branchName: s.branchName,
      total: s.total,
      status: s.status,
      lines: (j['lines'] as List).map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>)).toList(),
      subTotal: _dn(j['subTotal']),
      discountTotal: _dn(j['discountTotal']),
      voucherDiscount: _dn(j['voucherDiscount']),
      pointsValue: _dn(j['pointsValue']),
      taxTotal: _dn(j['taxTotal']),
      pointsEarned: j['pointsEarned'] as int?,
      paymentMethod: switch (j['paymentMethod']) {
        'cash' => PaymentMethod.cash,
        'card' => PaymentMethod.card,
        'cash_and_card' => PaymentMethod.cashAndCard,
        _ => null,
      },
    );
  }
}

class Offer {
  final String id;
  final String titleAr, titleEn, descriptionAr, descriptionEn;
  final String? imageUrl, ctaLabelAr, ctaLabelEn, destinationUrl;
  final DateTime startAt, endAt;
  final bool ended;
  const Offer({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.descriptionAr,
    required this.descriptionEn,
    this.imageUrl,
    this.ctaLabelAr,
    this.ctaLabelEn,
    this.destinationUrl,
    required this.startAt,
    required this.endAt,
    this.ended = false,
  });
  String title(bool ar) => ar ? titleAr : titleEn;
  String description(bool ar) => ar ? descriptionAr : descriptionEn;
  String? ctaLabel(bool ar) => ar ? ctaLabelAr : ctaLabelEn;
  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        descriptionAr: j['descriptionAr'] as String,
        descriptionEn: j['descriptionEn'] as String,
        imageUrl: j['imageUrl'] as String?,
        ctaLabelAr: j['ctaLabelAr'] as String?,
        ctaLabelEn: j['ctaLabelEn'] as String?,
        destinationUrl: j['destinationUrl'] as String?,
        startAt: _dt(j['startAt']),
        endAt: _dt(j['endAt']),
        ended: j['status'] == 'expired',
      );
}

class AppNotification {
  final String id;
  final String type;
  final String titleAr, titleEn, bodyAr, bodyEn;
  final String deepLink;
  final DateTime createdAt;
  final bool read;
  const AppNotification({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.deepLink,
    required this.createdAt,
    required this.read,
  });
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        titleAr: j['titleAr'] as String,
        titleEn: j['titleEn'] as String,
        bodyAr: j['bodyAr'] as String,
        bodyEn: j['bodyEn'] as String,
        deepLink: j['deepLink'] as String,
        createdAt: _dt(j['createdAt']),
        read: j['readAt'] != null,
      );
  AppNotification markRead() => AppNotification(
      id: id, type: type, titleAr: titleAr, titleEn: titleEn, bodyAr: bodyAr, bodyEn: bodyEn, deepLink: deepLink, createdAt: createdAt, read: true);
}

enum RedemptionStatus { pending, approved, rejected, expired, completed, failed }

class Redemption {
  final String id;
  final String reference;
  final String branchName;
  final int points;
  final double discountAmount;
  final RedemptionStatus status;
  final DateTime expiresAt;
  final String? customerDecision;
  const Redemption({
    required this.id,
    required this.reference,
    required this.branchName,
    required this.points,
    required this.discountAmount,
    required this.status,
    required this.expiresAt,
    this.customerDecision,
  });
  bool get isActionable => status == RedemptionStatus.pending && customerDecision == null && expiresAt.isAfter(DateTime.now());
  factory Redemption.fromJson(Map<String, dynamic> j) => Redemption(
        id: j['id'] as String,
        reference: j['reference'] as String,
        branchName: j['branchName'] as String,
        points: j['points'] as int,
        discountAmount: _d(j['discountAmount']),
        status: RedemptionStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => RedemptionStatus.failed),
        expiresAt: _dt(j['expiresAt']),
        customerDecision: j['customerDecision'] as String?,
      );
}

class PageResult<T> {
  final List<T> items;
  final String? nextCursor;
  const PageResult(this.items, this.nextCursor);
}

/// A Zaad branch from the backend branch directory (imported from the branches sheet).
/// Only active branches ever reach the app. ONE phone per branch (calls and delivery).
/// Optional fields are null when the sheet left them empty; the UI hides what is missing.
class Branch {
  final int id;
  final String nameAr;
  final String? nameEn;
  final String city;
  final String? district;
  final String addressAr;
  final String? addressEn;
  final String? phone;
  final String? mapsUrl;
  final String? notes;
  Branch({
    required this.id,
    required this.nameAr,
    this.nameEn,
    required this.city,
    this.district,
    required this.addressAr,
    this.addressEn,
    this.phone,
    this.mapsUrl,
    this.notes,
  });

  /// English falls back to Arabic when the sheet has no English value (nothing is translated or invented).
  String name(bool ar) => ar || (nameEn ?? '').isEmpty ? nameAr : nameEn!;
  String address(bool ar) => ar || (addressEn ?? '').isEmpty ? addressAr : addressEn!;

  /// "City · District", without repeating the district when the sheet uses the same value for both.
  String place() => [city, if (district != null && district != city) district!].join(' · ');

  /// Address line for cards. Null when it only repeats the district/city already shown in [place].
  String? extraAddress(bool ar) {
    final a = address(ar);
    if (ar && (a == district || a == city)) return null;
    return a;
  }

  Uri? get telUri => phone == null ? null : Uri(scheme: 'tel', path: phone);
  Uri? get mapsUri {
    final u = mapsUrl == null ? null : Uri.tryParse(mapsUrl!);
    return u != null && u.scheme == 'https' ? u : null;
  }

  late final String _haystack = normalizeSearch([nameAr, nameEn, city, district, addressAr, addressEn].whereType<String>().join(' '));

  /// Search by name (Arabic/English), city, district or address. Every word typed must appear.
  bool matches(String query) {
    final words = normalizeSearch(query).split(' ').where((w) => w.isNotEmpty);
    return words.every(_haystack.contains);
  }

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        id: (j['id'] as num).toInt(),
        nameAr: j['nameAr'] as String,
        nameEn: j['nameEn'] as String?,
        city: j['city'] as String,
        district: j['district'] as String?,
        addressAr: j['addressAr'] as String,
        addressEn: j['addressEn'] as String?,
        phone: j['phone'] as String?,
        mapsUrl: j['mapsUrl'] as String?,
        notes: j['notes'] as String?,
      );
}

/// Folds the spelling differences people type in Arabic search (أ/إ/آ→ا, ة→ه, ى→ي, ؤ→و, ئ→ي),
/// removes diacritics and tatweel, converts Arabic-Indic digits and lowercases Latin text.
String normalizeSearch(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if ((r >= 0x064B && r <= 0x0652) || r == 0x0640 || r == 0x0670) continue;
    final c = switch (r) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
      0x0629 => 0x0647,
      0x0649 => 0x064A,
      0x0624 => 0x0648,
      0x0626 => 0x064A,
      >= 0x0660 && <= 0x0669 => r - 0x0660 + 0x30,
      >= 0x06F0 && <= 0x06F9 => r - 0x06F0 + 0x30,
      _ => r,
    };
    b.writeCharCode(c);
  }
  return b.toString().replaceAll(RegExp(r'[\s\-_,.،/]+'), ' ').trim();
}
