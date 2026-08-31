import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AlmacenScreen extends StatefulWidget {
  const AlmacenScreen({super.key});

  @override
  State<AlmacenScreen> createState() => _AlmacenScreenState();
}

class _AlmacenScreenState extends State<AlmacenScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  // Lists
  List<Map<String, dynamic>> _articulos = [];
  List<Map<String, dynamic>> _lotes = [];
  List<Map<String, dynamic>> _proveedores = [];
  List<Map<String, dynamic>> _centros = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch articles
      final artRes = await _apiService.getArticulos();
      if (artRes['success'] == true) {
        _articulos = List<Map<String, dynamic>>.from(artRes['data'] ?? []);
      }

      // 2. Fetch inventory (lotes)
      final invRes = await _apiService.getInventario();
      if (invRes['success'] == true) {
        _lotes = List<Map<String, dynamic>>.from(invRes['data'] ?? []);
      }

      // 3. Fetch suppliers
      final provRes = await _apiService.getProveedores();
      if (provRes['success'] == true) {
        _proveedores = List<Map<String, dynamic>>.from(provRes['data'] ?? []);
      }

      // 4. Fetch centers
      final centRes = await _apiService.getCentros();
      if (centRes['success'] == true) {
        _centros = List<Map<String, dynamic>>.from(centRes['data'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos del almacén: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DIÁLOGOS DE ARTÍCULOS (CREAR / EDITAR / ELIMINAR)
  // ───────────────────────────────────────────────────────────────────────────

  void _showArticuloDialog({Map<String, dynamic>? articulo}) {
    final formKey = GlobalKey<FormState>();
    final nombreCtrl = TextEditingController(
      text: articulo?['nombre_articulo'] ?? '',
    );
    final unidadCtrl = TextEditingController(
      text: articulo?['unidad_medida'] ?? 'Unidades',
    );
    final descCtrl = TextEditingController(
      text: articulo?['descripcion'] ?? '',
    );
    final stockMinCtrl = TextEditingController(
      text: (articulo?['stock_minimo_alerta'] ?? 10).toString(),
    );
    String selectedTipo = articulo?['tipo'] ?? 'Insumo';

    final isEdit = articulo != null;
    final int? artId = articulo?['id_articulo'] ?? articulo?['id'];

    const tipos = ['Vacuna', 'Insumo', 'Medicamento', 'Equipo'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(
            isEdit ? 'Editar Artículo Médico' : 'Registrar Artículo Médico',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo de artículo
                  DropdownButtonFormField<String>(
                    initialValue: selectedTipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Artículo *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: tipos
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Row(
                              children: [
                                Icon(
                                  t == 'Vacuna'
                                      ? Icons.vaccines
                                      : t == 'Medicamento'
                                      ? Icons.medication
                                      : t == 'Equipo'
                                      ? Icons.medical_information
                                      : Icons.inventory_2_outlined,
                                  size: 18,
                                  color: t == 'Vacuna'
                                      ? Colors.green
                                      : t == 'Medicamento'
                                      ? Colors.blue
                                      : t == 'Equipo'
                                      ? Colors.orange
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(t),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setStateDialog(() => selectedTipo = val ?? 'Insumo'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [UpperCaseTextFormatter()],
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Artículo *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Ingrese el nombre'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: unidadCtrl,
                    decoration: const InputDecoration(
                      labelText:
                          'Unidad de Medida * (e.g. Unidades, Dosis, ML, Frasco)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Ingrese la unidad'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Presentación (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: stockMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Mínimo para Alerta (Semáforo)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val != null &&
                          val.isNotEmpty &&
                          int.tryParse(val) == null) {
                        return 'Ingrese un número válido';
                      }
                      return null;
                    },
                  ),
                  if (selectedTipo != 'Vacuna')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Solo los artículos de tipo Vacuna aparecen en los esquemas de dosificación.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);

                final nombre = nombreCtrl.text.trim();
                final unidad = unidadCtrl.text.trim();
                final desc = descCtrl.text.trim();
                final stockMin = int.tryParse(stockMinCtrl.text.trim());

                Map<String, dynamic> res;
                if (isEdit && artId != null) {
                  res = await _apiService.actualizarArticulo(
                    id: artId,
                    nombreArticulo: nombre,
                    unidadMedida: unidad,
                    tipo: selectedTipo,
                    descripcion: desc.isEmpty ? null : desc,
                    stockMinimoAlerta: stockMin,
                  );
                } else {
                  res = await _apiService.registrarArticulo(
                    nombre,
                    unidad,
                    tipo: selectedTipo,
                    descripcion: desc.isEmpty ? null : desc,
                    stockMinimoAlerta: stockMin,
                  );
                }

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message'] ??
                            (isEdit
                                ? 'Artículo actualizado'
                                : 'Artículo registrado'),
                      ),
                      backgroundColor: res['success'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarArticulo(int id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Artículo Médico'),
        content: Text(
          '¿Está seguro de eliminar "$nombre"? Se perderán los datos asociados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final res = await _apiService.eliminarArticulo(id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Procesado'),
            backgroundColor: res['success'] == true ? Colors.green : Colors.red,
          ),
        );
        if (res['success'] == true) _fetchData();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // DIÁLOGOS DE LOTES (CREAR / EDITAR / ELIMINAR)
  // ───────────────────────────────────────────────────────────────────────────

  void _showLoteDialog({Map<String, dynamic>? lote}) {
    if (_articulos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero registre al menos un artículo médico'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isEdit = lote != null;
    final int? loteId = lote?['id_lote_insumo'] ?? lote?['id'];

    final formKey = GlobalKey<FormState>();
    final numeroLoteCtrl = TextEditingController(
      text: lote?['numero_lote'] ?? '',
    );
    final stockCtrl = TextEditingController(
      text: (lote?['stock_actual'] ?? 100).toString(),
    );

    // Selections
    int? selectedArtId =
        lote?['id_articulo'] ?? (lote?['articulo']?['id_articulo']);
    selectedArtId ??= _articulos.first['id_articulo'];

    int? selectedProvId =
        lote?['id_proveedor'] ?? (lote?['proveedor']?['id_proveedor']);
    int? selectedCentroId =
        lote?['id_centro'] ?? (lote?['centro']?['id_centro']);

    DateTime? fechaVenc;
    if (lote?['fecha_vencimiento'] != null) {
      fechaVenc = DateTime.tryParse(lote!['fecha_vencimiento'].toString());
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            isEdit ? 'Editar Lote de Insumo' : 'Registrar Lote de Insumo',
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Artículo Médico
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Artículo Médico *',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedArtId,
                    items: _articulos.map((a) {
                      final int id = a['id_articulo'] ?? a['id'];
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(a['nombre_articulo'] ?? 'N/A'),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedArtId = val),
                    validator: (val) =>
                        val == null ? 'Seleccione un artículo' : null,
                  ),
                  const SizedBox(height: 14),

                  // Número de Lote
                  TextFormField(
                    controller: numeroLoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de Lote *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Ingrese número de lote'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // Stock Actual
                  TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stock Actual *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty)
                        return 'Ingrese el stock';
                      if (int.tryParse(val) == null || int.parse(val) < 0)
                        return 'Ingrese número válido';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Proveedor (Opcional) con botón de creación rápida
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          decoration: const InputDecoration(
                            labelText: 'Proveedor (Opcional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_shipping_outlined),
                          ),
                          initialValue: selectedProvId,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sin especificar'),
                            ),
                            ..._proveedores.map((p) {
                              final int id = p['id_proveedor'] ?? p['id'];
                              return DropdownMenuItem<int?>(
                                value: id,
                                child: Text(
                                  p['nombre_proveedor'] ?? 'N/A',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) =>
                              setDialogState(() => selectedProvId = val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.add_business_outlined,
                          color: Color(0xFF0D47A1),
                        ),
                        tooltip: 'Crear nuevo proveedor',
                        onPressed: () =>
                            _quickAddProveedor(setDialogState, (newId) {
                              selectedProvId = newId;
                            }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Centro de Salud (Opcional)
                  DropdownButtonFormField<int?>(
                    decoration: const InputDecoration(
                      labelText: 'Centro de Salud (Opcional)',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: selectedCentroId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ASIC Guanipa (Principal)'),
                      ),
                      ..._centros.map((c) {
                        final int id = c['id_centro'] ?? c['id'];
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Text(c['nombre_centro'] ?? 'N/A'),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => selectedCentroId = val),
                  ),
                  const SizedBox(height: 14),

                  // Fecha de Vencimiento
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate:
                            fechaVenc ??
                            DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365 * 15),
                        ),
                      );
                      if (picked != null) {
                        setDialogState(() => fechaVenc = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Vencimiento *',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        fechaVenc != null
                            ? '${fechaVenc!.day.toString().padLeft(2, '0')}/${fechaVenc!.month.toString().padLeft(2, '0')}/${fechaVenc!.year}'
                            : 'Seleccionar fecha',
                        style: TextStyle(
                          color: fechaVenc != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                if (fechaVenc == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Seleccione fecha de vencimiento'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final nav = Navigator.of(ctx);

                final numLote = numeroLoteCtrl.text.trim();
                final stock = int.parse(stockCtrl.text.trim());
                final fechaStr = fechaVenc!.toIso8601String().split('T')[0];

                Map<String, dynamic> res;
                if (isEdit && loteId != null) {
                  res = await _apiService.actualizarLote(
                    id: loteId,
                    idArticulo: selectedArtId,
                    numeroLote: numLote,
                    stockActual: stock,
                    fechaVencimiento: fechaStr,
                    idProveedor: selectedProvId,
                    idCentro: selectedCentroId,
                  );
                } else {
                  res = await _apiService.registrarLote(
                    idArticulo: selectedArtId!,
                    numeroLote: numLote,
                    stockActual: stock,
                    fechaVencimiento: fechaStr,
                    idProveedor: selectedProvId,
                    idCentro: selectedCentroId,
                  );
                }

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message'] ??
                            (isEdit ? 'Lote actualizado' : 'Lote registrado'),
                      ),
                      backgroundColor: res['success'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  );
                  if (res['success'] == true) {
                    nav.pop();
                    _fetchData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              child: Text(isEdit ? 'Actualizar' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarLote(int id, String numLote) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Lote'),
        content: Text('¿Está seguro de eliminar el Lote N° "$numLote"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final res = await _apiService.eliminarLote(id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Procesado'),
            backgroundColor: res['success'] == true ? Colors.green : Colors.red,
          ),
        );
        if (res['success'] == true) _fetchData();
      }
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // VISTAS PRINCIPALES
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Almacén e Insumos'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.description_outlined),
              text: isMobile ? 'Artículos' : 'Artículos Médicos',
            ),
            Tab(
              icon: const Icon(Icons.layers_outlined),
              text: isMobile ? 'Lotes' : 'Lotes / Existencias',
            ),
            Tab(
              icon: const Icon(Icons.local_shipping_outlined),
              text: isMobile ? 'Proveedores' : 'Proveedores',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildArticulosTab(),
                _buildLotesTab(),
                _buildProveedoresTab(),
              ],
            ),
    );
  }

  Widget _buildArticulosTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showArticuloDialog(),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo Artículo',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _articulos.isEmpty
          ? const Center(child: Text('No hay artículos médicos registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _articulos.length,
              itemBuilder: (context, index) {
                final art = _articulos[index];
                final int artId = art['id_articulo'] ?? art['id'] ?? 0;
                final nombre = art['nombre_articulo'] ?? 'N/A';
                final unidad = art['unidad_medida'] ?? 'N/A';
                final desc = art['descripcion'];
                final stockMin = art['stock_minimo_alerta'];
                final tipo = art['tipo'] ?? 'Insumo';

                Color tipoColor = tipo == 'Vacuna'
                    ? Colors.green
                    : tipo == 'Medicamento'
                    ? Colors.blue
                    : tipo == 'Equipo'
                    ? Colors.orange
                    : Colors.grey;
                IconData tipoIcon = tipo == 'Vacuna'
                    ? Icons.vaccines
                    : tipo == 'Medicamento'
                    ? Icons.medication
                    : tipo == 'Equipo'
                    ? Icons.medical_information
                    : Icons.inventory_2_outlined;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: tipoColor.withValues(alpha: 0.15),
                      foregroundColor: tipoColor,
                      child: Icon(tipoIcon),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: tipoColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tipo,
                            style: TextStyle(
                              fontSize: 11,
                              color: tipoColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Unidad de Medida: $unidad  ·  Umbral Alerta: ${stockMin ?? "10"}',
                        ),
                        if (desc != null && desc.toString().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Descripción: $desc',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          tooltip: 'Editar Artículo',
                          onPressed: () => _showArticuloDialog(articulo: art),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.red,
                          ),
                          tooltip: 'Eliminar Artículo',
                          onPressed: () => _eliminarArticulo(artId, nombre),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLotesTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLoteDialog(),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nuevo Lote', style: TextStyle(color: Colors.white)),
      ),
      body: _lotes.isEmpty
          ? const Center(child: Text('No hay lotes en existencia.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lotes.length,
              itemBuilder: (context, index) {
                final lote = _lotes[index];
                final int loteId = lote['id_lote_insumo'] ?? lote['id'] ?? 0;
                final String numLote = lote['numero_lote'] ?? 'N/A';
                final String artNombre =
                    lote['articulo']?['nombre_articulo'] ??
                    lote['nombre_articulo'] ??
                    'N/A';

                final String provNombre =
                    lote['proveedor']?['nombre_proveedor'] ?? 'No especificado';
                final String centroNombre =
                    lote['centro']?['nombre_centro'] ?? 'ASIC Guanipa';

                final alert = lote['alertas'] ?? {};
                final isStockBajo = alert['stock_bajo'] == true;
                final isVencido = alert['vencido'] == true;
                final isProximoVencer = alert['proximo_vencer'] == true;

                Color cardColor = Colors.white;
                String alertText = '';

                if (isVencido) {
                  cardColor = Colors.red.shade50;
                  alertText = 'VENCIDO';
                } else if (isStockBajo) {
                  cardColor = Colors.orange.shade50;
                  alertText = 'STOCK BAJO';
                } else if (isProximoVencer) {
                  cardColor = Colors.amber.shade50;
                  alertText = 'PRÓXIMO A VENCER';
                }

                return Card(
                  color: cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isVencido
                                  ? Colors.red.shade200
                                  : const Color(0xFFE3F2FD),
                              child: Icon(
                                isVencido
                                    ? Icons.dangerous_outlined
                                    : Icons.inventory_2_outlined,
                                color: isVencido
                                    ? Colors.red.shade900
                                    : const Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    artNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    'Lote: $numLote  |  Stock: ${lote['stock_actual']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (alertText.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isVencido
                                      ? Colors.red
                                      : isStockBajo
                                      ? Colors.orange
                                      : Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  alertText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.event_outlined,
                                        size: 15,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Vence: ${lote['fecha_vencimiento']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.local_shipping_outlined,
                                        size: 15,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Proveedor: $provNombre',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.business_outlined,
                                        size: 15,
                                        color: Colors.blueGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Centro: $centroNombre',
                                          style: const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                              ),
                              tooltip: 'Editar Lote',
                              onPressed: () => _showLoteDialog(lote: lote),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                              ),
                              tooltip: 'Eliminar Lote',
                              onPressed: () => _eliminarLote(loteId, numLote),
                            ),
                          ],
                        ),
                        // Botón de descarte cuando el lote está vencido o próximo a vencer
                        if (isVencido || isProximoVencer) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              onPressed: () => _showDescarteDialog(lote),
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Gestión de Biológicos (Evidencia)',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ─── DIÁLOGO DE GESTIÓN DE BIOLÓGICOS / EVIDENCIA FOTOGRÁFICA ─────────────
  Future<void> _showDescarteDialog(Map<String, dynamic> lote) async {
    final formKey = GlobalKey<FormState>();
    final actaCtrl = TextEditingController();
    final justCtrl = TextEditingController();
    final metodoCtrl = TextEditingController(
      text: 'Destrucción / Incineración',
    );
    DateTime fechaRetiro = DateTime.now();
    XFile? fotoFile;
    String? fotoBase64;
    bool loading = false;
    int? movimientoId;

    final artNombre = lote['articulo']?['nombre_articulo'] ?? 'Insumo';
    final numLote = lote['numero_lote'] ?? '';
    final int loteId = lote['id_lote_insumo'] ?? lote['id'] ?? 0;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Gestión de Biológicos: $artNombre',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Lote: $numLote  |  Stock: ${lote['stock_actual']}  |  Vence: ${lote['fecha_vencimiento'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      controller: actaCtrl,
                      decoration: const InputDecoration(
                        labelText: 'N° Acta de Descarte (Opcional)',
                        hintText: 'Ej: ACTA-2026-001',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      controller: metodoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Método de Disposición *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.recycling_rounded),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      controller: justCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Justificación / Observaciones',
                        hintText: 'Motivo del descarte...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Fecha de Retiro: ${fechaRetiro.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: ctx,
                              initialDate: fechaRetiro,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setS(() => fechaRetiro = d);
                          },
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                          ),
                          label: const Text('Cambiar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Evidencia Fotográfica:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (fotoFile != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: kIsWeb
                            ? (fotoBase64 != null
                                  ? Image.memory(
                                      base64Decode(fotoBase64!.split(',').last),
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : const SizedBox())
                            : Image.file(
                                File(fotoFile!.path),
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      TextButton.icon(
                        onPressed: () => setS(() {
                          fotoFile = null;
                          fotoBase64 = null;
                        }),
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('Quitar Foto'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final f = await picker.pickImage(
                                  source: ImageSource.camera,
                                  imageQuality: 60,
                                );
                                if (f != null) {
                                  final bytes = await f.readAsBytes();
                                  final b64 =
                                      'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  setS(() {
                                    fotoFile = f;
                                    fotoBase64 = b64;
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Cámara',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picker = ImagePicker();
                                final f = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 60,
                                );
                                if (f != null) {
                                  final bytes = await f.readAsBytes();
                                  final b64 =
                                      'data:image/jpeg;base64,${base64Encode(bytes)}';
                                  setS(() {
                                    fotoFile = f;
                                    fotoBase64 = b64;
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.photo_library_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Galería',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (movimientoId != null) ...[
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Registro de biológicos procesado exitosamente',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final url = await _apiService.getNotaSalidaUrl(
                              movimientoId!,
                            );
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Ver Nota de Salida (PDF con QR)'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: movimientoId != null
              ? [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cerrar'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: loading ? null : () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: loading
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setS(() => loading = true);
                            final r = await _apiService.descartarLotes(
                              ids: [loteId],
                              metodoDisposicion: metodoCtrl.text.trim(),
                              fechaRetiro: fechaRetiro.toIso8601String().split(
                                'T',
                              )[0],
                              justificacion: justCtrl.text.trim().isNotEmpty
                                  ? justCtrl.text.trim()
                                  : null,
                              numeroActaDescarte:
                                  actaCtrl.text.trim().isNotEmpty
                                  ? actaCtrl.text.trim()
                                  : null,
                              fotoEvidencia: fotoBase64,
                            );
                            if (r['success'] == true) {
                              final primId = r['primer_movimiento_id'];
                              setS(() {
                                loading = false;
                                movimientoId = primId is int
                                    ? primId
                                    : int.tryParse(primId.toString());
                              });
                              await _fetchData();
                            } else {
                              setS(() => loading = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      r['message'] ??
                                          'Error al procesar registro',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shield_outlined),
                    label: Text(
                      loading ? 'Procesando...' : 'Registrar Gestión',
                    ),
                  ),
                ],
        ),
      ),
    );
  }

  Future<void> _quickAddProveedor(
    void Function(void Function()) setDialogState,
    void Function(int newId) onCreated,
  ) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final rifCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo Proveedor'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Proveedor *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese el nombre'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                controller: rifCtrl,
                decoration: const InputDecoration(
                  labelText: 'RIF (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseTextFormatter()],
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final res = await _apiService.registrarProveedor(
                nombreProveedor: nameCtrl.text.trim(),
                rif: rifCtrl.text.trim().isEmpty ? null : rifCtrl.text.trim(),
                telefono: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
              );
              if (mounted && res['success'] == true) {
                final newProv = res['data'];
                final int newId = newProv['id_proveedor'] ?? newProv['id'];
                // Update local list
                await _fetchData();
                setDialogState(() {
                  onCreated(newId);
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showProveedorDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final rifCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dirCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Proveedor'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Proveedor *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Ingrese el nombre'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: rifCtrl,
                  decoration: const InputDecoration(
                    labelText: 'RIF (Ej: J-12345678-0)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [UpperCaseTextFormatter()],
                  controller: dirCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dirección',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final res = await _apiService.registrarProveedor(
                nombreProveedor: nameCtrl.text.trim(),
                rif: rifCtrl.text.trim().isEmpty ? null : rifCtrl.text.trim(),
                telefono: phoneCtrl.text.trim().isEmpty
                    ? null
                    : phoneCtrl.text.trim(),
                direccion: dirCtrl.text.trim().isEmpty
                    ? null
                    : dirCtrl.text.trim(),
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Proveedor registrado'),
                    backgroundColor: res['success'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                );
                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  _fetchData();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _buildProveedoresTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProveedorDialog,
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add_business_outlined, color: Colors.white),
        label: const Text(
          'Nuevo Proveedor',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _proveedores.isEmpty
          ? const Center(child: Text('No hay proveedores registrados.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _proveedores.length,
              itemBuilder: (context, index) {
                final p = _proveedores[index];
                final nombre = p['nombre_proveedor'] ?? 'N/A';
                final rif = p['rif'];
                final tel = p['telefono'];
                final dir = p['direccion'];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      foregroundColor: Colors.green,
                      child: Icon(Icons.local_shipping_outlined),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rif != null && rif.toString().isNotEmpty)
                          Text(
                            'RIF: $rif',
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (tel != null && tel.toString().isNotEmpty)
                          Text(
                            'Teléfono: $tel',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        if (dir != null && dir.toString().isNotEmpty)
                          Text(
                            'Dirección: $dir',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
