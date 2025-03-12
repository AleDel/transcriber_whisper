import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

enum PlayerStatus {
  playing,
  paused,
  stopped,
  completed,
  idle,
}

class SessionData extends Equatable {
  final String id;
  final String projectId;
  final String audioFilename;
  final String name;
  final Uint8List? processedAudioBytes;
  final Uint8List? userAudioBytes;
  String? originalText;
  Transcription? transcription;
  final String? melSpectrogram;
  final String? waveformImage;
  final String? waveformData;
  final AlignmentMFAData? alignmentMFAData;
  // ADDED: audioUrl
  String? audioUrl;

  final PlayerStatus playerStatus;
  final Duration audioPosition;
  final Duration audioDuration;
  final int currentWordIndex;
  final bool autoScrollEnabled;
  final bool userSelectedWord;
  final DateTime? lastForceCurrentWordCall;
  final Duration forceCurrentWordDebounceTime;
  final ScrollController scrollController; // Aseguramos que no sea nulo
  final bool playAndStopWordOnSelect;

  SessionData({
    required this.id,
    required this.projectId,
    required this.audioFilename,
    required this.name,
    this.processedAudioBytes,
    this.userAudioBytes,
    this.originalText,
    this.transcription,
    this.melSpectrogram,
    this.waveformImage,
    this.waveformData,
    this.alignmentMFAData,
    // ADDED: audioUrl
    this.audioUrl,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.playerStatus = PlayerStatus.idle,
    this.currentWordIndex = 0,
    this.autoScrollEnabled = false,
    this.userSelectedWord = false,
    this.lastForceCurrentWordCall,
    this.forceCurrentWordDebounceTime = const Duration(milliseconds: 100),
    ScrollController? scrollController, // Ahora es opcional
    this.playAndStopWordOnSelect = false,
  }) : scrollController = scrollController ?? ScrollController(); // Inicializamos si es nulo

  SessionData copyWith({
    String? id,
    String? projectId,
    String? audioFilename,
    String? name,
    Uint8List? processedAudioBytes,
    Uint8List? userAudioBytes,
    String? originalText,
    Transcription? transcription,
    String? melSpectrogram,
    String? waveformImage,
    String? waveformData,
    AlignmentMFAData? alignmentMFAData,
    // ADDED: audioUrl
    String? audioUrl,
    PlayerStatus? playerStatus,
    Duration? audioPosition,
    Duration? audioDuration,
    int? currentWordIndex,
    bool? autoScrollEnabled,
    bool? userSelectedWord,
    DateTime? lastForceCurrentWordCall,
    Duration? forceCurrentWordDebounceTime,
    ScrollController? scrollController,
    bool? playAndStopWordOnSelect,
  }) {
    return SessionData(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      audioFilename: audioFilename ?? this.audioFilename,
      name: name ?? this.name,
      processedAudioBytes: processedAudioBytes ?? this.processedAudioBytes,
      userAudioBytes: userAudioBytes ?? this.userAudioBytes,
      originalText: originalText ?? this.originalText,
      transcription: transcription ?? this.transcription,
      melSpectrogram: melSpectrogram ?? this.melSpectrogram,
      waveformImage: waveformImage ?? this.waveformImage,
      waveformData: waveformData ?? this.waveformData,
      alignmentMFAData: alignmentMFAData ?? this.alignmentMFAData,
      // ADDED: audioUrl
      audioUrl: audioUrl ?? this.audioUrl,
      playerStatus: playerStatus ?? this.playerStatus,
      audioPosition: audioPosition ?? this.audioPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      userSelectedWord: userSelectedWord ?? this.userSelectedWord,
      lastForceCurrentWordCall: lastForceCurrentWordCall ?? this.lastForceCurrentWordCall,
      forceCurrentWordDebounceTime: forceCurrentWordDebounceTime ?? this.forceCurrentWordDebounceTime,
      scrollController: scrollController ?? this.scrollController,
      playAndStopWordOnSelect: playAndStopWordOnSelect ?? this.playAndStopWordOnSelect,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'audioFilename': audioFilename,
      'name': name,
      'userAudioBytes': userAudioBytes,
      'originalText': originalText,
      'transcription': transcription?.toListMap(),
      'melSpectrogram': melSpectrogram,
      'waveformImage': waveformImage,
      'waveformData': waveformData,
      'processedAudioBytes': processedAudioBytes,
      'alignmentMFAData': alignmentMFAData?.toMap(),
      'audioUrl': audioUrl,
      'playerStatus': playerStatus.index,
      'audioPosition': audioPosition.inMilliseconds,
      'audioDuration': audioDuration.inMilliseconds,
      'currentWordIndex': currentWordIndex,
      'autoScrollEnabled': autoScrollEnabled,
      'userSelectedWord': userSelectedWord,
      'lastForceCurrentWordCall': lastForceCurrentWordCall?.toIso8601String(),
      'forceCurrentWordDebounceTime': forceCurrentWordDebounceTime.inMilliseconds,
      'playAndStopWordOnSelect': playAndStopWordOnSelect,
    };
  }

  static SessionData fromMap(Map<String, dynamic> map) {
    return SessionData(
      id: map['id'] as String,
      projectId: map['projectId'] as String,
      audioFilename: map['audioFilename'] as String,
      name: map['name'] as String,
      userAudioBytes: map['userAudioBytes'] != null ? Uint8List.fromList(List<int>.from(map['userAudioBytes'])) : null,
      originalText: map['originalText'] as String?,
      transcription: map['transcription'] != null ? Transcription.fromListMap(List<Map<String, dynamic>>.from(map['transcription'])) : null,
      melSpectrogram: map['melSpectrogram'] as String?,
      waveformImage: map['waveformImage'] as String?,
      waveformData: map['waveformData'] as String?,
      processedAudioBytes: map['processedAudioBytes'] != null ? Uint8List.fromList(List<int>.from(map['processedAudioBytes'])) : null,
      alignmentMFAData: map['alignmentMFAData'] != null ? AlignmentMFAData.fromMap(Map<String, dynamic>.from(map['alignmentMFAData'])) : null,
      audioUrl: map['audioUrl'] as String?,
      playerStatus: PlayerStatus.values[map['playerStatus'] as int],
      audioPosition: Duration(milliseconds: map['audioPosition'] as int),
      audioDuration: Duration(milliseconds: map['audioDuration'] as int),
      currentWordIndex: map['currentWordIndex'] as int,
      autoScrollEnabled: map['autoScrollEnabled'] as bool,
      userSelectedWord: map['userSelectedWord'] as bool,
      lastForceCurrentWordCall: map['lastForceCurrentWordCall'] != null ? DateTime.parse(map['lastForceCurrentWordCall'] as String) : null,
      forceCurrentWordDebounceTime: Duration(milliseconds: map['forceCurrentWordDebounceTime'] as int),
      playAndStopWordOnSelect: map['playAndStopWordOnSelect'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    id,
    projectId,
    audioFilename,
    name,
    userAudioBytes,
    processedAudioBytes,
    originalText,
    transcription,
    melSpectrogram,
    waveformImage,
    waveformData,
    alignmentMFAData,
    audioUrl,
    playerStatus,
    audioPosition,
    audioDuration,
    currentWordIndex,
    autoScrollEnabled,
    userSelectedWord,
    lastForceCurrentWordCall,
    forceCurrentWordDebounceTime,
    scrollController,
    playAndStopWordOnSelect,
  ];
}