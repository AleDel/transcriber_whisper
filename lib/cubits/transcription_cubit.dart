import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../constants.dart';
import '../data_repository.dart';
import '../mfa_service.dart';
import '../models/project.dart';
import '../models/session_data.dart';
import '../models/transcription_model.dart';

part 'transcription_state.dart';

class TranscriptionCubit extends Cubit<TranscriptionState> {
  final DataRepository _dataRepository;
  final ProjectCubit _projectCubit;
  late StreamSubscription _projectSubscription;

  TranscriptionCubit(this._dataRepository, this._projectCubit, this.mfaService) : super(const TranscriptionState(transcriptionStatus: TranscriptionStatus.pending)) {
    _projectSubscription = _projectCubit.stream.listen((projectState) {
      if (projectState.project != null) {
        emit(state.copyWith(currentProject: projectState.project));
      }
    });
  }

  late WebSocketChannel _audioProcessorChannel;
  late WebSocketChannel _transcriptionChannel;

  final Map<String, String> _lastAudioProcessorMessage = {};
  final Map<String, List<Uint8List>> _processedFiles = {};

  Timer? _pingTimer;
  static const Duration _pingInterval = Duration(seconds: 10);

  final MfaService mfaService;

  void updateSession(SessionData newSession) {
    final currentProject = state.currentProject;
    if (currentProject == null) return;

    final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == newSession.id);
    if (sessionIndex == -1) return;

    final updatedSessions = List<SessionData>.from(currentProject.sessionsData)..[sessionIndex] = newSession;
    final updatedProject = currentProject.copyWith(sessions: updatedSessions);

