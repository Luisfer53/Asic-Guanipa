import 'package:flutter/material.dart';

class CardSimple extends StatelessWidget {
  const CardSimple({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              Text('Nombre:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Apellido:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Cedula:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Fecha de Nacimiento:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Telefono:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Direccion:', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
