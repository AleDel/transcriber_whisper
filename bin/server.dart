import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:path/path.dart' as p;
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/models/transcription_service.dart';

final getIt = GetIt.instance;

void main() async {
  // Registrar el Cubit en GetIt
  getIt.registerSingleton<TranscriptionService>(TranscriptionService());

  // Configurar el router
  final app = Router();

  // Ruta para servir archivos estáticos (tu aplicación web)
  final staticHandler = shelf_static.createStaticHandler('build/web'); // Removed defaultDocument

  // Map to determine MIME types based on file extensions
  final mimeTypeMap = {
    '.js': 'application/javascript',
    '.html': 'text/html',
    '.css': 'text/css',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.json': 'application/json',
    '.ico': 'image/x-icon',
    // Add more MIME types as needed
  };

  // Handler to serve static files first
  staticFileHandler(Request request) async {
    final response = await staticHandler(request);
    if (response == null) {
      return null;
    } else {
      // Determine the MIME type based on the file extension
      final extension = p.extension(request.url.path);
      final mimeType = mimeTypeMap[extension] ?? 'application/octet-stream'; // Default to binary

      // Add the Content-Type header
      final headers = Map<String, String>.from(response.headers);
      headers['Content-Type'] = mimeType;

      return response.change(headers: headers);
    }
  }

  // Catch-all route to serve index.html for Flutter routes
  app.all('/<ignored|.*>', (Request request) async {
    print("eeeeeee: ${request.url}");
    // Check if it's the root route
    if (request.url.path == '') {
      final indexFile = File(p.join('build', 'web', 'index.html'));
      if (await indexFile.exists()) {
        return Response.ok(
          indexFile.openRead(),
          headers: {'Content-Type': 'text/html'},
        );
      } else {
        return Response.notFound('index.html not found');
      }
    } else {
      // Handle other static files
      final response = await staticFileHandler(request);
      if (response == null) {
        // If staticHandler returns null, it means it didn't find a file.
        // Serve index.html manually.
        final indexFile = File(p.join('build', 'web', 'index.html'));
        if (await indexFile.exists()) {
          return Response.ok(
            indexFile.openRead(),
            headers: {'Content-Type': 'text/html'},
          );
        } else {
          return Response.notFound('index.html not found');
        }
      } else {
        return response;
      }
    }
  });

  app.get('/api/checkaudio', (Request request) {
    final nombreAudio = request.url.queryParameters['nombreaudio'];
    if (nombreAudio != null) {
      final service = getIt<TranscriptionService>();
      final audioExists = service.checkAudio(nombreAudio);
      if (audioExists) {
        return Response.ok(
          jsonEncode({
            'status': 'success',
            'message': 'Audio $nombreAudio exists.',
            'action': 'navigateToDiffTextPage', // Tell Flutter to navigate
            'nombreAudio': nombreAudio, // Send the audio name
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.ok(
          jsonEncode({
            'status': 'error',
            'message': 'Audio $nombreAudio does not exist.',
            'action': 'showError', // Tell Flutter to show an error
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } else {
      return Response.badRequest(
        body: jsonEncode({'status': 'error', 'message': 'Missing nombreaudio parameter.'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // Crear el pipeline
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(app);

  // Iniciar el servidor
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, '0.0.0.0', port);

  print('Servidor corriendo en http://${server.address.host}:${server.port}');
}
