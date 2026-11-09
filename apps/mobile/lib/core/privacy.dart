import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots and screen recording while a sensitive screen is visible
/// (Android FLAG_SECURE). iOS cannot block screenshots; there the app-switcher
/// snapshot is covered natively (ios/Runner/SceneDelegate.swift).
class SecureScreen extends StatefulWidget {
  final Widget child;
  const SecureScreen({super.key, required this.child});
  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  static const _channel = MethodChannel('zaad/privacy');
  static int _active = 0; // nested secure screens

  static Future<void> _set(bool on) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', on);
    } on PlatformException {
      // Not fatal: content stays visible, but never crash the screen over it.
    } on MissingPluginException {
      // tests / unsupported embedders
    }
  }

  @override
  void initState() {
    super.initState();
    if (_active++ == 0) _set(true);
  }

  @override
  void dispose() {
    if (--_active == 0) _set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
