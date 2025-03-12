part of 'transcription_cubit.dart';

enum TranscriptionStatus {
  pending,
  loading,
  connectedAudioProcess,
  processingAudio,
  processingTranscription,
  completedAll,
  error,
  completedAudioProcess,
  completedTranscription
}

class TranscriptionState extends Equatable {
  final TranscriptionStatus transcriptionStatus;
  final String? errorMessage;
  final String? errorDetails;
  final Project? currentProject;

  const TranscriptionState({
    //this.status = TranscriptionStatus.pending,
    required this.transcriptionStatus,
    this.errorMessage,
    this.errorDetails,
    this.currentProject,
  });

  TranscriptionState copyWith({
    TranscriptionStatus? transcriptionStatus,
    String? errorMessage,
    String? errorDetails,
    Project? currentProject,
  }) {
    return TranscriptionState(
      transcriptionStatus: transcriptionStatus ?? this.transcriptionStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      errorDetails: errorDetails ?? this.errorDetails,
      currentProject: currentProject ?? this.currentProject,
    );
  }

  @override
  List<Object?> get props => [transcriptionStatus, errorMessage, errorDetails, currentProject];
}