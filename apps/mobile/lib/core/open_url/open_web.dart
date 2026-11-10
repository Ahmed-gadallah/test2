import 'package:web/web.dart' as web;

/// Opens [url] in a new tab synchronously inside the tap, so the browser treats it as a user
/// action (works in sandboxed frames that allow popups, such as the shared demo link).
void openInNewTab(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
