import 'package:equatable/equatable.dart';

class Data extends Equatable {
  final int currentWordIndex;
  final int currentAssociatedWordIndex;
  final Duration audioPosition;
  final Duration audioDuration;
  final String? audioFilePath;
  final bool playAndStopWordOnSelect;

  const Data({
    this.currentWordIndex = 0,
    this.currentAssociatedWordIndex = 0,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.audioFilePath,
    this.playAndStopWordOnSelect = true,
  });

  Data copyWith({
    int? currentAudioWordIndex,
    int? currentAssociatedWordIndex,
    Duration? audioPosition,
    Duration? audioDuration,
    String? audioFilePath,
    bool? playAndStopWordOnSelect,
  }) {
    return Data(
      currentWordIndex: currentAudioWordIndex ?? this.currentWordIndex,
      currentAssociatedWordIndex: currentAssociatedWordIndex ?? this.currentAssociatedWordIndex,
      audioPosition: audioPosition ?? this.audioPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      playAndStopWordOnSelect: playAndStopWordOnSelect ?? this.playAndStopWordOnSelect,
    );
  }

  @override
  List<Object?> get props => [
    currentWordIndex,
    currentAssociatedWordIndex,
    audioPosition,
    audioDuration,
    audioFilePath,
    playAndStopWordOnSelect,
  ];
}