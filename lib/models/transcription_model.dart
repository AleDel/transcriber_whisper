import 'package:equatable/equatable.dart';

import 'alignment_mfa_data.dart';

enum SegmentType { word, phoneme }

class Transcription extends Equatable {
  final List<Segment> segments;

  const Transcription({required this.segments});

  factory Transcription.fromListMap(List<dynamic> listMap) {
    return Transcription(
      segments: listMap.map((e) => Segment.fromMap(e as Map<String, dynamic>)).toList(),
    );
  }

  Transcription copyWith({
    List<Segment>? segments,
  }) {
    return Transcription(
      segments: segments ?? this.segments,
    );
  }

  String get textcolumna {
    return segments.map((segment) => segment.word.toLowerCase()).join('\n');
  }

  String get fulltext {
    return segments.map((segment) => segment.word).join(' ');
  }

  // Nuevo método toListMap
  List<Map<String, dynamic>> toListMap() {
    return segments.map((segment) => segment.toMap()).toList();
  }

  @override
  List<Object?> get props => [segments];
}

class Segment extends Equatable {
  final double start;
  final double end;
  final String word;
  final double probability;
  final List<String> tags;

  const Segment({
    required this.start,
    required this.end,
    required this.word,
    required this.probability,
    this.tags = const [],
  });

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      start: map['start']?.toDouble() ?? 0.0,
      end: map['end']?.toDouble() ?? 0.0,
      word: map['word'] as String? ?? '',
      probability: map['probability']?.toDouble() ?? 0.0,
      tags: map['tags'] != null ? List<String>.from(map['tags'] as List) : [],
      //phonemes: map['phonemes'] != null ? List<Entry>.from(map['phonemes'] as List) : [],
    );
  }

  Segment copyWith({
    double? start,
    double? end,
    String? word,
    double? probability,
    List<String>? tags,
    //List<Entry>? phonemes,
  }) {
    return Segment(
      start: start ?? this.start,
      end: end ?? this.end,
      word: word ?? this.word,
      probability: probability ?? this.probability,
      tags: tags ?? this.tags,
      //phonemes: phonemes ?? this.phonemes,
    );
  }

  // Nuevo método toMap
  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'word': word,
      'probability': probability,
      'tags': tags,
    };
  }

  @override
  List<Object?> get props => [start, end, word, probability, tags];
}