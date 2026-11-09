import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

/// Tokens live in the platform secure store (Keychain / Android Keystore).
/// Biometric unlock gates access to an existing session; it does not replace
/// authentication after a full logout (spec §5.2).
class TokenStore {
  static const _access = 'zaad.access';
  static const _refresh = 'zaad.refresh';
  static const _device = 'zaad.device';
  static const _mobile = 'zaad.mobile';
  // iOS: Keychain item readable only while unlocked and never migrated to another device via backup.
  // Android: values encrypted with a key held in Android Keystore (library default); app backups are disabled in the manifest.
  final FlutterSecureStorage _s = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
  );
  String? _accessCache;

  String get platform => kIsWeb
      ? 'web'
      : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

  Future<String?> accessToken() async => _accessCache ??= await _s.read(key: _access);
  Future<String?> refreshToken() => _s.read(key: _refresh);
  Future<bool> hasSession() async => (await refreshToken()) != null;

  Future<void> save(AuthTokens t) async {
    _accessCache = t.accessToken;
    await _s.write(key: _access, value: t.accessToken);
    await _s.write(key: _refresh, value: t.refreshToken);
  }

  Future<void> clear() async {
    _accessCache = null;
    await _s.delete(key: _access);
    await _s.delete(key: _refresh);
  }

  Future<void> rememberMobile(String m) => _s.write(key: _mobile, value: m);
  Future<String?> lastMobile() => _s.read(key: _mobile);

  Future<String> deviceId() async {
    final existing = await _s.read(key: _device);
    if (existing != null) return existing;
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _s.write(key: _device, value: id);
    return id;
  }
}
