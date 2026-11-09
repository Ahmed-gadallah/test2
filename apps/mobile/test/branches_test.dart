import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/link.dart';
import 'package:zaad/core/theme.dart';
import 'package:zaad/data/models.dart';
import 'package:zaad/features/branches/branches_screens.dart';
import 'package:zaad/l10n/gen/app_localizations.dart';
import 'package:zaad/widgets/ui_kit.dart';
import 'package:zaad/state/providers.dart';

Branch _b({int id = 1, String nameAr = 'صيدلية زاد الدوائية 48', String? nameEn = 'zaad pharmacy 48', String city = 'بقعاء', String? district = 'بقعاء', String addressAr = 'بقعاء', String? addressEn = 'Baqaa', String? phone = '+966541418264', String? mapsUrl = 'https://maps.app.goo.gl/BB8rfs9zdyUzd7a38', String? notes}) =>
    Branch(id: id, nameAr: nameAr, nameEn: nameEn, city: city, district: district, addressAr: addressAr, addressEn: addressEn, phone: phone, mapsUrl: mapsUrl, notes: notes);

final _branches = [
  _b(),
  _b(id: 6, nameAr: 'صيدلية زاد الدوائية 49', nameEn: 'zaad pharmacy 49', city: 'حائل', district: 'النقرة', addressAr: 'سعود بن عبد المحسن', addressEn: 'Saud Bin Abdulmuhsin', phone: '+966541329804', mapsUrl: 'https://maps.app.goo.gl/gyN2GtVJuXu4Hjk57'),
  // Branch 7 in the real sheet has no phone; this one also has no link — both must be handled gracefully.
  _b(id: 7, nameAr: 'صيدلية زاد الدوائية 2', nameEn: 'zaad pharmacy 2', city: 'حائل', district: 'الحوطي', addressAr: 'الحوطي', addressEn: 'Al-Hawti', phone: null, mapsUrl: null),
];

