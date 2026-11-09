import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'data/models.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/home_screen.dart';
import 'features/invoices/invoice_screens.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/offers/offers_screens.dart';
import 'features/points/points_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/redemption/redemption_screen.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/providers.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/common.dart';

class _SessionListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionListenable();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  const publicRoutes = {'/welcome', '/register', '/otp', '/password', '/login', '/forgot'};

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = ref.read(sessionProvider);
      final loc = state.matchedLocation;
      if (s == SessionState.loading) return loc == '/splash' ? null : '/splash';
      if (s == SessionState.locked) return loc == '/unlock' ? null : '/unlock';
      if (s == SessionState.signedOut) return publicRoutes.contains(loc) ? null : '/welcome';
      if (publicRoutes.contains(loc) || loc == '/splash' || loc == '/unlock') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const Scaffold(body: LoadingView())),
      GoRoute(path: '/unlock', builder: (_, _) => const UnlockScreen()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterMobileScreen()),
      GoRoute(path: '/forgot', builder: (_, _) => const RegisterMobileScreen(purpose: 'reset_password')),
      GoRoute(path: '/otp', builder: (_, s) => OtpScreen(flow: s.extra! as AuthFlow)),
      GoRoute(path: '/password', builder: (_, s) => PasswordScreen(flow: s.extra! as AuthFlow)),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => _Shell(shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/invoices', builder: (_, _) => const InvoicesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/offers', builder: (_, _) => const OffersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/points', builder: (_, _) => const PointsScreen()),
      GoRoute(path: '/invoices/:id', builder: (_, s) => InvoiceDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/offers/:id', builder: (_, s) => OfferDetailScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/redemption/:id', builder: (_, s) => RedemptionScreen(id: s.pathParameters['id']!)),
    ],
  );
});

class _Shell extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;
  const _Shell(this.shell);
  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  final _seen = <String>{};

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // A customer standing at the counter should see the request immediately:
    // open the approval screen once per new pending request.
    ref.listen<AsyncValue<List<Redemption>>>(pendingRedemptionsProvider, (_, next) {
      for (final r in next.value ?? const <Redemption>[]) {
        if (r.isActionable && _seen.add(r.id)) {
          ref.invalidate(notificationsProvider);
          context.push('/redemption/${r.id}');
          break;
        }
      }
    });
    return Scaffold(
      body: Column(children: [const DemoBanner(), Expanded(child: widget.shell)]),
      bottomNavigationBar: ZaadBottomNav(
        index: widget.shell.currentIndex,
        onTap: (i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
        items: [
          NavItem(Icons.home_outlined, Icons.home_rounded, t.navHome),
          NavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, t.navInvoices),
          NavItem(Icons.local_offer_outlined, Icons.local_offer_rounded, t.navOffers),
          NavItem(Icons.person_outline_rounded, Icons.person_rounded, t.navProfile),
        ],
      ),
    );
  }
}

class ZaadApp extends ConsumerWidget {
  const ZaadApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: buildTheme(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
    );
  }
}
