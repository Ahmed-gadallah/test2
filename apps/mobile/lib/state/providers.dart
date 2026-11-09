import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../data/api.dart';
import '../data/demo_api.dart';
import '../data/http_api.dart';
import '../data/models.dart';
import '../data/token_store.dart';

final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('overridden in main'));
final tokenStoreProvider = Provider<TokenStore>((_) => TokenStore());

final apiProvider = Provider<ZaadApi>((ref) {
  if (AppConfig.isDemo) return DemoZaadApi();
  return HttpZaadApi(AppConfig.apiBaseUrl, ref.read(tokenStoreProvider), onSessionExpired: () => ref.read(sessionProvider.notifier).expired());
});

// ── Locale (Arabic default, spec §4.3) ─────────────────────────────────────
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => Locale(ref.read(prefsProvider).getString('lang') ?? 'ar');
  void set(String lang) {
    ref.read(prefsProvider).setString('lang', lang);
    state = Locale(lang);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

// ── Session ────────────────────────────────────────────────────────────────
enum SessionState { loading, signedOut, locked, signedIn }

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    _init();
    return SessionState.loading;
  }

  TokenStore get _store => ref.read(tokenStoreProvider);
  bool get biometricEnabled => ref.read(prefsProvider).getBool('biometric') ?? false;

  Future<void> _init() async {
    final has = await _store.hasSession();
    if (!has) {
      state = SessionState.signedOut;
      return;
    }
    final api = ref.read(apiProvider);
    if (api is DemoZaadApi) api.restore((await _store.accessToken()) ?? '');
    // Biometrics only unlock an EXISTING session (spec §5.2).
    state = biometricEnabled && !kIsWeb ? SessionState.locked : SessionState.signedIn;
  }

  Future<void> signedIn(AuthTokens t, String mobile) async {
    await _store.save(t);
    await _store.rememberMobile(mobile);
    state = SessionState.signedIn;
  }

  Future<bool> unlock(String reason) async {
    try {
      final ok = await LocalAuthentication().authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
      if (ok) state = SessionState.signedIn;
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(apiProvider).logout();
    } catch (_) {/* revoke best-effort; local tokens are cleared regardless */}
    await _store.clear();
    state = SessionState.signedOut;
  }

  void expired() {
    _store.clear();
    state = SessionState.signedOut;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class BiometricNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getBool('biometric') ?? false;
  Future<void> set(bool v) async {
    await ref.read(prefsProvider).setBool('biometric', v);
    state = v;
  }
}

final biometricProvider = NotifierProvider<BiometricNotifier, bool>(BiometricNotifier.new);
final biometricAvailableProvider = FutureProvider<bool>((_) async {
  if (kIsWeb) return false;
  try {
    final a = LocalAuthentication();
    return await a.isDeviceSupported() && await a.canCheckBiometrics;
  } catch (_) {
    return false;
  }
});

// ── Data ───────────────────────────────────────────────────────────────────
final profileProvider = FutureProvider.autoDispose<Profile>((ref) => ref.watch(apiProvider).profile());
final pointsProvider = FutureProvider.autoDispose<PointsBalance>((ref) => ref.watch(apiProvider).points());
final offersProvider = FutureProvider.autoDispose<List<Offer>>((ref) => ref.watch(apiProvider).offers());
final branchesProvider = FutureProvider.autoDispose<List<Branch>>((ref) => ref.watch(apiProvider).branches());
final offerProvider = FutureProvider.autoDispose.family<Offer, String>((ref, id) => ref.watch(apiProvider).offer(id));
final invoiceProvider = FutureProvider.autoDispose.family<InvoiceDetail, String>((ref, id) => ref.watch(apiProvider).invoice(id));
final notificationsProvider = FutureProvider.autoDispose<(List<AppNotification>, int)>((ref) => ref.watch(apiProvider).notifications());
final redemptionProvider = FutureProvider.autoDispose.family<Redemption, String>((ref, id) => ref.watch(apiProvider).redemption(id));

/// Pending redemption requests, polled while the app is open. Critical requests
/// must never depend on push delivery alone (spec §13.3).
final pendingRedemptionsProvider = StreamProvider.autoDispose<List<Redemption>>((ref) {
  final api = ref.watch(apiProvider);
  final out = StreamController<List<Redemption>>();
  Timer? timer;
  var disposed = false;
  Future<void> tick() async {
    try {
      final list = await api.pendingRedemptions();
      if (!disposed) out.add(list);
    } on ApiFailure catch (e) {
      if (e.code == 'SESSION_EXPIRED' && !disposed) out.addError(e);
      // other failures are transient: keep polling; the banner simply doesn't show
    }
    if (!disposed) timer = Timer(AppConfig.redemptionPollInterval, tick);
  }

  tick();
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
    out.close();
  });
  return out.stream;
});

/// Generic paginated list state (invoices, points history).
class Paged<T> {
  final List<T> items;
  final String? cursor;
  final bool done;
  final bool loading;
  final Object? error;
  const Paged({this.items = const [], this.cursor, this.done = false, this.loading = false, this.error});
  Paged<T> copy({List<T>? items, String? cursor, bool? done, bool? loading, Object? error, bool clearError = false}) =>
      Paged(items: items ?? this.items, cursor: cursor ?? this.cursor, done: done ?? this.done, loading: loading ?? this.loading, error: clearError ? null : error ?? this.error);
}

abstract class PagedNotifier<T> extends Notifier<Paged<T>> {
  Future<PageResult<T>> fetch(String? cursor);

  @override
  Paged<T> build() {
    Future.microtask(loadMore);
    return Paged<T>(loading: true);
  }

  Future<void> loadMore() async {
    if (state.done || (state.loading && state.items.isNotEmpty)) return;
    state = state.copy(loading: true, clearError: true);
    try {
      final p = await fetch(state.cursor);
      state = Paged(items: [...state.items, ...p.items], cursor: p.nextCursor, done: p.nextCursor == null);
    } catch (e) {
      state = state.copy(loading: false, error: e);
    }
  }

  Future<void> reload() async {
    state = Paged<T>(loading: true);
    await loadMore();
  }
}

class InvoicesNotifier extends PagedNotifier<InvoiceSummary> {
  @override
  Future<PageResult<InvoiceSummary>> fetch(String? cursor) => ref.read(apiProvider).invoices(cursor);
}

class HistoryNotifier extends PagedNotifier<PointsEntry> {
  @override
  Future<PageResult<PointsEntry>> fetch(String? cursor) => ref.read(apiProvider).pointsHistory(cursor);
}

final invoicesProvider = NotifierProvider.autoDispose<InvoicesNotifier, Paged<InvoiceSummary>>(InvoicesNotifier.new);
final historyProvider = NotifierProvider.autoDispose<HistoryNotifier, Paged<PointsEntry>>(HistoryNotifier.new);
