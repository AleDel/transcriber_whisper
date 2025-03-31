import 'package:transcriber_whisper/models/segment.dart';

class Palabra {
  final String texto;
  final int index;
  final Segment segmento;

  Palabra({required this.texto, required this.index, required this.segmento});

  @override
  String toString() {
    return 'Palabra{texto: $texto, index: $index, segmento: $segmento}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Palabra &&
              runtimeType == other.runtimeType &&
              texto == other.texto &&
              index == other.index;

  @override
  int get hashCode => texto.hashCode ^ index.hashCode;
}