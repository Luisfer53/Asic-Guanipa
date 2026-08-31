// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setSessionToken(String token) {
  try {
    html.window.sessionStorage['jwt'] = token;
  } catch (_) {}
}

String? getSessionToken() {
  try {
    return html.window.sessionStorage['jwt'];
  } catch (_) {
    return null;
  }
}

void removeSessionToken() {
  try {
    html.window.sessionStorage.remove('jwt');
  } catch (_) {}
}
