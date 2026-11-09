import 'package:flutter/services.dart';

import 'fallback_stub.dart' if (dart.library.js_interop) 'fallback_web.dart';

/// Copies [text]; returns false only if every method failed (the UI then asks to copy by hand).
Future<bool> copyText(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return fallbackCopy(text);
  }
}
