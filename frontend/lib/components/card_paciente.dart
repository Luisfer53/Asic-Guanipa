import 'package:flutter/material.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/create_patient_dialog.dart';
import 'package:asis_guanipa_frontend/screen/nominal_register/patient_history_screen.dart';

class CardPaciente extends StatelessWidget {
  final Paciente paciente;
  final Function([String?]) onPatientUpdated;

  const CardPaciente({
    super.key,
    required this.paciente,
    required this.onPatientUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showHistorial(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(
                      0xFF1565C0,
                    ).withValues(alpha: 0.1),
                    child: Icon(
                      paciente.sexo == 'M'
                          ? Icons.person
                          : Icons.person_outline,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${paciente.nombre} ${paciente.apellido}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (paciente.cedula.isNotEmpty)
                          Text(
                            'CI: ${paciente.cedula}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Botón historial
                  IconButton(
                    icon: const Icon(Icons.history, color: Color(0xFF1565C0)),
                    tooltip: 'Ver Historial',
                    onPressed: () => _showHistorial(context),
                  ),
                  // Botón editar
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                    tooltip: 'Editar Paciente',
                    onPressed: () => _showEditPatientDialog(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.cake,
                      _formatDate(paciente.fechaNacimiento),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.wc,
                      paciente.sexo == 'M'
                          ? 'Masculino'
                          : paciente.sexo == 'F'
                          ? 'Femenino'
                          : paciente.sexo,
                    ),
                  ),
                ],
              ),
              if (paciente.telefono != null &&
                  paciente.telefono!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoRow(Icons.phone, paciente.telefono!),
              ],
              if (paciente.direccion != null &&
                  paciente.direccion!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoRow(Icons.location_on, paciente.direccion!),
              ],
              if (paciente.nombreRepresentante != null &&
                  paciente.nombreRepresentante!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  Icons.person_outline,
                  'Rep: ${paciente.nombreRepresentante} ${paciente.apellidoRepresentante ?? ''}',
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showHistorial(context),
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text('Ver historial'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1565C0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    if (date.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  void _showHistorial(BuildContext context) {
    final String identifier = paciente.cedula.isNotEmpty
        ? paciente.cedula
        : paciente.id.toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PatientHistoryScreen(
          pacienteId: identifier,
          nombrePaciente: paciente.nombreCompleto.isNotEmpty
              ? paciente.nombreCompleto
              : '${paciente.nombre} ${paciente.apellido}',
        ),
      ),
    );
  }

  void _showEditPatientDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CreatePatientDialog(
        paciente: paciente,
        onPatientCreated: onPatientUpdated,
      ),
    );
  }
}
