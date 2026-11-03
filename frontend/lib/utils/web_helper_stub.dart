/// Stub para plataformas no-web (Android, iOS, Desktop).
/// Todas las funciones son no-op o devuelven valores por defecto.

/// Abre una URL en una nueva pestaña. No-op en Android.
void openInNewTab(String url) {}

/// Retorna el origen (dominio base) del servidor.
/// En Android usamos la constante de Supabase/Render.
String getOrigin() => 'https://asicguanipa.gob.ve';

/// Abre una ventana en blanco (para pre-cargar antes del print). No-op en Android.
dynamic openBlankWindow() => null;

/// Lanza la impresión de un documento HTML. No-op en Android.
Future<void> openHtmlPrint(String htmlContent, [dynamic preWindow]) async {}

/// Descarga bytes como archivo CSV. No-op en Android
/// (en Android usaría path_provider + open_file, pero no es necesario aquí).
void downloadCsvBytes(List<int> bytes, String filename) {}

