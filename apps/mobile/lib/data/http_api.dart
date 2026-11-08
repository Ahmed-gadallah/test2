import 'dart:async';

import 'package:dio/dio.dart';

import 'api.dart';
import 'models.dart';
import 'token_store.dart';

/// Real backend client. Handles bearer tokens and transparent refresh (with
/// single-flight so concurrent 401s trigger only one refresh — the backend
/// rotates refresh tokens and treats a replay as theft).
class HttpZaadApi implements ZaadApi {
  final Dio _dio;
  final TokenStore _tokens;
  final void Function() onSessionExpired;
  Completer<bool>? _refreshing;

  HttpZaadApi(String baseUrl, this._tokens, {required this.onSessionExpired})
      : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 20))) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await _tokens.accessToken();
        if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        final req = e.requestOptions;
        if (e.response?.statusCode == 401 && req.extra['retried'] != true && req.extra['noAuth'] != true) {
          if (await _refresh()) {
            req.extra['retried'] = true;
            req.headers['Authorization'] = 'Bearer ${await _tokens.accessToken()}';
            try {
              return h.resolve(await _dio.fetch(req));
            } on DioException catch (e2) {
              return h.next(e2);
            }
          }
          onSessionExpired();
        }
        h.next(e);
      },
    ));
  }

  Future<bool> _refresh() async {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    try {
      final rt = await _tokens.refreshToken();
      if (rt == null) {
        c.complete(false);
      } else {
        final r = await _dio.post('/auth/refresh', data: {'refreshToken': rt}, options: Options(extra: {'noAuth': true}));
        await _tokens.save(AuthTokens.fromJson(r.data['data'] as Map<String, dynamic>));
        c.complete(true);
      }
    } catch (_) {
      await _tokens.clear();
      c.complete(false);
    } finally {
      _refreshing = null;
    }
    return c.future;
  }

  Future<Map<String, dynamic>> _call(Future<Response<dynamic>> Function() fn) async {
    try {
      final r = await fn();
      if (r.statusCode == 202 && r.data is Map && r.data['error'] != null) {
        throw ApiFailure(r.data['error']['code'] as String, status: 202);
      }
      return r.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final body = e.response?.data;
      if (body is Map && body['error'] is Map) {
        final err = body['error'] as Map;
        throw ApiFailure(err['code'] as String, status: e.response!.statusCode ?? 0, details: (err['details'] as Map?)?.cast<String, dynamic>());
      }
      throw ApiFailure(e.response == null ? 'NETWORK' : 'INTERNAL', status: e.response?.statusCode ?? 0);
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> body) => body['data'] as Map<String, dynamic>;
  List<Map<String, dynamic>> _list(Map<String, dynamic> body) => (body['data'] as List).cast<Map<String, dynamic>>();
  Options get _anon => Options(extra: {'noAuth': true});

  Future<Map<String, dynamic>> _deviceInfo() async => {'deviceId': await _tokens.deviceId(), 'platform': _tokens.platform};

  @override
  Future<void> checkMobile(String mobile) async => _call(() => _dio.post('/auth/check-mobile', data: {'mobile': mobile}, options: _anon));

  @override
  Future<OtpInfo> sendOtp(String mobile, String purpose) async =>
      OtpInfo.fromJson(_data(await _call(() => _dio.post('/auth/send-otp', data: {'mobile': mobile, 'purpose': purpose}, options: _anon))));

  @override
  Future<String> verifyOtp(String mobile, String purpose, String code) async =>
      _data(await _call(() => _dio.post('/auth/verify-otp', data: {'mobile': mobile, 'purpose': purpose, 'code': code}, options: _anon)))['verificationToken']
          as String;

  @override
  Future<AuthTokens> register(String verificationToken, String password, String language) async {
    final body = {'verificationToken': verificationToken, 'password': password, 'language': language, ...await _deviceInfo()};
    return AuthTokens.fromJson(_data(await _call(() => _dio.post('/auth/register', data: body, options: _anon))));
  }

  @override
  Future<AuthTokens> login(String mobile, String password) async {
    final body = {'mobile': mobile, 'password': password, ...await _deviceInfo()};
    return AuthTokens.fromJson(_data(await _call(() => _dio.post('/auth/login', data: body, options: _anon))));
  }

  @override
  Future<void> resetPassword(String verificationToken, String password) async =>
      _call(() => _dio.post('/auth/reset-password', data: {'verificationToken': verificationToken, 'password': password}, options: _anon));

  @override
  Future<void> logout() async {
    try {
      await _call(() => _dio.post('/auth/logout'));
    } finally {
      await _tokens.clear();
    }
  }

  @override
  Future<Profile> profile() async => Profile.fromJson(_data(await _call(() => _dio.get('/customer/profile'))));

  @override
  Future<PointsBalance> points({bool refresh = false}) async =>
      PointsBalance.fromJson(_data(await _call(() => _dio.get('/customer/points', queryParameters: {if (refresh) 'refresh': 'true'}))));

  @override
  Future<PageResult<PointsEntry>> pointsHistory(String? cursor) async {
    final b = await _call(() => _dio.get('/customer/points/history', queryParameters: {'limit': 20, 'cursor': ?cursor}));
    return PageResult(_list(b).map(PointsEntry.fromJson).toList(), (b['meta'] as Map)['nextCursor'] as String?);
  }

  @override
  Future<PageResult<InvoiceSummary>> invoices(String? cursor) async {
    final b = await _call(() => _dio.get('/customer/invoices', queryParameters: {'limit': 20, 'cursor': ?cursor}));
    return PageResult(_list(b).map(InvoiceSummary.fromJson).toList(), (b['meta'] as Map)['nextCursor'] as String?);
  }

  @override
  Future<InvoiceDetail> invoice(String id) async => InvoiceDetail.fromJson(_data(await _call(() => _dio.get('/customer/invoices/$id'))));

  @override
  Future<List<Offer>> offers() async => _list(await _call(() => _dio.get('/offers'))).map(Offer.fromJson).toList();

  @override
  Future<Offer> offer(String id) async => Offer.fromJson(_data(await _call(() => _dio.get('/offers/$id'))));

  @override
  Future<(List<AppNotification>, int)> notifications() async {
    final b = await _call(() => _dio.get('/notifications', queryParameters: {'limit': 50}));
    return (_list(b).map(AppNotification.fromJson).toList(), (b['meta'] as Map)['unread'] as int);
  }

  @override
  Future<void> markNotificationRead(String id) async => _call(() => _dio.patch('/notifications/$id/read'));

  @override
  Future<void> markAllNotificationsRead() async => _call(() => _dio.post('/notifications/read-all'));

  @override
  Future<List<Redemption>> pendingRedemptions() async => _list(await _call(() => _dio.get('/redemption/pending'))).map(Redemption.fromJson).toList();

  @override
  Future<Redemption> redemption(String id) async => Redemption.fromJson(_data(await _call(() => _dio.get('/redemption/$id'))));

  @override
  Future<Redemption> decideRedemption(String id, bool approve) async =>
      Redemption.fromJson(_data(await _call(() => _dio.post('/redemption/$id/${approve ? 'approve' : 'reject'}'))));

  @override
  Future<void> simulateCashierRedemption(String mobile, int points) async =>
      _call(() => _dio.post('/dev/simulate/cashier-redemption', data: {'mobile': mobile, 'points': points, 'ttlSeconds': 120}, options: _anon));

  @override
  Future<void> simulateErpOutage(bool on) async => _call(() => _dio.post('/dev/simulate/erp-outage', data: {'on': on}, options: _anon));
}