    emit(state.copyWith(currentProject: updatedProject));
    _dataRepository.saveProject(updatedProject);
  }

  // dentro del contexto del proyecto actual. Actualiza el proyecto completo.
  void updateTranscription(Transcription newTranscription) {
    if (state.currentProject == null) return;
    final newProject = state.currentProject!.copyWith(
      sessions: state.currentProject!.sessionsData.map((session) {
        return session.copyWith(transcription: newTranscription);
      }).toList(),
    );
    emit(state.copyWith(currentProject: newProject));
  }

  // Métodos de Conexión y Desconexión

  void _connectAudioProcessor(String sessionId) {
    _audioProcessorChannel = WebSocketChannel.connect(
      Uri.parse('${AppConstants.audioProcessorUrl}/$sessionId'),
    );
    _audioProcessorChannel.stream.listen(
      _handleAudioProcessorMessage,
      onError: (error) {
        print('Error en la conexión con el servidor de preprocesamiento de audio: $error');
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: 'Error en la conexión con el servidor de preprocesamiento de audio: $error'));
        _disconnectAudioProcessor();
      },
      onDone: () {
        print('Conexión con el servidor de preprocesamiento de audio cerrada');
        _cancelPingAudioProcessor();
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.completedAudioProcess));
        _disconnectAudioProcessor();
      },
    );
  }

  void _disconnectAudioProcessor() {
    _cancelPingAudioProcessor();
    _audioProcessorChannel.sink.close();
    //_audioProcessorChannel = null;
  }

  void _connectTranscription(String sessionId) {
    _transcriptionChannel = WebSocketChannel.connect(
      Uri.parse('${AppConstants.transcriptionUrl}/$sessionId'),
    );
    _transcriptionChannel!.stream.listen(
      _handleTranscriptionMessage,
      onError: (error) {
        print('Error en la conexión con el servidor de transcripción: $error');
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: error.toString()));
        _disconnectTranscription();
      },
      onDone: () {
        print('Conexión con el servidor de transcripción cerrada');
        _cancelPingTranscription();
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.completedTranscription));
        _disconnectTranscription();
      },
    );
  }

  void _disconnectTranscription() {
    _cancelPingTranscription();
    _transcriptionChannel?.sink.close();
    //_transcriptionChannel = null;
  }

  // Manejo de Mensajes

  void _handleAudioProcessorMessage(message) {
    if (message is String) {
      print("------------- - - -  ${message}");
      final data = jsonDecode(message);
      final sessionId = data['session_id'].toString();
      _lastAudioProcessorMessage[sessionId] = message;
      if (data['type'] == 'session_joined_audio_processor') {
        print('Conectado al servidor de preprocesamiento de audio');
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.connectedAudioProcess));
        _startPingAudioProcessor();
      } else if (data['type'] == 'send_file_chunk_audio_processor') {
        print('send_file_chunk_audio_processor: ${data['filename']}');
      } else if (data['type'] == 'send_file_chunk_processed_audio') {
        print("ooooook1");
        print('Archivo procesado por el servidor de preprocesamiento de audio: ${data['filename']}');
        final filename = data['filename'];
        final chunkIndex = data['chunk_index'];
        final totalChunks = data['total_chunks'];
        final currentProject = state.currentProject;
        if (currentProject != null) {
          print("ooooook2");
          final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == sessionId);
          if (sessionIndex != -1) {
            print("ooooook3");
            if (!_processedFiles.containsKey(sessionId)) {
              _processedFiles[sessionId] = [];
            }
            print("chunkIndex: $chunkIndex, totalChunks: $totalChunks");
            final updatedSession = currentProject.sessionsData[sessionIndex];
            final updatedSessions = List<SessionData>.from(currentProject.sessionsData)..[sessionIndex] = updatedSession;
            final updatedProject = currentProject.copyWith(sessions: updatedSessions);
            emit(state.copyWith(currentProject: updatedProject, transcriptionStatus: TranscriptionStatus.processingAudio));
            _dataRepository.saveProject(updatedProject);
          }
        }
      } else if (data['type'] == 'file_processed_error_audio_processor') {
        print('Error al procesar el archivo en el servidor de preprocesamiento de audio: ${data['filename']}');
        _handleAudioProcessorError(data);
      }
    } else if (message is Uint8List) {
      // (manejo de chunks de audio)
      /*String? currentSessionId;
      if (_lastAudioProcessorMessage.isNotEmpty) {
        currentSessionId = _lastAudioProcessorMessage.keys.last;
      }
      final metadata = currentSessionId != null && _lastAudioProcessorMessage.containsKey(currentSessionId) ? jsonDecode(_lastAudioProcessorMessage[currentSessionId]!) : null;
    */
      final metadata = _lastAudioProcessorMessage.values.isNotEmpty ? jsonDecode(_lastAudioProcessorMessage.values.last) as Map<String, dynamic> : null;
      if (metadata != null) {
        //print("metadata: $metadata");
        final filename = metadata['filename'];
        if (filename == null) {
          return;
        }
        //final filename = metadata['filename'];
        final chunkIndex = metadata['chunk_index'];
        final totalChunks = metadata['total_chunks'];
        final sessionId = metadata['session_id'];
        if (!_processedFiles.containsKey(sessionId)) {
          _processedFiles[sessionId] = [];
        }
        _processedFiles[sessionId]!.add(message);
        if (chunkIndex == totalChunks - 1) {
          print("ooooook4");
          final concatenatedBytes = _concatenateChunks(_processedFiles[sessionId]!);
          final originalFilename = filename;
          print("------------------- _processedFiles.keys: ${_processedFiles.keys}");
          print("filename: $originalFilename");
          _saveProcessedAudioToDatabase(sessionId, concatenatedBytes);
          _sendProcessedFileToTranscription(sessionId, concatenatedBytes, originalFilename);
          _processedFiles.remove(sessionId);
          _cancelPingAudioProcessor();
          _disconnectAudioProcessor();
        }
      }
    }
  }

  void _handleAudioProcessorError(Map<String, dynamic> data) {
    final sessionId = data['session_id'];
    final currentProject = state.currentProject;
    if (currentProject != null) {
      final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final updatedSession = currentProject.sessionsData[sessionIndex];
        final updatedSessions = List<SessionData>.from(currentProject.sessionsData)..[sessionIndex] = updatedSession;
        final updatedProject = currentProject.copyWith(sessions: updatedSessions);
        emit(state.copyWith(currentProject: updatedProject, transcriptionStatus: TranscriptionStatus.error));
        _dataRepository.saveProject(updatedProject);
      }
    }
    _cancelPingAudioProcessor();
    _disconnectAudioProcessor();
  }

  void _handleTranscriptionMessage(message) {
    final data = jsonDecode(message);
    final sessionId = data['session_id'];
    if (data['type'] == 'session_joined_transcription') {
      print('Conectado al servidor de transcripción');
      _startPingTranscription();
      final currentProject = state.currentProject;
      if (currentProject != null) {
        final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final updatedSession = currentProject.sessionsData[sessionIndex];
          final updatedSessions = List<SessionData>.from(currentProject.sessionsData)..[sessionIndex] = updatedSession;
          final updatedProject = currentProject.copyWith(sessions: updatedSessions);
          emit(state.copyWith(currentProject: updatedProject, transcriptionStatus: TranscriptionStatus.processingTranscription));
          _dataRepository.saveProject(updatedProject);
        }
      }
    } else if (data['type'] == 'transcription_received') {
      print('Transcripción recibida');
      _handleTranscriptionReceived(data);
    } else if (data['type'] == 'transcription_error') {
      print('Error al transcribir el archivo');
      _handleTranscriptionError(data);
    }
  }

  Future<void> _handleTranscriptionReceived(Map<String, dynamic> data) async {
    final sessionId = data['session_id'];
    final transcription = data['transcription'];
    //final melSpectrogram = data['mel_spectrogram'];
    final waveformImage = data['waveform_image'];
    //final waveformData = data['waveform_data'];
    _disconnectTranscription();
    _cancelPingTranscription();
    final currentProject = state.currentProject;
    print("_handleTranscriptionReceived --> currentProject: ${currentProject?.id}");
    if (currentProject != null) {
      print(currentProject?.id);
      print("sessionId: $sessionId");
      currentProject.sessionsData.forEach(
        (element) {
          print(element.id);
        },
      );
      final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == sessionId);
      print(sessionIndex);
      if (sessionIndex != -1) {
        final updatedSession = currentProject.sessionsData[sessionIndex].copyWith(
          transcription: Transcription.fromListMap(transcription),
          //melSpectrogram: melSpectrogram,
          //waveformImage: waveformImage,
          //waveformData: waveformData,
        );
        final updatedSessions = List<SessionData>.from(currentProject.sessionsData)..[sessionIndex] = updatedSession;
        final updatedProject = currentProject.copyWith(sessions: updatedSessions);
        // Llamar a MFA después de recibir la transcripción
        await _alignTranscription(updatedSession, Transcription.fromListMap(transcription).fulltext);


        _dataRepository.saveProject(updatedProject);
        //dataRepository.saveWaveformData(currentProject.id, updatedSession.id, waveformData);
        //_dataRepository.saveWaveformImage(currentProject.id, updatedSession.id, waveformImage);
        //dataRepository.saveMelSpectrogram(currentProject.id, updatedSession.id, melSpectrogram);
        _dataRepository.saveTranscription(currentProject.id, updatedSession.id, Transcription.fromListMap(transcription));
        emit(state.copyWith(currentProject: updatedProject));


      }
    }
  }

  void _handleTranscriptionError(Map<String, dynamic> data) {
    final sessionId = data['session_id'];
    _disconnectTranscription();
    _cancelPingTranscription();
    final currentProject = state.currentProject;
    if (currentProject != null) {
      final sessionIndex = currentProject.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: "Error en la transcripcion"));
      }
    }
  }

  // Funciones de Procesamiento

  Future<void> sendFilesToAudioProcessor(SessionData session) async {
    print('sendFilesToAudioProcessor called for session: ${session.id}');
    final filename = session.audioFilename;
    _connectAudioProcessor(session.id);
    try {
      final sessionId = session.id;
      Uint8List fileBytes;
      if (session.userAudioBytes != null) {
        fileBytes = session.userAudioBytes!;
        print('File loaded from session, size: ${fileBytes.length}');
      } else {
        throw Exception('User file bytes not found in session');
      }
      _audioProcessorChannel!.sink.add(jsonEncode({'type': 'join_session_audio_processor', 'session_id': sessionId, 'filename': filename}));
      print('join_session_audio_processor event emitted');
      await _sendFileChunks(_audioProcessorChannel!, fileBytes, filename, sessionId, 'send_file_chunk_audio_processor');
      print('File sent');
    } catch (e) {
      print('Error in _sendFilesToAudioProcessor: $e');
      emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _sendProcessedFileToTranscription(String sessionId, Uint8List fileBytes, String filename) async {
    print('_sendProcessedFileToTranscription called for session: $sessionId, filename: $filename');
    _connectTranscription(sessionId);
    try {
      await _sendFileChunks(_transcriptionChannel!, fileBytes, filename, sessionId, 'send_file_chunk_transcription');
      emit(state.copyWith(transcriptionStatus: TranscriptionStatus.processingTranscription));
      print('File sent to transcription server');
    } catch (e) {
      print('Error in _sendProcessedFileToTranscription: $e');
      emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _alignTranscription(SessionData session, String text) async { // Añadido: Método para alinear la transcripción
    print('_alignTranscription called for session: ${session.id}');
    if (session.processedAudioBytes == null) {
      print('Error: processedAudioBytes is null');
      return;
    }
    final alignmentData = await mfaService.align(session.processedAudioBytes!, text);
    if (alignmentData != null) {
      print('Datos de alineamiento recibidos: $alignmentData');
      // Guardar los datos de alineamiento en la sesión
      //final newSession = session.copyWith(alignmentData: alignmentData);
      //updateSession(newSession);
////////////////////////////////////////////////////////////////////////////////llllllll
    } else {
      print('Error al obtener los datos de alineamiento');
    }
  }


  void _saveProcessedAudioToDatabase(String sessionId, Uint8List audioBytes) async {
    final currentProject = state.currentProject;
    if (currentProject != null) {
      print("333333333333333333333 _saveProcessedAudioToDatabase de $sessionId");
      //await dataRepository.saveProcessedAudio(currentProject.id, sessionId, audioBytes);
      final session = currentProject.sessionsData.firstWhere((s) => s.id == sessionId);
      final newSession = session.copyWith(processedAudioBytes: audioBytes);
      updateSession(newSession);
    }
  }

  Future<void> _sendFileChunks(WebSocketChannel channel, Uint8List fileBytes, String filename, String sessionId, String eventName) async {
    print('_sendFileChunks called for session: $sessionId, filename: $filename, eventName: $eventName');

    const chunkSize = 1024 * 1024; // 1MB chunks
    final totalChunks = (fileBytes.length / chunkSize).ceil();
    print('Total chunks: $totalChunks');
    for (var i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (i + 1) * chunkSize > fileBytes.length ? fileBytes.length : (i + 1) * chunkSize;
      final chunk = fileBytes.sublist(start, end);
      print('Sending chunk $i of $totalChunks, size: ${chunk.length}');
      try {
        channel.sink.add(jsonEncode({
          'type': eventName,
          'session_id': sessionId,
          'filename': filename,
          'file_size': fileBytes.length,
          'chunk_index': i,
          'total_chunks': totalChunks,
        }));
        channel.sink.add(chunk);
        print('Chunk $i sent');
      } catch (e) {
        print('Error sending chunk $i: $e');
        emit(state.copyWith(transcriptionStatus: TranscriptionStatus.error, errorMessage: e.toString()));
      }
      await Future.delayed(const Duration(milliseconds: 100)); // Add a small delay
    }
    print('All chunks sent for session: $sessionId, filename: $filename');
  }

  Uint8List _concatenateChunks(List<Uint8List> chunks) {
    final totalLength = chunks.fold(0, (sum, chunk) => sum + chunk.length);
    print("chunks.length: ${chunks.length}");
    print("_concatenateChunks totalLength: $totalLength");
    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }


  void _startPingAudioProcessor() {
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      print('Ping enviado al servidor de preprocesamiento de audio');
      _audioProcessorChannel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _startPingTranscription() {
    _pingTimer = Timer.periodic(_pingInterval, (timer) {
      print('Ping enviado al servidor de transcripción');
      _transcriptionChannel?.sink.add(jsonEncode({'type': 'ping'}));
    });
  }

  void _cancelPingAudioProcessor() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _cancelPingTranscription() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  @override
  Future<void> close() {
    _projectSubscription.cancel();
    _cancelPingAudioProcessor();
    _cancelPingTranscription();
    _disconnectAudioProcessor();
    _disconnectTranscription();
    return super.close();
  }
}
