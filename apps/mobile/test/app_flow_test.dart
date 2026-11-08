import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zaad/app.dart';
import 'package:zaad/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = <String, String>{};
  setUp(() async {
    store.clear();
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        switch (call.method) {
          case 'write':
            store[args['key'] as String] = args['value'] as String;
            return null;
          case 'read':
            return store[args['key']];
          case 'delete':
            store.remove(args['key']);
            return null;
          case 'containsKey':
            return store.containsKey(args['key']);
          default:
            return null;
        }
      },
    );
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const ZaadApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on the welcome screen in Arabic, right-to-left', (tester) async {
    await boot(tester);
    expect(find.text('إنشاء حساب'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('إنشاء حساب'))), TextDirection.rtl);
  });

  testWidgets('demo login lands on home with the ERP balance; English switch flips to LTR', (tester) async {
    await boot(tester);
    await tester.tap(find.text('تسجيل الدخول'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'تسجيل الدخول'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2,500'), findsOneWidget);
    expect(find.text('تعادل 50 ر.س'), findsOneWidget);

    await tester.tap(find.text('حسابي'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('English'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Language'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Language'))), TextDirection.ltr);
    await tester.pumpWidget(const SizedBox()); // disposes providers → poller must cancel its timer
  });
}
