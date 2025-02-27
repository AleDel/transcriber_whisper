class Transcription {
  final List<Segment> segments;
  final String? fulltext;

  Transcription({required this.segments, this.fulltext});

  factory Transcription.fromListMap(dynamic listmap, {bool generateFullText = true}) {
    List<Segment> segments = [];
    String fullTextTranscription = "";
    if (listmap is List) {
      for (var e in listmap) {
        if (e is Map<String, dynamic>) {
          segments.add(Segment.fromMap(e));
          if (generateFullText) {
            fullTextTranscription += "${e["word"]} ";
          }
        } else {
          throw FormatException("Error: Elemento no es un mapa: $e");
        }
      }
    } else {
      throw FormatException("Error: No es una lista");
    }
    return Transcription(
      segments: segments,
      fulltext: generateFullText ? fullTextTranscription : null,
    );
  }

  Transcription copyWith({List<Segment>? segments, String? fulltext}) {
    return Transcription(segments: segments ?? this.segments, fulltext: fulltext ?? this.fulltext);
  }
}

class Segment {
  final double start;
  final double end;
  final String word;
  final double probability;
  List<String> tags;

  Segment({
    required this.start,
    required this.end,
    required this.word,
    required this.probability,
    List<String>? tags, // Make tags optional in the constructor
  }) : tags = tags ?? []; // Initialize tags as an empty list if null

  factory Segment.fromMap(Map<String, dynamic> map) {
    return Segment(
      start: map['start'] as double,
      end: map['end'] as double,
      word: map['word'] as String,
      probability: map['probability'] as double,
    );
  }

  Segment copyWith({
    double? start,
    double? end,
    String? word,
    double? probability,
    List<String>? tags,
  }) {
    return Segment(
      start: start ?? this.start,
      end: end ?? this.end,
      word: word ?? this.word,
      probability: probability ?? this.probability,
      tags: tags ?? this.tags,
    );
  }
}
