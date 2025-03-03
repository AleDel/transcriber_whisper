import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:socket_io_client/socket_io_client.dart' as socketIO;
import 'package:transcriber_whisper/app_exceptions.dart';
import 'package:transcriber_whisper/constants.dart';
import 'package:transcriber_whisper/data_repository.dart';
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:uuid/uuid.dart';

import 'mockData/textotest.dart';

class TranscribeCubit extends Cubit<TranscribeState> {
  TranscribeCubit(this.dataRepository) : super(const TranscribeState(status: TranscribeStatus.initial)) {
    //initSocket();
    initAudioPlayer();
    loadData();
  }

  final DataRepository dataRepository;
  final ScrollController scrollController = ScrollController();
  final AudioPlayer audioPlayer = AudioPlayer();
  late socketIO.Socket socket;
  Transcription? transcription;
  bool _autoScrollEnabled = true;
  bool _userSelectedWord = false;
  bool _isPlayingWord = false;
  Timer? _wordPlayTimer;
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;

  static Map<String, Color> availableTags = {
    "Omisión": Colors.red,
    "Relectura": Colors.green,
    "Repetición": Colors.blue,
    "Corrección": Colors.purple,
    'Tag5': Colors.orange,
    'Tag6': Colors.pink,
  };

  void initSocket() {
    socket = socketIO.io(AppConstants.socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket.onConnect((_) {
      print('connect');
      emit(state.copyWith(status: TranscribeStatus.loaded));
    });
    socket.onDisconnect((_) => print('disconnect'));
    socket.on('connect_error', (data) {
      print('connect_error: $data');
      emit(state.copyWith(status: TranscribeStatus.noserver));
    });
    socket.on('connect_timeout', (data) {
      print('connect_timeout: $data');
      emit(state.copyWith(status: TranscribeStatus.noserver));
    });
  }

  void initAudioPlayer() {
    audioPlayer.onDurationChanged.listen((Duration d) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioDuration: d)));
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioPosition: p)));
      updateCurrentWord();
    });
    audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (s == PlayerState.playing) {
        emit(state.copyWith(playerStatus: PlayerStatus.playing));
      } else if (s == PlayerState.paused) {
        emit(state.copyWith(playerStatus: PlayerStatus.paused));
      } else if (s == PlayerState.stopped) {
        emit(state.copyWith(playerStatus: PlayerStatus.stopped));
      } else if (s == PlayerState.completed) {
        emit(state.copyWith(playerStatus: PlayerStatus.completed));
      }
    });
    audioPlayer.onPlayerComplete.listen((event) {
      emit(state.copyWith(playerStatus: PlayerStatus.completed));
    });
  }

  Future<void> alignAudio(PlatformFile audioFile, String text) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final url = Uri.parse(AppConstants.alignUrl);
      var request = http.MultipartRequest('POST', url);

      // Añadir el texto como un campo de formulario
      request.fields['text'] = text;

      // Añadir el archivo de audio como un campo de formulario
      Uint8List? fileBytes;
      if (audioFile.bytes != null) {
        fileBytes = audioFile.bytes;
      } else if (audioFile.path != null) {
        fileBytes = await io.File(audioFile.path!).readAsBytes();
      } else {
        throw FileException("No se pudo leer el archivo");
      }

      // Verificar si fileBytes es nulo
      if (fileBytes == null) {
        throw FileException("No se pudo leer el archivo");
      }

      var multipartFile = http.MultipartFile.fromBytes(
        'audio', // Nombre del campo en el servidor
        fileBytes.toList(),
        filename: audioFile.name,
        contentType: MediaType('application', 'octet-stream'), // Tipo de contenido
      );
      request.files.add(multipartFile);

      // Enviar la solicitud
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print(jsonResponse);
        // ... procesar la respuesta
        emit(state.copyWith(status: TranscribeStatus.loaded));
      } else {
        print("Error en la respuesta: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
        throw ServerException('Failed to align audio', details: 'Status code: ${response.statusCode}');
      }
    } on FileException catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message));
    } on ServerException catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message));
    } catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error desconocido"));
    }
  }

