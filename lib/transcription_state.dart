import 'package:equatable/equatable.dart';
import 'package:transcriber_whisper/models/alignment_mfa_data.dart';
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

import 'models/comparation_model.dart';
import 'models/word_with_spans.dart';

enum TranscriptionStatus {
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
  success,
  checkingAudio,
  audioChecked,
  checkingServerStatus,
  serverStatusChecked,
  serverBusy
}

class CheckAudioResult {
  final bool isTranscribed;
  final String message;
  final String? nombreAudio;
  final String? action;
  final String status; // Ahora es requerido

  CheckAudioResult({required this.isTranscribed, required this.message, this.nombreAudio, this.action, required this.status});
}
class ServerStatusResult {
  final String? file;
  final String status;

  ServerStatusResult({this.file, required this.status});
}

class TranscriptionState extends Equatable {
  final TranscriptionStatus status;
  final Transcription? transcription;
  final Transcription? realtextComoTranscription;
  final List<ComparacionSegmento>? comparacion;
  final AlignmentMFAData? textoEscritoAlineado;
  final Data? extradata;
  final String? melSpectrogramBase64;
  final List<List<double>>? melSpectrogramData;
  //final List<double> samples;
  final String? waveformImageBase64;
  final List<String>? logs_mfa;
  final bool editMode;
  final String? errorMessage;
  final List<WordWithSpans> wordsWithSpans;
  final String? textoRealformadoparrafos;
  final CheckAudioResult? checkAudioResult; // Nuevo campo
  final ServerStatusResult? serverStatusResult; // Nuevo campo

  const TranscriptionState({
    required this.status,
    this.transcription,
    this.realtextComoTranscription,
    this.comparacion,
    this.textoEscritoAlineado,
    this.extradata = const Data(),
    this.melSpectrogramBase64,
    this.melSpectrogramData,
    //this.samples = const [],
    this.waveformImageBase64,
    this.logs_mfa,
    this.editMode = true,
    this.errorMessage,
    this.wordsWithSpans = const [],
    this.textoRealformadoparrafos,
    this.checkAudioResult, // Nuevo parámetro
    this.serverStatusResult, // Nuevo parámetro
  });

  TranscriptionState copyWith({
    TranscriptionStatus? status,
    Transcription? transcription,
    Transcription? realtextComoTranscription,
    List<ComparacionSegmento>? comparacion,
    AlignmentMFAData? textoEscritoAlineado,
    Data? extradata,
    String? melSpectrogramBase64,
    List<List<double>>? melSpectrogramData,
    //List<double>? samples,
    String? waveformImageBase64,
    List<String>? logs_mfa,
    bool? editMode,
    String? errorMessage,
    List<WordWithSpans>? wordsWithSpans,
    String? textoRealformadoparrafos,
    CheckAudioResult? checkAudioResult, // Nuevo parámetro
    ServerStatusResult? serverStatusResult, // Nuevo parámetro
  }) {
    return TranscriptionState(
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      realtextComoTranscription: realtextComoTranscription ?? this.realtextComoTranscription,
      comparacion: comparacion ?? this.comparacion,
      textoEscritoAlineado: textoEscritoAlineado ?? this.textoEscritoAlineado,
      extradata: extradata ?? this.extradata,
      melSpectrogramBase64: melSpectrogramBase64 ?? this.melSpectrogramBase64,
      melSpectrogramData: melSpectrogramData ?? this.melSpectrogramData,
      //samples: samples ?? this.samples,
      waveformImageBase64: waveformImageBase64 ?? this.waveformImageBase64,
      logs_mfa: logs_mfa ?? this.logs_mfa,
      editMode: editMode ?? this.editMode,
      errorMessage: errorMessage ?? this.errorMessage,
      wordsWithSpans: wordsWithSpans ?? this.wordsWithSpans,
      textoRealformadoparrafos: textoRealformadoparrafos ?? this.textoRealformadoparrafos,
      checkAudioResult: checkAudioResult ?? this.checkAudioResult,
      serverStatusResult: serverStatusResult ?? this.serverStatusResult, // Nuevo campo
    );
  }

  @override
  List<Object?> get props => [
    status,
    transcription,
    realtextComoTranscription,
    comparacion,
    textoEscritoAlineado,
    extradata,
    melSpectrogramBase64,
    waveformImageBase64,
    logs_mfa,
    editMode,
    errorMessage,
    wordsWithSpans,
    textoRealformadoparrafos,
    checkAudioResult,
    serverStatusResult, // Nuevo campo
  ];
}