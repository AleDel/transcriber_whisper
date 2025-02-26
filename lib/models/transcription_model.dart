class Transcription {
  final List<Segment> segments;
  final String? fulltext;

  Transcription({required this.segments, this.fulltext});

  factory Transcription.fromListMap(dynamic listmap) {
    List<Segment> segments = [];
    String fullTextTranscription = "";
    if (listmap is List) {
      for (var e in listmap) {
        if (e is Map<String, dynamic>) {
          segments.add(Segment.fromMap(e));
          fullTextTranscription += "${e["word"]} ";
        } else {
          print("Error: Elemento no es un mapa: $e");
          // Manejar el error, por ejemplo, ignorar el elemento o lanzar una excepción
        }
      }
    } else {
      print("Error: No es una lista");
      // Manejar el error, por ejemplo, lanzar una excepción
    }
    return Transcription(segments: segments, fulltext: fullTextTranscription);
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
}
