import 'package:equatable/equatable.dart';
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

enum TranscribeStatus {
  initial,
  loaded,
  loading,
  error,
  noserver,
  isPlayerplaying,
  isPlayerpause,
  isPlayerstopped,
  isPlayercompleted,
  isPlayerdisposed,
}

class TranscribeState extends Equatable {
  final TranscribeStatus status;
  final Transcription? transcription;
  final Data? extradata;
  final String? melSpectrogramBase64;
  final List<List<double>>? melSpectrogramData;
  //final List<double> samples;
  final String? waveformImageBase64;
  final List<String>? logs_mfa;
  final bool editMode;
  final String? errorMessage;

  const TranscribeState({
    required this.status,
    this.transcription,
    this.extradata = const Data(),
    this.melSpectrogramBase64,
    this.melSpectrogramData,
    //this.samples = const [],
    this.waveformImageBase64,
    this.logs_mfa,
    this.editMode = true,
    this.errorMessage,
  });

  TranscribeState copyWith({
    TranscribeStatus? status,
    Transcription? transcription,
    Data? extradata,
    String? melSpectrogramBase64,
    List<List<double>>? melSpectrogramData,
    //List<double>? samples,
    String? waveformImageBase64,
    List<String>? logs_mfa,
    bool? editMode,
    String? errorMessage,
  }) {
    return TranscribeState(
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      extradata: extradata ?? this.extradata,
      melSpectrogramBase64: melSpectrogramBase64 ?? this.melSpectrogramBase64,
      melSpectrogramData: melSpectrogramData ?? this.melSpectrogramData,
      //samples: samples ?? this.samples,
      waveformImageBase64: waveformImageBase64 ?? this.waveformImageBase64,
      logs_mfa: logs_mfa ?? this.logs_mfa,
      editMode: editMode ?? this.editMode,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transcription,
    extradata,
    melSpectrogramBase64,
    waveformImageBase64,
    logs_mfa,
    editMode,
    errorMessage,
  ];
}