/// Implementación real para plataforma Web usando dart:html.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Abre una URL en una nueva pestaña del navegador.
void openInNewTab(String url) {
  html.window.open(url, '_blank');
}

/// Retorna el origin del sitio web actual (protocolo + dominio + puerto).
String getOrigin() {
  try {
    final origin = html.window.location.origin;
    if (origin.isNotEmpty && !origin.startsWith('file:') && !origin.contains(':0')) {
      return origin;
    }
  } catch (_) {}
  return 'https://asicguanipa.gob.ve';
}

/// Abre una ventana en blanco (para hacer escritura posterior sin bloqueo de pop-up).
dynamic openBlankWindow() {
  try {
    return html.window.open('about:blank', '_blank');
  } catch (_) {
    return null;
  }
}

/// Genera una ventana de impresión con el contenido HTML dado.
/// Si se pasa [preWindow] (una ventana ya abierta), la usa directamente.
Future<void> openHtmlPrint(String htmlContent, [dynamic preWindow]) async {
  try {
    if (preWindow != null) {
      final dynamic win = preWindow;
      win.document?.open();
      win.document?.write(htmlContent);
      win.document?.close();
      return;
    }
    final blob = html.Blob([htmlContent], 'text/html;charset=utf-8');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    final ventana = html.window.open(blobUrl, '_blank');
    if (ventana != null) return;
  } catch (_) {}

  // Fallback: iframe invisible para cuando el navegador bloquea pop-ups
  try {
    final iframe = html.IFrameElement()
      ..style.position = 'fixed'
      ..style.right = '0'
      ..style.bottom = '0'
      ..style.width = '0'
      ..style.height = '0'
      ..style.border = '0';
    html.document.body?.append(iframe);
    final dynamic win = iframe.contentWindow;
    win?.document?.open();
    win?.document?.write(htmlContent);
    win?.document?.close();
    win?.focus();
    win?.print();
    Future.delayed(const Duration(seconds: 15), () {
      iframe.remove();
    });
  } catch (_) {}
}

/// Descarga bytes como un archivo CSV usando un elemento anchor oculto.
void downloadCsvBytes(List<int> bytes, String filename) {
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

