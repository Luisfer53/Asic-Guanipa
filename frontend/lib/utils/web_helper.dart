// Exportación condicional: Web real vs Stub para Android/Desktop
export 'web_helper_stub.dart' if (dart.library.html) 'web_helper_web.dart';

