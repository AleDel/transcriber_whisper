import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../constants.dart';

class MfaService {
  Future<Map<String, dynamic>?> align(Uint8List audioBytes, String text) async {
    final url = Uri.parse(AppConstants.mfaUrl); // URL del servidor MFA
    final request = http.MultipartRequest('POST', url);
    request.files.add(http.MultipartFile.fromBytes('audio', audioBytes, filename: 'audio.wav'));
    request.fields['text'] = text;

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody.containsKey('alignment')) {
          return responseBody['alignment'];
        } else {
          print('Error: La respuesta del servidor MFA no contiene "alignment".');
          return null;
        }
      } else {
        print('Error en la solicitud MFA: ${response.statusCode}');
        print('Cuerpo de la respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error en la solicitud MFA: $e');
      return null;
    }
  }
}