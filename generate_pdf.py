import os
import glob
from PIL import Image, ImageDraw, ImageFont

CAPTURAS_DIR = '/home/luis/Documentos/Proyecto-Uptjaa-CDI/capturas_interfaz'
OUTPUT_PDF = '/home/luis/Documentos/Proyecto-Uptjaa-CDI/capturas_interfaz/manual_pantallas_sistema_cdi.pdf'
OUTPUT_PDF_ROOT = '/home/luis/Documentos/Proyecto-Uptjaa-CDI/manual_pantallas_sistema_cdi.pdf'

TITULOS = {
    '01_login.png': '1. Pantalla de Inicio de Sesión (Login)',
    '02_dashboard_home.png': '2. Panel Principal / Dashboard',
    '03_jornada_diaria.png': '3. Módulo: Jornada / Atención Médica Diaria',
    '04_registro_nominal_pacientes.png': '4. Módulo: Registro Nominal de Pacientes',
    '05_almacen_insumos.png': '5. Módulo: Almacén e Insumos Médicos',
    '06_reportes_estadisticas.png': '6. Módulo: Reportes Epidemiológicos y Estadísticas',
    '07_descartes_biologicos.png': '7. Módulo: Gestión de Descartes Biológicos',
    '08_seguridad_usuarios.png': '8. Módulo: Seguridad y Control de Usuarios',
    '09_movil_jornada_diaria.png': '9. Vista Móvil: Jornada Diaria (Responsivo)',
    '10_movil_almacen.png': '10. Vista Móvil: Almacén e Insumos (Responsivo)',
    '11_movil_reportes.png': '11. Vista Móvil: Reportes y Estadísticas (Responsivo)',
}

def create_page_with_header(img_path, title_text):
    # Abrir captura original
    orig = Image.open(img_path).convert('RGB')
    
    # Dimensiones para la página del PDF (Letter landscape o portrait proporcional)
    page_w = 1600
    page_h = 1100
    
    page = Image.new('RGB', (page_w, page_h), color=(248, 250, 252))
    draw = ImageDraw.Draw(page)
    
    # Barra superior de encabezado
    draw.rectangle([(0, 0), (page_w, 70)], fill=(21, 101, 192)) # Azul institucional #1565C0
    draw.rectangle([(0, 70), (page_w, 75)], fill=(245, 166, 35)) # Acento dorado #F5A623
    
    # Título en el encabezado
    draw.text((30, 22), f"ASIC Guanipa — {title_text}", fill=(255, 255, 255))
    
    # Redimensionar la imagen para que quepa en el área de contenido con márgenes
    content_w = page_w - 60
    content_h = page_h - 110
    
    # Mantener aspect ratio
    orig_ratio = orig.width / orig.height
    content_ratio = content_w / content_h
    
    if orig_ratio > content_ratio:
        # Limitado por ancho
        new_w = content_w
        new_h = int(content_w / orig_ratio)
    else:
        # Limitado por alto
        new_h = content_h
        new_w = int(content_h * orig_ratio)
        
    resized_orig = orig.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Centrar la imagen en la página
    pos_x = (page_w - new_w) // 2
    pos_y = 90 + (content_h - new_h) // 2
    
    # Sombra/borde suave alrededor de la captura
    draw.rectangle([(pos_x - 3, pos_y - 3), (pos_x + new_w + 3, pos_y + new_h + 3)], fill=(226, 232, 240))
    page.paste(resized_orig, (pos_x, pos_y))
    
    return page

# Portada
def create_cover_page():
    page_w = 1600
    page_h = 1100
    page = Image.new('RGB', (page_w, page_h), color=(13, 71, 161))
    draw = ImageDraw.Draw(page)
    
    # Acento dorado
    draw.rectangle([(0, 0), (page_w, 15)], fill=(245, 166, 35))
    draw.rectangle([(0, page_h - 15), (page_w, page_h)], fill=(245, 166, 35))
    
    draw.text((100, 320), "SISTEMA DE GESTIÓN DE SALUD", fill=(245, 166, 35))
    draw.text((100, 380), "ASIC Guanipa / CDI Pedro Urbina", fill=(255, 255, 255))
    draw.text((100, 480), "Catálogo de Pantallas e Interfaces del Sistema", fill=(227, 242, 253))
    draw.text((100, 540), "Vistas Web de Escritorio y Adaptabilidad Móvil", fill=(179, 229, 252))
    
    draw.text((100, 850), "UPTJAA — Proyecto Sociotecnológico CDI", fill=(255, 255, 255))
    draw.text((100, 890), "Generado automáticamente — Año 2026", fill=(200, 225, 255))
    
    return page

files = sorted([f for f in os.listdir(CAPTURAS_DIR) if f.endswith('.png')])

pages = []
# 1. Portada
pages.append(create_cover_page())

# 2. Páginas de capturas
for f in files:
    img_path = os.path.join(CAPTURAS_DIR, f)
    title = TITULOS.get(f, f)
    print(f"Procesando página para: {f} -> {title}")
    page = create_page_with_header(img_path, title)
    pages.append(page)

# Guardar PDF
if pages:
    pages[0].save(
        OUTPUT_PDF,
        save_all=True,
        append_images=pages[1:],
        resolution=150.0
    )
    pages[0].save(
        OUTPUT_PDF_ROOT,
        save_all=True,
        append_images=pages[1:],
        resolution=150.0
    )
    print(f"\n✓ PDF generado exitosamente en:\n  - {OUTPUT_PDF}\n  - {OUTPUT_PDF_ROOT}")

