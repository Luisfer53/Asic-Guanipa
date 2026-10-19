// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setSessionToken(String token) {
  try {
    html.window.sessionStorage['jwt'] = token;
    html.window.localStorage['jwt'] = token;
  } catch (_) {}
}

String? getSessionToken() {
  try {
    final s = html.window.sessionStorage['jwt'];
    if (s != null && s.trim().isNotEmpty) return s.trim();
    final l = html.window.localStorage['jwt'];
    if (l != null && l.trim().isNotEmpty) return l.trim();
    return null;
  } catch (_) {
    return null;
  }
}

void removeSessionToken() {
  try {
    html.window.sessionStorage.remove('jwt');
    html.window.localStorage.remove('jwt');
  } catch (_) {}
}
