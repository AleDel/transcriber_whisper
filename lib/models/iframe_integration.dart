import 'dart:js';
import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:transcriber_whisper/transcription_cubit.dart';

class IframeIntegration {
  void exposeFunctionToJs({required GetIt getIt}) {
    // Exponer la función a JavaScript
    context['enviarDatosDesdeIframe'] = (String rutaAudio, String textoReferencia, String jsonTranscripcion) {
      _recibirDatos(rutaAudio, textoReferencia, jsonTranscripcion, getIt: getIt);
    };
  }

  void _recibirDatos(String rutaAudio, String textoReferencia, String rutaJson, {required GetIt getIt}) async {
    print("____recibirDatos >>>>>>>>>>>>>>> rutaAudio: $rutaAudio,\ntextoReferencia: $textoReferencia,\nrutaJson: $rutaJson");
    // Decodificar el JSON
    List<Map<String, dynamic>> jsonList = [];
    String text = "";
    try {
      final response = await http.get(Uri.parse(rutaJson));
      if (response.statusCode == 200) {
        jsonList = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      } else {
        print('Error al obtener el JSON: ${response.statusCode}');
      }
      final responseText = await http.get(Uri.parse(textoReferencia));
      if (responseText.statusCode == 200) {
        text = responseText.body;
      } else {
        print('Error al obtener el texto: ${responseText.statusCode}');
      }
      getIt<TranscriptionCubit>().useReal(jsonList, rutaAudio, text);
    } catch (e) {
      print('Error al decodificar el JSON: $e');
    }
  }
}