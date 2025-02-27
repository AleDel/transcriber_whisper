import 'package:equatable/equatable.dart';

class Data extends Equatable {
  final int currentWordIndex;
  final Duration audioPosition;
  final Duration audioDuration;
  final String? audioFilePath;
  final bool playAndStopWordOnSelect;

  const Data({
    this.currentWordIndex = -1,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.audioFilePath,
    this.playAndStopWordOnSelect = true,
  });

  Data copyWith({
    int? currentWordIndex,
    Duration? audioPosition,
    Duration? audioDuration,
    String? audioFilePath,
    bool? playAndStopWordOnSelect,
  }) {
    return Data(
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      audioPosition: audioPosition ?? this.audioPosition,
      audioDuration: audioDuration ?? this.audioDuration,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      playAndStopWordOnSelect: playAndStopWordOnSelect ?? this.playAndStopWordOnSelect,
    );
  }

  @override
  List<Object?> get props => [
    currentWordIndex,
    audioPosition,
    audioDuration,
    audioFilePath,
    playAndStopWordOnSelect,
  ];
}
