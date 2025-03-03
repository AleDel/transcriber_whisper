import 'package:equatable/equatable.dart';

class ExtraData extends Equatable {
  final Duration? audioDuration;
  final Duration? audioPosition;
  final int? currentWordIndex;
  final bool playAndStopWordOnSelect;

  const ExtraData({
    this.audioDuration,
    this.audioPosition,
    this.currentWordIndex,
    this.playAndStopWordOnSelect = false,
  });

  ExtraData copyWith({
    Duration? audioDuration,
    Duration? audioPosition,
    int? currentWordIndex,
    bool? playAndStopWordOnSelect,
  }) {
    return ExtraData(
      audioDuration: audioDuration ?? this.audioDuration,
      audioPosition: audioPosition ?? this.audioPosition,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      playAndStopWordOnSelect: playAndStopWordOnSelect ?? this.playAndStopWordOnSelect,
    );
  }

  @override
  List<Object?> get props => [audioDuration, audioPosition, currentWordIndex, playAndStopWordOnSelect];
}