/*
  Future<void> transcribeAudio(PlatformFile audioFile, String projectId) async {
    print("transcribeAudio");
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final url = Uri.parse(AppConstants.transcribeUrl);
      final headers = {'Content-Type': 'application/octet/stream'};
      Uint8List? fileBytes;
      String audioFilePath = "";
      if (audioFile.path != null) {
        audioFilePath = audioFile.path!;
      }
      if (audioFile.bytes != null) {
        fileBytes = audioFile.bytes;
      } else if (audioFile.path != null) {
        fileBytes = await File(audioFile.path!).readAsBytes();
      } else {
        throw FileException("No se pudo leer el archivo");
      }

      final response = await http.post(url, headers: headers, body: fileBytes);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        transcription = Transcription.fromListMap(List<Map<String, dynamic>>.from(jsonResponse['transcription']));

        emit(
          state.copyWith(
            status: TranscribeStatus.loaded,
            transcription: transcription,
          ),
        );

        var uuid = const Uuid();
        String sessionId = uuid.v4();
        await audioPlayer.setSource(DeviceFileSource(audioFilePath));
        await dataRepository.saveAudio(fileBytes?.toList(), audioFile.name, projectId, sessionId);
        await dataRepository.saveTranscription(projectId, sessionId, transcription!);
        await dataRepository.saveOriginalText(projectId, sessionId, "");
        final session = Session(id: sessionId, wavFilename: audioFile.name, audioFilename: audioFile.name, status: SessionStatus.completed);
        await dataRepository.saveSession(projectId, session);
        final currentProject = state.currentProject?.copyWith(sessions: [...state.currentProject!.sessions, session]);
        emit(state.copyWith(currentProject: currentProject));
        // Update session status to completed
        if (currentProject != null) {
          final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == sessionId);
          if (sessionIndex != -1) {
            final updatedSession = currentProject.sessions[sessionIndex].copyWith(
              transcription: transcription,
              status: SessionStatus.completed,
            );
            final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
            final updatedProject = currentProject.copyWith(sessions: updatedSessions);
            emit(state.copyWith(currentProject: updatedProject));
            await dataRepository.saveProject(updatedProject);
          }
        }
      } else {
        print('Error: ${response.statusCode}');
        throw ServerException('Failed to transcribe audio', details: 'Status code: ${response.statusCode}');
      }
    } on FileException catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message));
    } on ServerException catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message));
    } catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error desconocido"));
    } finally {
      emit(state.copyWith(status: TranscribeStatus.loaded));
    }
  }
*/
  /*
  Future<void> processAndTranscribeFiles(String projectId, List<PlatformFile> files) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      await _sendFilesToAudioProcessor(files, projectId);
      emit(state.copyWith(status: TranscribeStatus.loaded));
    } on ServerException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message, errorDetails: e.details));
    } on ServerNotAvailableException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.noserver, errorMessage: e.message, errorDetails: e.details));
    } on UnknownException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message, errorDetails: e.details));
    }
  }

  */

  Future<void> _sendFilesToAudioProcessor(Session session) async {
    print("_sendFilesToAudioProcessor");
    print("Session file name: ${session.platformFile?.name}");
    print("Session file bytes: ${session.platformFile?.bytes}");
    print("Session file path: ${session.platformFile?.path}");
    try {
      final url = Uri.parse(AppConstants.audioProcessorUrl);
      final currentProject = state.currentProject;

      // Check if the session has a PlatformFile
      if (session.platformFile == null) {
        // Handle the case where there's no file associated with the session
        if (currentProject != null) {
          final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == session.id);
          if (sessionIndex != -1) {
            final updatedSession = currentProject.sessions[sessionIndex].copyWith(
              status: SessionStatus.error,
            );
            final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
            final updatedProject = currentProject.copyWith(sessions: updatedSessions);
            emit(state.copyWith(currentProject: updatedProject));
            await dataRepository.saveProject(updatedProject);
          }
        }
        throw Exception('No file associated with this session.');
      }

      // Update session status to processingAudio
      if (currentProject != null) {
        final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == session.id);
        if (sessionIndex != -1) {
          final updatedSession = currentProject.sessions[sessionIndex].copyWith(
            status: SessionStatus.processingAudio,
          );
          final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
          final updatedProject = currentProject.copyWith(sessions: updatedSessions);
          emit(state.copyWith(currentProject: updatedProject));
          await dataRepository.saveProject(updatedProject);
        }
      }

      print("ok1");
      // Add the file to the request
      if (session.platformFile!.path != null) {
        print("Adding file with path");
        // Fetch the blob
        final blobResponse = await http.get(Uri.parse(session.platformFile!.path!));
        if (blobResponse.statusCode == 200) {
          // Convert to Uint8List
          final bytes = blobResponse.bodyBytes;
          final request = http.MultipartRequest('POST', url)
            ..files.add(http.MultipartFile.fromBytes(
              'audio_files',
              bytes,
              filename: session.platformFile!.name,
            ));
          print("Request files: ${request.files.length}");
          print("ok4");
          final response = await request.send();
          final responseBody = await response.stream.bytesToString();

          if (response.statusCode == 200) {
            final responseData = jsonDecode(responseBody);
            final processedFiles = responseData['processed_files'] as List<dynamic>;
            for (final file in processedFiles) {
              final filename = path.basename(file);
              final fileUrl = Uri.parse('${AppConstants.audioProcessorUrl.replaceAll("/process_audio", "")}/get_processed_file/$filename');
              final fileResponse = await http.get(fileUrl);
              print('fileResponse.statusCode: ${fileResponse.statusCode}');
              if (fileResponse.statusCode == 200) {
                final fileBytes = fileResponse.bodyBytes;
                print('Tamaño de fileBytes: ${fileBytes.length} bytes');
                // Save the file
                if (kIsWeb) {
                  // Flutter Web: Download as a Blob
                  final blob = html.Blob([fileBytes]);
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final anchor = html.document.createElement('a') as html.AnchorElement
                    ..href = url
                    ..style.display = 'none'
                    ..download = filename;
                  html.document.body!.children.add(anchor);
                  anchor.click();
                  html.document.body!.children.remove(anchor);
                  html.Url.revokeObjectUrl(url);
                  print('Archivo guardado en: ${filename}');
                } else {
                  // Mobile/Desktop: Save to file system
                  final directory = await getApplicationDocumentsDirectory();
                  final file = io.File('${directory.path}/$filename');
                  await file.writeAsBytes(fileBytes);
                  print('Archivo guardado en: ${file.path}');
                }
                print('Archivo descargado: $filename');
              } else {
                print('Error al descargar el archivo: $filename');
              }
            }
            // Update session status to completed
            if (currentProject != null) {
              final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == session.id);
              if (sessionIndex != -1) {
                final updatedSession = currentProject.sessions[sessionIndex].copyWith(
                  status: SessionStatus.completed,
                );
                final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
                final updatedProject = currentProject.copyWith(sessions: updatedSessions);
                emit(state.copyWith(currentProject: updatedProject));
                await dataRepository.saveProject(updatedProject);
              }
            }
          } else {
            // Update session status to error
            if (currentProject != null) {
              final sessionIndex = currentProject.sessions.indexWhere((s) => s.id== session.id);
              if (sessionIndex != -1) {
                final updatedSession = currentProject.sessions[sessionIndex].copyWith(
                  status: SessionStatus.error,
                );
                final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
                final updatedProject = currentProject.copyWith(sessions: updatedSessions);
                emit(state.copyWith(currentProject: updatedProject));
                await dataRepository.saveProject(updatedProject);
              }
            }
            throw ServerException('Error al procesar el audio', details: 'Status code: ${response.statusCode} - $responseBody');
          }
        } else {
          // Handle the case where the blob fetch fails
          if (currentProject != null) {
            final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == session.id);
            if (sessionIndex != -1) {
              final updatedSession = currentProject.sessions[sessionIndex].copyWith(
                status: SessionStatus.error,
              );
              final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
              final updatedProject = currentProject.copyWith(sessions: updatedSessions);
              emit(state.copyWith(currentProject: updatedProject));
              await dataRepository.saveProject(updatedProject);
            }
          }
          throw Exception('Failed to fetch blob: ${blobResponse.statusCode}');
        }
      } else {
        // Handle the case where there's no path
        if (currentProject != null) {
          final sessionIndex = currentProject.sessions.indexWhere((s) => s.id == session.id);
          if (sessionIndex != -1) {
            final updatedSession = currentProject.sessions[sessionIndex].copyWith(
              status: SessionStatus.error,
            );
            final updatedSessions = List<Session>.from(currentProject.sessions)..[sessionIndex] = updatedSession;
            final updatedProject = currentProject.copyWith(sessions: updatedSessions);
            emit(state.copyWith(currentProject: updatedProject));
            await dataRepository.saveProject(updatedProject);
          }
        }
        throw Exception('No path found for the file.');
      }
    } on io.SocketException catch (e) {
      print('No se pudo conectar con el servidor');
      throw ServerNotAvailableException('No se pudo conectar con el servidor', details: e.toString());
    } on TimeoutException catch (e) {
      print('Tiempo de espera agotado al conectar con el servidor');
      throw ServerNotAvailableException('Tiempo de espera agotado al conectar con el servidor', details: e.toString());
    } on http.ClientException catch (e) {
      print('Error de cliente al conectar con el servidor: ${e.toString()}');
      emit(state.copyWith(status: TranscribeStatus.noserver, errorMessage: 'Error de cliente al conectar con el servidor'));
      throw ServerNotAvailableException('Error de cliente al conectar con el servidor', details: e.toString());
    } catch (e) {
      print('Error desconocido al conectar con el servidor: ${e.toString()}');
      throw UnknownException('Error desconocido al conectar con el servidor', details: e.toString());
    }
  }

  Future<void> processSession(Session session) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      await _sendFilesToAudioProcessor(session);
      emit(state.copyWith(status: TranscribeStatus.loaded));
    } on ServerException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message, errorDetails: e.details));
    } on ServerNotAvailableException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.noserver, errorMessage: e.message, errorDetails: e.details));
    } on UnknownException catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: e.message, errorDetails: e.details));
    }
  }

  Future<void> pickAudioFile(String projectId) async {
    print("hola");
    //FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    //FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowMultiple: true, allowedExtensions: ["aac"]);
/*
    if (result != null) {
      //File file = File(result.files.single.path!);
      PlatformFile file = result.files.single;
      ///////////transcribeAudio(file);
      transcribeAudio(file, projectId);
      //alignAudio(file, "Nadie te puede salvar");
    } else {
      // User canceled the picker, do nothing
      print("User canceled the picker");
    }*/
  }

  Future<void> useMockTranscription() async {
    transcription = Transcription.fromListMap(textoMock);
    //await audioPlayer.setSource(DeviceFileSource(audioFilePath));
    await audioPlayer.setSource(AssetSource('9183-2-2660_16000hz.wav'));
    emit(state.copyWith(status: TranscribeStatus.loaded, transcription: transcription)); /**/
    //await dataRepository.saveTranscription(transcription!);
  }

  void toggleEditMode() {
    emit(state.copyWith(editMode: !state.editMode));
  }

  void addTagToSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final segment = state.transcription!.segments[index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void removeTagFromSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final segment = state.transcription!.segments[index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegment(Segment newSegment) {
    if (state.transcription == null) return;
    final index = state.transcription!.segments.indexOf(newSegment);
    if (index == -1) return;
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegments(List<int> indexes, String newText) {
    if (state.transcription == null || indexes.isEmpty) return;
    final newSegments = List<Segment>.from(state.transcription!.segments);
    for (int index in indexes) {
      if (index >= 0 && index < newSegments.length) {
        final segment = newSegments[index];
        final newSegment = segment.copyWith(word: newText);
        newSegments[index] = newSegment;
      }
    }
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void deleteSegment(int index) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final newSegments = List<Segment>.from(state.transcription!.segments)..removeAt(index);
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  void updateCurrentWord() {
    if (state.transcription == null || state.transcription!.segments.isEmpty) return;
    if (_userSelectedWord) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    final index = _binarySearch(state.transcription!.segments, currentMillis);
    if (index != -1) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));
    }
  }

  void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.segments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = state.transcription!.segments[index];
    final startMillis = (segment.start * 1000).toInt();
    final endMillis = (segment.end * 1000).toInt();
    audioPlayer.seek(Duration(milliseconds: startMillis));
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));

    if (_wordPlayTimer != null && _wordPlayTimer!.isActive) {
      _wordPlayTimer!.cancel();
    }

    if (state.extradata!.playAndStopWordOnSelect) {
      if (_isPlayingWord) {
        audioPlayer.pause();
      }
      _isPlayingWord = true;
      audioPlayer.resume();
      _wordPlayTimer = Timer(Duration(milliseconds: endMillis - startMillis), () {
        audioPlayer.pause();
        _isPlayingWord = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _userSelectedWord = false;
    });
  }

  void togglePlayAndStopWordOnSelect() {
    emit(state.copyWith(extradata: state.extradata?.copyWith(playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect)));
  }

  /// Realiza una búsqueda binaria en la lista de segmentos para encontrar el segmento que contiene el tiempo objetivo.
  ///
  /// Args:
  ///   segments (List<Segment>): La lista de segmentos en la que se realizará la búsqueda.
  ///   target (int): El tiempo objetivo en milisegundos.
  ///
  /// Returns:
  ///   int: El índice del segmento que contiene el tiempo objetivo, o -1 si no se encuentra ningún segmento.
  int _binarySearch(List<Segment> segments, int target) {
    int left = 0;
    int right = segments.length - 1;
    while (left <= right) {
      int mid = left + ((right - left) ~/ 2);
      final segment = segments[mid];
      final startMillis = (segment.start * 1000).toInt();
      final endMillis = (segment.end * 1000).toInt();
      if (target >= startMillis && target <= endMillis) {
        return mid;
      } else if (target < startMillis) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return -1;
  }

  void updateTranscription(Transcription newTranscription) {
    emit(state.copyWith(transcription: newTranscription));
  }

  Future<void> loadData() async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final projects = await dataRepository.loadProjects();
      print(projects);
      emit(state.copyWith(status: TranscribeStatus.loaded, projects: projects));
    } catch (e) {
      print("Error al cargar los proyectos: $e");
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error al cargar los datos"));
    }
  }

  Future<void> loadProject(String projectId) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final project = await dataRepository.loadProject(projectId);
      if (project != null) {
        if (project.sessions.isNotEmpty) {
          //_originalText = project.sessions.first.originalText ?? "";
        }
        emit(state.copyWith(status: TranscribeStatus.loaded, currentProject: project));
      }
    } catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error al cargar el proyecto"));
    }
  }

  Future<void> selectProject(Project project) async {
    emit(state.copyWith(currentProject: project));
  }

  Future<void> deleteData() async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final projects = await dataRepository.loadProjects();
      for (var project in projects) {
        await dataRepository.deleteProject(project.id);
      }
      emit(state.copyWith(status: TranscribeStatus.loaded, transcription: Transcription(segments: [])));
    } catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error al eliminar los datos"));
    }
  }

  Future<void> saveOriginalText(String projectId, String sessionId, String text) async {
    try {
      await dataRepository.saveOriginalText(projectId, sessionId, text);
    } catch (e) {
      print('Error al guardar el texto original: $e');
    }
  }

  Future<void> deleteProject(String projectId) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      await dataRepository.deleteProject(projectId);
      await loadData();
      emit(state.copyWith(status: TranscribeStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error al eliminar el proyecto"));
    }
  }

  Future<void> createProject(String projectName) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      var uuid = const Uuid();
      String projectId = uuid.v4();
      final project = Project(id: projectId, name: projectName);
      await dataRepository.saveProject(project);
      await loadData();
      emit(state.copyWith(status: TranscribeStatus.loaded));
    } catch (e) {
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error al crear el proyecto"));
    }
  }

  Future<void> addFilesToProject(String projectId, List<PlatformFile> files) async {
    try {
      final currentProject = state.currentProject;
      if (currentProject != null) {
        List<Session> newSessions = [];
        for (var file in files) {
          // Check if a session with the same audioFilename already exists
          final sessionExists = currentProject.sessions.any((session) => session.audioFilename == file.name);
          if (!sessionExists) {
            print("File name: ${file.name}");
            print("File bytes: ${file.bytes}");
            print("File path: ${file.path}");
            final newSession = Session(id: const Uuid().v4(), audioFilename: file.name, platformFile: file);
            await dataRepository.saveSession(projectId, newSession);
            newSessions.add(newSession);
          }
        }
        if (newSessions.isNotEmpty) {
          final updatedSessions = List<Session>.from(currentProject.sessions)..addAll(newSessions);
          final updatedProject = currentProject.copyWith(sessions: List.from(updatedSessions));
          emit(state.copyWith(currentProject: updatedProject));
        }
      }
    } catch (e) {
      print('Error al añadir archivos al proyecto: $e');
    }
  }

  Future<void> deleteAllSessions(String projectId) async {
    try {
      await dataRepository.deleteSessions(projectId);
      final currentProject = await dataRepository.loadProject(projectId);
      emit(state.copyWith(currentProject: currentProject));
    } catch (e) {
      print('Error al borrar todas las sesiones: $e');
    }
  }

  void addFiles(List<PlatformFile> files) {
    emit(state.copyWith(files: files));
  }

  void clearFiles() {
    emit(state.copyWith(files: []));
  }

  Future<void> removeFile(PlatformFile file) async {
    final files = state.files.where((f) => f.name != file.name).toList();
    emit(state.copyWith(files: files));
  }
}
