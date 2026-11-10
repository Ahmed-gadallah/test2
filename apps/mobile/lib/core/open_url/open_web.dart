import 'package:web/web.dart' as web;

/// Opens [url] in a new tab from inside the tap.
///
/// A real <a target="_blank"> is created and clicked: the shared demo page runs the app in a
/// sandboxed frame without "allow-popups", where window.open() is refused but link clicks are
/// honoured. (url_launcher's own web Link overlay is not used: this Flutter web build positions it
/// at the wrong horizontal offset.)
void openInNewTab(String url) {
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..target = '_blank'
    ..rel = 'noopener noreferrer'
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
}
