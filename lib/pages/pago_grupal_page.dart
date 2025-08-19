// Archivo: lib/pages/pago_grupal_page.dart

import 'package:flutter/material.dart';

class PagoGrupalPage extends StatelessWidget {
  final String paymentUrl;
  final String grupoId;

  const PagoGrupalPage({
    super.key,
    required this.paymentUrl,
    required this.grupoId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realizar Pago'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Redirigiendo a la página de pago...',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('URL de Pago'),
                        content: Text(paymentUrl),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Cerrar'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: const Text('Ir a Pagar'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}