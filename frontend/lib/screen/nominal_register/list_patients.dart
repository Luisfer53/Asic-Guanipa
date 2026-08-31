import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/services/api_service.dart';
import 'package:asis_guanipa_frontend/components/card_paciente.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/create_patient_dialog.dart';
import 'package:asis_guanipa_frontend/utils/upper_case_text_formatter.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ListPatients extends StatefulWidget {
  const ListPatients({super.key});

  @override
  State<ListPatients> createState() => _ListPatientsState();
}

class _ListPatientsState extends State<ListPatients> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  List<Paciente> _pacientes = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasMoreData = true;
  String _activeSearch = '';

  @override
  void initState() {
    super.initState();
    final searchParam = GoRouterState.of(context).uri.queryParameters['search'] ?? '';
    _searchController.text = searchParam;
    _activeSearch = searchParam;
    _loadPacientes(reset: true, searchText: searchParam);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final searchParam = GoRouterState.of(context).uri.queryParameters['search'] ?? '';
    if (searchParam != _activeSearch && _searchController.text != searchParam) {
      _searchController.value = TextEditingValue(
        text: searchParam,
        selection: TextSelection.collapsed(offset: searchParam.length),
      );
      _activeSearch = searchParam;
      _loadPacientes(reset: true, searchText: searchParam);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMoreData) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePacientes();
    }
  }

  void _scheduleSearch(String value) {
    final search = value.trim();
    if (_searchDebounce?.isActive ?? false) {
      _searchDebounce!.cancel();
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      if (search == _activeSearch) return;

      _activeSearch = search;
      await _loadPacientes(reset: true, searchText: search);
    });
  }

  Future<void> _loadPacientes({bool reset = true, String? searchText}) async {
    final effectiveSearch = (searchText ?? _activeSearch).trim();

    if (reset) {
      setState(() {
        _currentPage = 1;
        _pacientes = [];
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
        _hasMoreData = true;
        _activeSearch = effectiveSearch;
      });
    } else {
      setState(() {
        _activeSearch = effectiveSearch;
      });
    }

    try {
      final response = await _apiService.getPacientes(
        page: 1,
        search: effectiveSearch.isNotEmpty ? effectiveSearch : null,
      );

      if (mounted) {
        setState(() {
          if (response.success) {
            final filtered = effectiveSearch.isEmpty
                ? response.data
                : response.data.where((paciente) => PacienteSearchMatcher.matches(paciente, effectiveSearch)).toList();

            _pacientes = filtered;
            _hasMoreData = false;
          } else {
            _hasError = true;
            _errorMessage = 'Error al cargar pacientes';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error de conexión';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMorePacientes() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final response = await _apiService.getPacientes(
        page: nextPage,
        search: _activeSearch.isNotEmpty ? _activeSearch : null,
      );

      if (mounted) {
        setState(() {
          if (response.success && response.data.isNotEmpty) {
            final filtered = _activeSearch.isEmpty
                ? response.data
                : response.data.where((paciente) => PacienteSearchMatcher.matches(paciente, _activeSearch)).toList();
            _pacientes.addAll(filtered);
            _currentPage = nextPage;
            _hasMoreData = response.data.length >= 20;
          } else {
            _hasMoreData = false;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _applySearch([String? searchText, bool updateRoute = true]) async {
    final effectiveSearch = (searchText ?? _searchController.text).trim();

    if (effectiveSearch == _activeSearch && _searchController.text == effectiveSearch) {
      return;
    }

    _searchController.value = TextEditingValue(
      text: effectiveSearch,
      selection: TextSelection.collapsed(offset: effectiveSearch.length),
    );
    _activeSearch = effectiveSearch;

    if (updateRoute && mounted) {
      final route = effectiveSearch.isEmpty
          ? '/list-patients'
          : '/list-patients?search=${Uri.encodeQueryComponent(effectiveSearch)}';
      context.go(route);
    }

    await _loadPacientes(reset: true, searchText: effectiveSearch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Pacientes'),
        backgroundColor: Colors.blue,
        actions: [
          if (_currentPage > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Página $_currentPage',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePatientDialog(context),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre, apellido o cédula',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        _searchController.clear();
                        await _applySearch('', true);
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onChanged: (value) {
              _scheduleSearch(value);
            },
            onSubmitted: (_) async => _applySearch(_searchController.text, true),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'Error desconocido',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () async => _applySearch(_activeSearch, false),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _pacientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No se encontraron pacientes',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: _pacientes.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _pacientes.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return CardPaciente(
                      paciente: _pacientes[index],
                      onPatientUpdated: ([String? _]) => _loadPacientes(),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreatePatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreatePatientDialog(
        onPatientCreated: ([String? searchKey]) async {
          await _applySearch(searchKey ?? _activeSearch, true);
        },
      ),
    );
  }
}
