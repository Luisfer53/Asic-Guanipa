import 'package:flutter_test/flutter_test.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';

void main() {
  group('PacienteSearchMatcher', () {
    test('coincide por nombre, apellido y cédula', () {
      final paciente = Paciente(
        idPaciente: 1,
        idPersona: 1,
        persona: Persona(
          idPersona: 1,
          nombre1: 'Luis',
          apellido1: 'Hernández',
          cedulaIdentidad: '30346936',
        ),
      );

      expect(PacienteSearchMatcher.matches(paciente, 'luis'), isTrue);
      expect(PacienteSearchMatcher.matches(paciente, 'hernandez'), isTrue);
      expect(PacienteSearchMatcher.matches(paciente, '30346936'), isTrue);
    });

    test('devuelve falso cuando no hay coincidencia', () {
      final paciente = Paciente(
        idPaciente: 2,
        idPersona: 2,
        persona: Persona(
          idPersona: 2,
          nombre1: 'Ana',
          apellido1: 'Pérez',
          cedulaIdentidad: '12345678',
        ),
      );

      expect(PacienteSearchMatcher.matches(paciente, 'luis'), isFalse);
    });
  });
}
