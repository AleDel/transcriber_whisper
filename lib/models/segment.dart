import 'package:transcriber_whisper/models/word_association.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

class Segment {
  final double start;
  final double end;
  final String word;
  final double probability;
  List<String> tags;
  WordWithSpans? wordWithSpans;
  WordAssociation? wordAssociation;
  String? realWord;
  List<String>? transcribedWords;
  List<double>? transcribedWordsProbabilities;
  String? associationType; // Nueva propiedad
  int? levenshteinDistance; // Nueva propiedad

  Segment({
    required this.start,
    required this.end,
    required this.word,
    required this.probability,
    List<String>? tags,
    this.wordWithSpans,
    this.wordAssociation,
    this.realWord,
    this.transcribedWords,
    this.transcribedWordsProbabilities,
    this.associationType, // Inicializar la nueva propiedad
    this.levenshteinDistance, // Inicializar la nueva propiedad
  }) : tags = tags ?? []; // Initialize tags as an empty list if null

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      start: map['start']?.toDouble() ?? 0.0,
      end: map['end']?.toDouble() ?? 0.0,
      word: map['word']?.replaceAll(RegExp(r'[^\w\s]'), '') ?? '',
      probability: map['probability']?.toDouble() ?? 0.0,
    );
  }

  Segment copyWith({
    double? start,
    double? end,
    String? word,
    double? probability,
    List<String>? tags,
    WordWithSpans? wordWithSpans,
    WordAssociation? wordAssociation,
    String? realWord,
    List<String>? transcribedWords,
    List<double>? transcribedWordsProbabilities,
    String? associationType, // Añadir la nueva propiedad
    int? levenshteinDistance, // Añadir la nueva propiedad
  }) {
    return Segment(
      start: start ?? this.start,
      end: end ?? this.end,
      word: word ?? this.word,
      probability: probability ?? this.probability,
      tags: tags ?? this.tags,
      wordWithSpans: wordWithSpans ?? this.wordWithSpans,
      wordAssociation: wordAssociation ?? this.wordAssociation,
      realWord: realWord ?? this.realWord,
      transcribedWords: transcribedWords ?? this.transcribedWords,
      transcribedWordsProbabilities: transcribedWordsProbabilities ?? this.transcribedWordsProbabilities,
      associationType: associationType ?? this.associationType, // Asignar la nueva propiedad
      levenshteinDistance: levenshteinDistance ?? this.levenshteinDistance, // Asignar la nueva propiedad
    );
  }
}