import 'package:collection/collection.dart';
import 'package:transcriber_whisper/models/word_association.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

enum AssociationType {
  coincidence,
  similar,
  deleted,
  inserted,
  none,
  punctuation,
}

class Segment {
  final double start;
  final double end;
  final String word; // Palabra de la transcripción (o puntuación)
  final double probability;
  final List<String> tags;
  final WordWithSpans? wordWithSpans;
  final WordAssociation? wordAssociation;

  // Información de Alineación
  final String? realWord; // Palabra del texto de referencia (si está alineada)
  final List<String> transcribedWords; // Palabras de la transcripción asociadas
  final List<double> transcribedWordsProbabilities; // Probabilidades de las palabras asociadas
  final AssociationType associationType; // Tipo de asociación
  final int? levenshteinDistance; // Distancia de Levenshtein (si es similar)
  final int? realIndex; // Índice en el texto de referencia
  int? transcribedIndex; // Índice en la transcripción
  int? transcribedOrder; // Orden en la transcripción
  final int? realOrder; // Orden en el texto de referencia (para inserciones)
  final int? rawRealOrder; // Orden original en rawRealTextSegments

  // Información para Inserciones y Eliminaciones
  final int? realWordBeforeIndex; // Índice de la palabra real antes de la inserción
  final int? realWordAfterIndex; // Índice de la palabra real después de la inserción
  final double? realWordBeforeEnd; // Fin de la palabra real antes de la eliminación
  final double? realWordAfterStart; // Inicio de la palabra real después de la eliminación

  // Puntuación
  final bool isPunctuation;

  // Constructor
  Segment({
    required this.start,
    required this.end,
    required this.word,
    required this.probability,
    List<String>? tags,
    this.wordWithSpans,
    this.wordAssociation,
    this.realWord,
    List<String>? transcribedWords,
    List<double>? transcribedWordsProbabilities,
    required this.associationType,
    this.levenshteinDistance,
    this.realIndex,
    this.transcribedIndex,
    this.transcribedOrder,
    this.realOrder,
    this.realWordBeforeIndex,
    this.realWordAfterIndex,
    this.realWordBeforeEnd,
    this.realWordAfterStart,
    this.isPunctuation = false,
    this.rawRealOrder,
  })  : tags = tags ?? [],
        transcribedWords = transcribedWords ?? [],
        transcribedWordsProbabilities = transcribedWordsProbabilities ?? [];

  // Getter para la palabra asociada (si existe)
  String get associatedWord => transcribedWords.isNotEmpty ? transcribedWords[0] : "";

  // Factory para crear desde un Map
  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      start: map['start']?.toDouble() ?? 0.0,
      end: map['end']?.toDouble() ?? 0.0,
      word: map['word'] ?? '',
      probability: map['probability']?.toDouble() ?? 0.0,
      associationType: AssociationType.none,
    );
  }

  // Método toString para debugging
  @override
  String toString() {
    return 'Segment{start: $start, end: $end, word: $word, probability: $probability, tags: $tags, wordWithSpans: $wordWithSpans, wordAssociation: $wordAssociation, realWord: $realWord, transcribedWords: $transcribedWords, transcribedWordsProbabilities: $transcribedWordsProbabilities, associationType: $associationType, levenshteinDistance: $levenshteinDistance, realIndex: $realIndex, transcribedIndex: $transcribedIndex, transcribedOrder: $transcribedOrder, realOrder: $realOrder, realWordBeforeIndex: $realWordBeforeIndex, realWordAfterIndex: $realWordAfterIndex, realWordBeforeEnd: $realWordBeforeEnd, realWordAfterStart: $realWordAfterStart, isPunctuation: $isPunctuation, rawRealOrder: $rawRealOrder}';
  }

  // Método copyWith para crear copias modificadas
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
    AssociationType? associationType,
    int? levenshteinDistance,
    int? realIndex,
    int? transcribedIndex,
    int? transcribedOrder,
    int? realOrder,
    int? realWordBeforeIndex,
    int? realWordAfterIndex,
    double? realWordBeforeEnd,
    double? realWordAfterStart,
    bool? isPunctuation,
    int? rawRealOrder,
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
      associationType: associationType ?? this.associationType,
      levenshteinDistance: levenshteinDistance ?? this.levenshteinDistance,
      realIndex: realIndex ?? this.realIndex,
      transcribedIndex: transcribedIndex ?? this.transcribedIndex,
      transcribedOrder: transcribedOrder ?? this.transcribedOrder,
      realOrder: realOrder ?? this.realOrder,
      realWordBeforeIndex: realWordBeforeIndex ?? this.realWordBeforeIndex,
      realWordAfterIndex: realWordAfterIndex ?? this.realWordAfterIndex,
      realWordBeforeEnd: realWordBeforeEnd ?? this.realWordBeforeEnd,
      realWordAfterStart: realWordAfterStart ?? this.realWordAfterStart,
      isPunctuation: isPunctuation ?? this.isPunctuation,
      rawRealOrder: rawRealOrder ?? this.rawRealOrder,
    );
  }
}