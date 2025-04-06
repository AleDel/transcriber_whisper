import 'package:transcriber_whisper/models/word_association.dart';
import 'package:transcriber_whisper/models/word_with_spans.dart';

class Segment {
  double start;
  double end;
  final String word; // palabra de la transcripcion
  final double probability;
  List<String> tags;
  WordWithSpans? wordWithSpans;
  WordAssociation? wordAssociation;
  String? realWord;
  List<String>? transcribedWords;
  List<double>? transcribedWordsProbabilities;
  String? associationType;
  int? levenshteinDistance;
  int? realIndex;
  int? transcribedIndex;
  int? transcribedOrder;
  int? insertionOrder;
  int? realOrder; // Nuevo: Orden en el texto real (para inserciones)
  int? realWordBeforeIndex; // Nuevo: Índice de la palabra real antes de la inserción
  int? realWordAfterIndex; // Nuevo: Índice de la palabra real después de la inserción
  double? realWordBeforeEnd; // Nuevo: Fin de la palabra real antes de la eliminacion
  double? realWordAfterStart; // Nuevo: Inicio de la palabra real despues de la eliminacion
  bool isPunctuation;
  int? rawRealOrder; // Nuevo: Orden original en rawRealTextSegments

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
    this.associationType,
    this.levenshteinDistance,
    this.realIndex,
    this.transcribedIndex,
    this.transcribedOrder,
    this.insertionOrder,
    this.realOrder, // Nuevo
    this.realWordBeforeIndex, // Nuevo
    this.realWordAfterIndex, // Nuevo
    this.realWordBeforeEnd, // Nuevo
    this.realWordAfterStart,
    this.isPunctuation = false, // Nuevo
    this.rawRealOrder, // Nuevo
  }) : tags = tags ?? []; // Initialize tags as an empty list if null

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      start: map['start']?.toDouble() ?? 0.0,
      end: map['end']?.toDouble() ?? 0.0,
      word: map['word'] ?? '',
      probability: map['probability']?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'Segment{start: $start, end: $end, word: $word, probability: $probability, realWord: $realWord, wordAssociation: $wordAssociation, transcribedWords: $transcribedWords, transcribedWordsProbabilities: $transcribedWordsProbabilities, associationType: $associationType, levenshteinDistance: $levenshteinDistance, realIndex: $realIndex, transcribedIndex: $transcribedIndex, transcribedOrder: $transcribedOrder, insertionOrder: $insertionOrder, realOrder: $realOrder, realWordBeforeIndex: $realWordBeforeIndex, realWordAfterIndex: $realWordAfterIndex, realWordBeforeEnd: $realWordBeforeEnd, realWordAfterStart: $realWordAfterStart, isPunctuation: $isPunctuation, rawRealOrder: $rawRealOrder}';
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
    String? associationType,
    int? levenshteinDistance,
    int? realIndex,
    int? transcribedIndex,
    int? transcribedOrder,
    int? insertionOrder,
    int? realOrder, // Nuevo
    int? realWordBeforeIndex, // Nuevo
    int? realWordAfterIndex, // Nuevo
    double? realWordBeforeEnd, // Nuevo
    double? realWordAfterStart, // Nuevo
    bool? isPunctuation, // Nuevo
    int? rawRealOrder, // Nuevo
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
      insertionOrder: insertionOrder ?? this.insertionOrder,
      realOrder: realOrder ?? this.realOrder, // Nuevo
      realWordBeforeIndex: realWordBeforeIndex ?? this.realWordBeforeIndex, // Nuevo
      realWordAfterIndex: realWordAfterIndex ?? this.realWordAfterIndex, // Nuevo
      realWordBeforeEnd: realWordBeforeEnd ?? this.realWordBeforeEnd, // Nuevo
      realWordAfterStart: realWordAfterStart ?? this.realWordAfterStart, // Nuevo
      isPunctuation: isPunctuation ?? this.isPunctuation, // Nuevo
      rawRealOrder: rawRealOrder ?? this.rawRealOrder, // Nuevo
    );
  }
}