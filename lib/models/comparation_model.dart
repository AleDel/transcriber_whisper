import 'package:transcriber_whisper/models/segment.dart';

class ComparacionSegmento {
  Segment segmentoTranscrito;
  String? palabraReal; // Puede ser null si es una inserción
  String estado; // "acierto", "insercion", "omision", "sustitucion"
  int indexReal;
  int indexTranscrito;

  ComparacionSegmento({
    required this.segmentoTranscrito,
    this.palabraReal,
    required this.estado,
    required this.indexReal,
    required this.indexTranscrito,
  });
  ComparacionSegmento copyWith({
    Segment? segmentoTranscrito,
    String? palabraReal,
    String? estado,
    int? indexReal,
    int? indexTranscrito,
  }) {
    return ComparacionSegmento(
      segmentoTranscrito: segmentoTranscrito ?? this.segmentoTranscrito,
      palabraReal: palabraReal ?? this.palabraReal,
      estado: estado ?? this.estado,
      indexReal: indexReal ?? this.indexReal,
      indexTranscrito: indexTranscrito ?? this.indexTranscrito,
    );
  }
}