Future<void> pump(WidgetTester tester, {String lang = 'ar', String initial = '/branches', List<Branch>? data}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: initial, observers: [linkGuard], routes: [
    GoRoute(path: '/branches', builder: (_, _) => const BranchesScreen()),
    GoRoute(path: '/branches/:id', builder: (_, s) => BranchDetailScreen(id: int.parse(s.pathParameters['id']!))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [branchesProvider.overrideWith((ref) async => data ?? _branches)],
    child: MaterialApp.router(
      routerConfig: router,
      theme: buildTheme(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    ),
  ));
  await tester.pumpAndSettle();
}

List<Uri?> linkUris(WidgetTester tester) => tester.widgetList<Link>(find.byType(Link)).map((l) => l.uri).toList();

void main() {
  group('search', () {
    test('matches Arabic and English names, city, district and address; spelling-tolerant', () {
      final b = _branches[1];
      for (final q in ['زاد 49', 'ZAAD PHARMACY 49', 'حائل', 'النقره', 'سعود بن عبدالمحسن'.replaceAll('عبدالمحسن', 'عبد المحسن'), 'saud', 'الدّوائية ٤٩', 'النقرة سعود']) {
        expect(b.matches(q), isTrue, reason: q);
      }
      for (final q in ['بقعاء', 'riyadh', 'زاد 50', 'حائل الرياض']) {
        expect(b.matches(q), isFalse, reason: q);
      }
      expect(normalizeSearch('إأآ ة ى ؤ ئ ـ'), 'ااا ه ي و ي');
    });

    test('display helpers never repeat the district and fall back to Arabic, never invent', () {
      final b0 = _branches[0];
      expect(b0.place(), 'بقعاء'); // city == district → shown once
      expect(b0.extraAddress(true), isNull); // address only repeats the district
      expect(_branches[1].place(), 'حائل · النقرة');
      expect(_b(nameEn: null).name(false), 'صيدلية زاد الدوائية 48');
      expect(_b(addressEn: '').address(false), 'بقعاء');
      expect(_b(mapsUrl: 'http://maps.app.goo.gl/x').mapsUri, isNull); // only https links are opened
      expect(_b().telUri.toString(), 'tel:+966541418264');
    });
  });

  testWidgets('list (Arabic): cards with name, place, phone, call and View Location links; missing data handled', (tester) async {
    await pump(tester);
    expect(find.text('فروع زاد'), findsOneWidget);
    expect(find.text('3 فروع'), findsOneWidget);
    expect(find.text('صيدلية زاد الدوائية 48'), findsOneWidget);
    expect(find.text('حائل · النقرة'), findsOneWidget);
    expect(find.text('054 132 9804'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('فروع زاد'))), TextDirection.rtl);
    expect(find.text('عرض الموقع'), findsNWidgets(2));
    // Branch 7: no phone → no call button, no number; no link → "location not available".
    expect(find.byKey(const Key('call-7')), findsNothing);
    expect(find.text('رقم الهاتف غير متوفر'), findsOneWidget);
    expect(find.text('الموقع غير متوفر'), findsOneWidget);
    final uris = linkUris(tester).map((u) => u.toString()).toList();
    expect(uris, containsAll(['tel:+966541418264', 'https://maps.app.goo.gl/BB8rfs9zdyUzd7a38', 'tel:+966541329804', 'https://maps.app.goo.gl/gyN2GtVJuXu4Hjk57']));
    expect(uris.where((u) => u.startsWith('tel:')), hasLength(2)); // ONE number per branch with a phone
  });

  testWidgets('search filters live and shows a no-results state', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('branch-search')), 'حائل');
    await tester.pumpAndSettle();
    expect(find.text('فرعان'), findsOneWidget);
    expect(find.text('صيدلية زاد الدوائية 48'), findsNothing);
    await tester.enterText(find.byKey(const Key('branch-search')), 'Al-Hawti');
    await tester.pumpAndSettle();
    expect(find.text('فرع واحد'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('branch-search')), 'الرياض');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد فروع مطابقة لبحثك.'), findsOneWidget);
    await tester.tap(find.byTooltip('مسح البحث'));
    await tester.pumpAndSettle();
    expect(find.text('3 فروع'), findsOneWidget);
  });

  testWidgets('English: LTR, English names/addresses, and tapping a card opens details', (tester) async {
    await pump(tester, lang: 'en');
    expect(find.text('Our Branches'), findsOneWidget);
    expect(find.text('3 branches'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Our Branches'))), TextDirection.ltr);
    expect(find.text('zaad pharmacy 49'), findsOneWidget);
    expect(find.text('Saud Bin Abdulmuhsin'), findsOneWidget);
    await tester.tap(find.text('zaad pharmacy 49'));
    await tester.pumpAndSettle();
    expect(find.text('Call branch'), findsOneWidget);
    expect(find.text('Get directions'), findsOneWidget);
    expect(find.text('For calls and delivery'), findsOneWidget);
  });

  testWidgets('details: Call opens the dialer (tel: link, never auto-call) and Directions opens the supplied link', (tester) async {
    await pump(tester, initial: '/branches/6');
    expect(find.text('صيدلية زاد الدوائية 49'), findsOneWidget);
    final call = tester.widget<Link>(find.ancestor(of: find.byKey(const Key('call-branch')), matching: find.byType(Link)));
    expect(call.uri.toString(), 'tel:+966541329804');
    final maps = tester.widget<Link>(find.ancestor(of: find.byKey(const Key('get-directions')), matching: find.byType(Link)));
    expect(maps.uri.toString(), 'https://maps.app.goo.gl/gyN2GtVJuXu4Hjk57');
  });

  testWidgets('details without phone/link: no dead buttons, a clear message instead', (tester) async {
    await pump(tester, initial: '/branches/7');
    expect(find.byKey(const Key('call-branch')), findsNothing);
    expect(find.byKey(const Key('get-directions')), findsNothing);
    expect(find.text('الموقع غير متوفر'), findsOneWidget);
    expect(find.text('رقم الهاتف غير متوفر'), findsOneWidget);
    expect(find.byType(Link), findsNothing);
  });

  testWidgets('details with a link but no phone: Directions only', (tester) async {
    await pump(tester, initial: '/branches/7', data: [_b(id: 7, phone: null)]);
    expect(find.byKey(const Key('call-branch')), findsNothing);
    expect(find.byKey(const Key('get-directions')), findsOneWidget);
    expect(linkUris(tester).map((u) => u.toString()), ['https://maps.app.goo.gl/BB8rfs9zdyUzd7a38']);
  });

  testWidgets('copy button copies the number in local format and confirms', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, initial: '/branches/6');
    await tester.tap(find.byKey(const Key('copy-phone')));
    await tester.pumpAndSettle();
    expect(copied, '0541329804');
    expect(find.text('تم نسخ الرقم'), findsOneWidget);
  });

  testWidgets('web build: Call opens a sheet with the number, Copy and a call attempt (browsers block tel: in embedded pages)', (tester) async {
    PhoneAction.useCallSheet = true;
    LinkGuard.forceWebBehaviour = true;
    addTearDown(() {
      PhoneAction.useCallSheet = false;
      LinkGuard.forceWebBehaviour = false;
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, initial: '/branches/6');
    await tester.tap(find.byKey(const Key('call-branch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('call-sheet')), findsOneWidget);
    expect(find.text('054 132 9804'), findsWidgets);
    // While the sheet is open, no web link is live underneath it (a tap on Copy once opened the map),
    // and the sheet has no Call button that browsers would silently block.
    expect(find.byType(Link), findsNothing);
    await tester.tap(find.byKey(const Key('copy-number')));
    await tester.pumpAndSettle();
    expect(copied, '0541329804');
    expect(find.byKey(const Key('call-sheet')), findsNothing);
    expect(find.text('تم نسخ الرقم'), findsOneWidget);
    expect(linkUris(tester).map((u) => u.toString()), contains('https://maps.app.goo.gl/gyN2GtVJuXu4Hjk57')); // links back after closing
  });

  testWidgets('unknown or inactive branch id → not found (the API never returns inactive branches)', (tester) async {
    await pump(tester, initial: '/branches/999');
    expect(find.text('غير موجود.'), findsOneWidget);
  });

  testWidgets('empty directory state', (tester) async {
    await pump(tester, data: const []);
    expect(find.text('لا توجد فروع متاحة حاليًا.'), findsOneWidget);
  });

  test('demo data file matches the API shape (generated from the real sheet)', () {
    final list = (jsonDecode(File('assets/demo/branches.json').readAsStringSync()) as List).map((j) => Branch.fromJson(j as Map<String, dynamic>)).toList();
    expect(list, hasLength(53));
    expect(list.where((b) => b.phone == null), hasLength(11));
    expect(list.every((b) => b.mapsUri != null), isTrue);
  });
}
