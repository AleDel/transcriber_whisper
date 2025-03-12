// constants.dart
class AppConstants {
  //static const String alignUrl = 'http://127.0.0.1:5000/align';
  //static const String transcribeUrl = 'http://127.0.0.1:5001/transcribe';
  //static const String transcribeUrl ='https://infanciadigital.duckdns.org/transcriber/transcribe';

  // Ruta base para el servidor de preprocesamiento de audio (WebSocket)
  static const String audioProcessorUrl = 'ws://localhost:8000/ws';
  // Ruta base para el servidor de transcripción (WebSocket)
  static const String transcriptionUrl = 'ws://localhost:8001/ws';
  // Ruta base para el servidor de MFA
  static const String mfaUrl = 'http://localhost:5023/align';
}