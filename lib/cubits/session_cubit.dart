import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:transcriber_whisper/cubits/transcription_cubit.dart';
import 'package:transcriber_whisper/data_repository.dart';
import 'package:transcriber_whisper/models/session_data.dart';

import '../models/alignment_mfa_data.dart';
import '../models/transcription_model.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';

part 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  final TranscriptionCubit _transcriptionCubit;
  final DataRepository _dataRepository;
  final ProjectCubit _projectCubit;
  SessionData? sessionData;
  final AudioPlayer audioPlayer = AudioPlayer();
  late StreamSubscription _transcriptionSubscription;
  AlignmentMFAData? alignmentData;

  bool _userSelectedWord = false;
  bool _isPlayingWord = false;
  Timer? _wordPlayTimer;
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;

  static Map<String, Color> availableTags = {
    'Omisioa': Colors.red[200]!,
    'Ordezkapena': Colors.green[200]!,
    'Asmaketa': Colors.blue[200]!,
    'Berrirakurtzea': Colors.purple[200]!,
    'Zuzenketa': Colors.orange[200]!,
    'Gehikuntza': Colors.pink[200]!,
    'Inbertsioa': Colors.yellow[200]!,
    'Jauzia': Colors.teal[200]!,
    'Errepikapena': Colors.indigo[200]!,
  };
  static Map<String, String> tagToSymbol = {
    'Omisioa': '-',
    'Ordezkapena': 'O',
    'Asmaketa': 'A',
    'Berrirakurtzea': 'B',
    'Zuzenketa': 'Z',
    'Gehikuntza': '+',
    'Inbertsioa': 'I',
    'Jauzia': 'J',
    'Errepikapena': 'E',
  };

  final Uuid _uuid = const Uuid();

  SessionCubit(this._transcriptionCubit, this._dataRepository, this._projectCubit) : super(const SessionState()) {
    _transcriptionSubscription = _transcriptionCubit.stream.listen((transcriptionState) {
      if (sessionData == null) {
        print("No hay session seleccionada");
        return;
      }
      final newSessionData = transcriptionState.currentProject?.sessionsData.firstWhere(
            (s) => s.id == sessionData?.id,
        orElse: () => sessionData!,
      );
      if (newSessionData != null) {
        sessionData = newSessionData;
        emit(state.copyWith(sessionData: sessionData));
      }
    });
    initAudioPlayer();
  }

  void updateCurrentWord() {
    if (sessionData?.transcription == null || sessionData!.transcription!.segments.isEmpty) return;
    if (_userSelectedWord) return;
    final currentPosition = sessionData!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    final index = _binarySearch(sessionData!.transcription!.segments, currentMillis);
    if (index != -1) {
      sessionData = sessionData?.copyWith(currentWordIndex: index);
      emit(state.copyWith(sessionData: sessionData));
    }
  }

  void initAudioPlayer() async {
    _loadAudio();
    print("-- initAudioPlayer --");
    audioPlayer.onDurationChanged.listen((Duration d) {
      print("-------------------Cambio duracion a: $d");
      sessionData = sessionData?.copyWith(audioDuration: d);
      emit(state.copyWith(sessionData: sessionData));
      updateCurrentWord();
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      sessionData = sessionData?.copyWith(audioPosition: p);
      emit(state.copyWith(sessionData: sessionData));
      updateCurrentWord();
    });
    audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      PlayerStatus playerStatus;
      if (s == PlayerState.playing) {
        playerStatus = PlayerStatus.playing;
      } else if (s == PlayerState.paused) {
        playerStatus = PlayerStatus.paused;
      } else if (s == PlayerState.stopped) {
        playerStatus = PlayerStatus.stopped;
      } else if (s == PlayerState.completed) {
        playerStatus = PlayerStatus.completed;
      } else {
        playerStatus = PlayerStatus.idle;
      }
      sessionData = sessionData?.copyWith(playerStatus: playerStatus);
      emit(state.copyWith(sessionData: sessionData));
    });
    audioPlayer.onPlayerComplete.listen((event) {
      sessionData = sessionData?.copyWith(playerStatus: PlayerStatus.completed);
      emit(state.copyWith(sessionData: sessionData));
    });
  }

  Future<void> _loadAudio() async {
    print("load Audio");
    await audioPlayer.setSourceAsset("/audio/audio_prueba.wav");
  }

  Future<void> loadProcessedAudio() async {
    if (sessionData?.processedAudioBytes != null) {
      try {
        await audioPlayer.setSourceBytes(sessionData!.processedAudioBytes!);
      } catch (e) {
        print('Error loading audio: $e');
      }
    }
  }

  Future<void> createSession(String projectId, String name) async {
    print("createSession: $projectId");
    try {
      final session = await _dataRepository.createSession(projectId, name);
      //final dummyTranscription = await _createDummyTranscription().timeout(const Duration(seconds: 10));
      final dummyTranscription = await _createDummyTranscriptionEuskera();
      final dummyTranscriptionMfa = await _loadAlignmentMFAData();
      await _dataRepository.saveTranscription(projectId, session.id, dummyTranscription);
      final updatedSession = session.copyWith(transcription: dummyTranscription, audioUrl: 'assets/audio_prueba.m4a', alignmentMFAData: dummyTranscriptionMfa);
      sessionData = updatedSession;
      emit(state.copyWith(sessionData: updatedSession));
      updateTranscription(dummyTranscription);
    } on TimeoutException catch (e) {
      print('Timeout creating dummy transcription: $e');
    } catch (e) {
      print('Error al cargar la sesión: $e');
    }
  }

  Future<void> getSessionById(String sessionId) async {
    print("getSessionById: $sessionId");
    try {
      final session = await _dataRepository.getSessionById(sessionId);
      sessionData = session;
      emit(state.copyWith(sessionData: session));
    } catch (e) {
      print('Error al cargar la sesión: $e');
    }
  }

  Future<AlignmentMFAData?> _loadAlignmentMFAData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/audio_1741581509.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      alignmentData = AlignmentMFAData.fromMap(jsonMap);
      print("Alignment data loaded successfully");
      print("alignmentData lista de words ---> ${alignmentData?.tiers["words"]!.entries.length}");
      print("alignmentData lista de fonemas ---> ${alignmentData?.tiers["phones"]!.entries.length}");
      return alignmentData;
    } catch (e) {
      print('Error loading alignment data: $e');
    }
    return null;
  }

  Future<Transcription> _createDummyTranscriptionEuskera() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/transcriptionWhisper.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      final List<Segment> segments = jsonList.map((item) {
        return Segment(
          start: (item['start'] as num).toDouble(),
          end: (item['end'] as num).toDouble(),
          word: item['word'] as String,
          probability: (item['probability'] as num).toDouble(),
          tags: [], // Puedes añadir tags si los tienes en el JSON
        );
      }).toList();
      return Transcription(segments: segments);
    } catch (e) {
      print('Error loading transcription from asset: $e');
      // Puedes devolver una transcripción vacía o lanzar una excepción
      return Transcription(segments: []);
    }
  }



  Future<Transcription> _createDummyTranscription() async {
    final String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');
    final List<String> lines = text.split('\n');
    final List<Segment> segments = [];
    const Duration totalAudioDuration = Duration(seconds: 60); // Example: 60 seconds
    final int totalSegments = lines.where((line) => line.trim().isNotEmpty).length;
    final Duration segmentDuration = Duration(milliseconds: totalSegments > 0 ? totalAudioDuration.inMilliseconds ~/ totalSegments : 0);
    Duration currentTime = const Duration(seconds: 0);

    for (String line in lines) {
      line = line.trim();
      if (line.isNotEmpty) {
        final Segment segment = Segment(
          start: currentTime.inSeconds.toDouble(),
          end: (currentTime + segmentDuration).inSeconds.toDouble(),
          word: line,
          probability: 0.9,
          tags: [],
        );
        segments.add(segment);
        currentTime += segmentDuration;
      }
    }
    return Transcription(segments: segments);
  }

  void setSession(SessionData session) {
    sessionData = session;
    emit(state.copyWith(sessionData: session));
  }

  Future<void> updateTranscription(Transcription transcription) async {
    print("updateTranscription: segments lenght ${transcription.segments.length}");
    try {
      if (sessionData == null) {
        print("Error: No hay sesión cargada.");
        return;
      }
      await _dataRepository.saveTranscription(sessionData!.projectId, sessionData!.id, transcription);
      final updatedSession = sessionData?.copyWith(transcription: transcription);
      sessionData = updatedSession;
      emit(state.copyWith(sessionData: updatedSession));
    } catch (e) {
      print('Error al actualizar la transcripción: $e');
    }
  }

  void forceCurrentWord(int index) {
    if (sessionData == null || sessionData!.transcription == null || sessionData!.transcription!.segments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = sessionData!.transcription!.segments[index];
    final startMillis = (segment.start * 1000).toInt();
    final endMillis = (segment.end * 1000).toInt();
    audioPlayer.seek(Duration(milliseconds: startMillis));
    sessionData = sessionData?.copyWith(currentWordIndex: index);
    emit(state.copyWith(sessionData: sessionData));

    if (_wordPlayTimer != null && _wordPlayTimer!.isActive) {
      _wordPlayTimer!.cancel();
    }

    if (sessionData!.playAndStopWordOnSelect) {
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

  void deleteSegment(int index) {
    if (sessionData == null || sessionData!.transcription == null) return;
    if (index < 0 || index >= sessionData!.transcription!.segments.length) return;
    final newSegments = [...sessionData!.transcription!.segments];
    newSegments.removeAt(index);
    final newTranscription = sessionData!.transcription!.copyWith(segments: newSegments);
    updateTranscription(newTranscription);
  }

  void editSegment(SessionData sessionData, Segment newSegment) {
    if (sessionData.transcription == null) return;
    final index = sessionData.transcription!.segments.indexWhere((element) => element.word == newSegment.word);
    if (index == -1) return;
    final newSegments = [...sessionData.transcription!.segments];
    newSegments[index] = newSegment;
    final newTranscription = sessionData.transcription!.copyWith(segments: newSegments);
    updateTranscription(newTranscription);
  }

  void editSegments(List<int> selectedIndexes, String newText) {
    if (sessionData == null || sessionData!.transcription == null) return;
    final newSegments = [...sessionData!.transcription!.segments];
    for (int index in selectedIndexes) {
      if (index < 0 || index >= newSegments.length) continue;
      newSegments[index] = newSegments[index].copyWith(word: newText);
    }
    final newTranscription = sessionData!.transcription!.copyWith(segments: newSegments);
    updateTranscription(newTranscription);
  }

  void addTagToSegment(SessionData sessionData, int index, String tag) {
    if (sessionData.transcription == null) return;
    if (index < 0 || index >= sessionData.transcription!.segments.length) return;
    final newSegments = [...sessionData.transcription!.segments];
    final segment = newSegments[index];
    final newTags = [...segment.tags, tag];
    newSegments[index] = segment.copyWith(tags: newTags);
    final newTranscription = sessionData.transcription!.copyWith(segments: newSegments);
    updateTranscription(newTranscription);
  }

  void removeTagFromSegment(SessionData sessionData, int index, String tag) {
    if (sessionData.transcription == null) return;
    if (index < 0 || index >= sessionData.transcription!.segments.length) return;
    final newSegments = [...sessionData.transcription!.segments];
    final segment = newSegments[index];
    final newTags = [...segment.tags];
    newTags.remove(tag);
    newSegments[index] = segment.copyWith(tags: newTags);
    final newTranscription = sessionData.transcription!.copyWith(segments: newSegments);
    updateTranscription(newTranscription);
  }

  void setAutoScroll(bool value) {
    sessionData = sessionData?.copyWith(autoScrollEnabled: value);
    emit(state.copyWith(sessionData: sessionData));
  }

  /*void togglePlayAndStopWordOnSelect() {
    sessionData = sessionData?.copyWith(playAndStopWordOnSelect: !(sessionData?.playAndStopWordOnSelect ?? false));
    emit(state.copyWith(sessionData: sessionData));
  }*/
  void togglePlayAndStopWordOnSelect() {
    emit(state.copyWith(sessionData: state.sessionData?.copyWith(playAndStopWordOnSelect: !state.sessionData!.playAndStopWordOnSelect)));
  }

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

  @override
  Future<void> close() {
    _transcriptionSubscription.cancel();
    audioPlayer.dispose();
    return super.close();
  }
}