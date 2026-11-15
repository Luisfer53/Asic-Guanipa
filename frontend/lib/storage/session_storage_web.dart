// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void setSessionToken(String token) {
  try {
    // Almacenamiento exclusivo de sesión: se destruye automáticamente al cerrar la pestaña o navegador
    html.window.sessionStorage['jwt'] = token;
    // Eliminar cualquier token persistente viejo de localStorage para que la sesión expire al cerrar la página
    html.window.localStorage.remove('jwt');
  } catch (_) {}
}

String? getSessionToken() {
  try {
    // Solo recuperar de sessionStorage (activo únicamente mientras la pestaña esté abierta)
    final s = html.window.sessionStorage['jwt'];
    if (s != null && s.trim().isNotEmpty) return s.trim();

    // Limpiar cualquier residuo de localStorage
    html.window.localStorage.remove('jwt');
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
