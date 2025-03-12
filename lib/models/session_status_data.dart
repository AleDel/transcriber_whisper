/*import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum PlayerStatus {
  playing,
  paused,
  stopped,
  completed,
  idle,
}

class SessionStatusData extends Equatable {
  final String sessionId;
  final PlayerStatus playerStatus;
  final Duration audioPosition;
  final Duration audioDuration;
  final int currentWordIndex;
  final bool autoScrollEnabled;
  final bool userSelectedWord;
  final DateTime? lastForceCurrentWordCall;
  final Duration forceCurrentWordDebounceTime;
  final ScrollController scrollController;
  final bool playAndStopWordOnSelect;

  SessionStatusData({
    required this.sessionId,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.playerStatus = PlayerStatus.idle,
    this.currentWordIndex = 0,
    this.autoScrollEnabled = false,
    this.userSelectedWord = false,
    this.lastForceCurrentWordCall,
    this.forceCurrentWordDebounceTime = const Duration(milliseconds: 100),
    ScrollController? scrollController,
    this.playAndStopWordOnSelect = false,
  }) : scrollController = scrollController ?? ScrollController();

  SessionStatusData copyWith({
    String? sessionId,
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
    return SessionStatusData(
      sessionId: sessionId ?? this.sessionId,
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
      'sessionId': sessionId,
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

  static SessionStatusData fromMap(Map<String, dynamic> map) {
    return SessionStatusData(
      sessionId: map['sessionId'] as String,
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
    sessionId,
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
}*/