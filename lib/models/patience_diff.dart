import 'dart:math';

import 'package:transcriber_whisper/models/patience_sequence_matcher.dart';

class PatienceDiff {
  /// Calcula las diferencias entre dos listas de cadenas usando el algoritmo Patience Diff.
  ///
  /// [a]: La primera lista de cadenas.
  /// [b]: La segunda lista de cadenas.
  ///
  /// Devuelve una lista de [DiffLine] que representan las diferencias entre las dos listas.
  static List<DiffLine> diff(List<String> a, List<String> b) {
    print("PatienceDiff.diff: a=$a, b=$b");
    final matcher = PatienceSequenceMatcher<String>();
    final matches = matcher.findMatchingBlocks(a, b);
    print("PatienceDiff.diff: matches=$matches");

    final diffLines = <DiffLine>[];
    var lastA = 0;
    var lastB = 0;

    for (final match in matches) {
      print("PatienceDiff.diff: match: startA=${match.startA}, startB=${match.startB}, length=${match.length}");
      // Procesar las eliminaciones
      for (var i = lastA; i < match.startA; i++) {
        print("PatienceDiff.diff: Eliminación: line=${a[i]}, aIndex=$i, bIndex=-1");
        diffLines.add(DiffLine(line: a[i], aIndex: i, bIndex: -1));
      }
      // Procesar las inserciones
      for (var i = lastB; i < match.startB; i++) {
        print("PatienceDiff.diff: Inserción: line=${b[i]}, aIndex=-1, bIndex=$i");
        diffLines.add(DiffLine(line: b[i], aIndex: -1, bIndex: i));
      }
      // Procesar las coincidencias
      for (var i = 0; i < match.length; i++) {
        print("PatienceDiff.diff: Coincidencia: line=${a[match.startA + i]}, aIndex=${match.startA + i}, bIndex=${match.startB + i}");
        diffLines.add(DiffLine(line: a[match.startA + i], aIndex: match.startA + i, bIndex: match.startB + i));
      }
      lastA = match.startA + match.length;
      lastB = match.startB + match.length;
    }
    // Procesar las eliminaciones restantes
    for (var i = lastA; i < a.length; i++) {
      print("PatienceDiff.diff: Eliminación restante: line=${a[i]}, aIndex=$i, bIndex=-1");
      diffLines.add(DiffLine(line: a[i], aIndex: i, bIndex: -1));
    }
    // Procesar las inserciones restantes
    for (var i = lastB; i < b.length; i++) {
      print("PatienceDiff.diff: Inserción restante: line=${b[i]}, aIndex=-1, bIndex=$i");
      diffLines.add(DiffLine(line: b[i], aIndex: -1, bIndex: i));
    }
    print("PatienceDiff.diff: diffLines=$diffLines");
    return diffLines;
  }
}

/// Representa una línea en la comparación de diferencias.
class DiffLine {
  /// La línea de texto.
  final String line;

  /// El índice de la línea en la lista 'a' (-1 si no está en 'a').
  final int aIndex;

  /// El índice de la línea en la lista 'b' (-1 si no está en 'b').
  final int bIndex;

  /// Indica si la línea se ha movido.
  bool moved = false;

  /// Constructor de [DiffLine].
  DiffLine({required this.line, required this.aIndex, required this.bIndex});
}