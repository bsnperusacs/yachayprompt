// lib/services/mercado_pago_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

class MercadoPagoService {
  final String baseUrl = 'https://creargrupoconpago-y7hx6h3sxa-uc.a.run.app';

  Future<Map<String, dynamic>> crearGrupo(Map<String, dynamic> data) async {
    final url = Uri.parse(baseUrl);

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error en crear grupo: ${response.body}');
    }
  }
}
