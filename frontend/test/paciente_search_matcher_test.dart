import 'package:flutter_test/flutter_test.dart';
import 'package:asis_guanipa_frontend/models/paciente.dart';

void main() {
  group('PacienteSearchMatcher', () {
    final paciente = Paciente(
      idPaciente: 1,
      idPersona: 1,
      persona: Persona(
        idPersona: 1,
        nombre1: 'Juan',
        nombre2: 'Antonio',
        apellido1: 'Pérez',
        apellido2: 'García',
        cedulaIdentidad: '12345678',
        sexo: 'M',
      ),
    );

    test('matches a full name query with spaces', () {
      expect(PacienteSearchMatcher.matches(paciente, 'Juan Pérez'), isTrue);
    });

    test('matches surname and name in either order', () {
      expect(PacienteSearchMatcher.matches(paciente, 'Pérez Juan'), isTrue);
    });

    test('matches by surname only', () {
      expect(PacienteSearchMatcher.matches(paciente, 'Garcia'), isTrue);
    });
  });
}
