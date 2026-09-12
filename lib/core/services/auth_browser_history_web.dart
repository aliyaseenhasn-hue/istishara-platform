import 'package:web/web.dart' as web;

void replaceBrowserUrl(String url) {
  web.window.history.replaceState(null, '', url);
}
