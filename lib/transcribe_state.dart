import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session.dart';
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

enum TranscribeStatus {
  initial,
  loading,
  loaded,
  error,
  noserver,
}

enum PlayerStatus {
  initial,
  playing,
  paused,
  stopped,
  completed,
  disposed,
}

class TranscribeState extends Equatable {
  final TranscribeStatus status;
  final PlayerStatus playerStatus;
  final String? errorMessage;
  final String? errorDetails;
  final Transcription? transcription;
  final List<Project>? projects;
  final Project? currentProject;
  final List<PlatformFile> files;
  final ExtraData? extradata;
  final bool editMode;
  final bool autoScrollEnabled;
  final bool playAndStopWordOnSelect;
  final List<String>? logs_mfa;

  const TranscribeState({
    this.status = TranscribeStatus.initial,
    this.playerStatus = PlayerStatus.initial,
    this.errorMessage,
    this.errorDetails,
    this.transcription,
    this.projects,
    this.currentProject,
    this.files = const [],
    this.extradata,
    this.editMode = false,
    this.autoScrollEnabled = false,
    this.playAndStopWordOnSelect = false,
    this.logs_mfa,
  });

  TranscribeState copyWith({
    TranscribeStatus? status,
    PlayerStatus? playerStatus,
    String? errorMessage,
    String? errorDetails,
    Transcription? transcription,
    List<Project>? projects,
    Project? currentProject,
    List<PlatformFile>? files,
    ExtraData? extradata,
    bool? editMode,
    bool? autoScrollEnabled,
    bool? playAndStopWordOnSelect,
    List<String>? logs_mfa,
  }) {
    return TranscribeState(
      status: status ?? this.status,
      playerStatus: playerStatus ?? this.playerStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      errorDetails: errorDetails ?? this.errorDetails,
      transcription: transcription ?? this.transcription,
      projects: projects ?? this.projects,
      currentProject: currentProject ?? this.currentProject,
      files: files ?? this.files,
      extradata: extradata ?? this.extradata,
      editMode: editMode ?? this.editMode,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      playAndStopWordOnSelect: playAndStopWordOnSelect ?? this.playAndStopWordOnSelect,
      logs_mfa: logs_mfa ?? this.logs_mfa,
    );
  }

  @override
  List<Object?> get props => [
    status,
    playerStatus,
    errorMessage,
    errorDetails,
    transcription,
    projects,
    currentProject,
    files,
    extradata,
    editMode,
    autoScrollEnabled,
    playAndStopWordOnSelect,
    logs_mfa,
  ];
}