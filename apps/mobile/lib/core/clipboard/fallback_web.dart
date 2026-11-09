import 'package:web/web.dart' as web;

/// Browsers can refuse navigator.clipboard inside an embedded page (e.g. the shared demo link).
/// The legacy copy command still works there during a tap, so use it as a fallback.
bool fallbackCopy(String text) {
  final area = web.document.createElement('textarea') as web.HTMLTextAreaElement
    ..value = text
    ..setAttribute('readonly', '')
    ..style.position = 'fixed'
    ..style.opacity = '0'
    ..style.top = '0';
  web.document.body?.append(area);
  try {
    area.select();
    return web.document.execCommand('copy');
  } catch (_) {
    return false;
  } finally {
    area.remove();
  }
}
