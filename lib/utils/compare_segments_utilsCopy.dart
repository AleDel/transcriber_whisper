import 'package:diff_match_patch/diff_match_patch.dart';

import '../models/comparation_model.dart';
import '../models/segment.dart';

List<ComparacionSegmento> compararSegmentos(List<Segment> textoTranscrito, List<Segment> textoReal) {
  final dmp = DiffMatchPatch();

  // 1. Preparar las cadenas de texto para la comparación
  String textoTranscritoStr = _prepararCadena(textoTranscrito);
  String textoRealStr = _prepararCadena(textoReal);

  // 2. Obtener las diferencias (diffs)
  final List<Diff> diffs = dmp.diff(textoRealStr, textoTranscritoStr);
  dmp.diffCleanupSemantic(diffs);

  // 3. Procesar las diferencias para crear la lista de ComparacionSegmento
  List<ComparacionSegmento> comparacion = _procesarDiferencias(diffs, textoTranscrito, textoReal);

  // 4. Imprimir resultados (para depuración)
  _imprimirResultados(textoReal, textoTranscrito, comparacion);

  return comparacion;
}

String _prepararCadena(List<Segment> segmentos) {
  String cadena = segmentos.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).join("\n");
  return cadena.replaceAll(RegExp(r'\n+'), '\n');
}

List<ComparacionSegmento> _procesarDiferencias(List<Diff> diffs, List<Segment> textoTranscrito, List<Segment> textoReal) {
  List<ComparacionSegmento> comparacion = [];
  int currentRealWordIndex = 0;
  int currentTranscritoWordIndex = 0;
  List<String> palabrasReal = textoReal.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
  List<String> palabrasTranscrito = textoTranscrito.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();

  for (final diff in diffs) {
    final List<String> words = diff.text.split("\n").where((word) => word.isNotEmpty).toList();
    for (final word in words) {
      if (currentRealWordIndex < palabrasReal.length && currentTranscritoWordIndex < palabrasTranscrito.length) {
        switch (diff.operation) {
          case DIFF_EQUAL:
            if (palabrasReal[currentRealWordIndex] == palabrasTranscrito[currentTranscritoWordIndex]) {
              comparacion.add(
                ComparacionSegmento(
                  segmentoTranscrito: textoTranscrito[currentTranscritoWordIndex].copyWith(word: palabrasTranscrito[currentTranscritoWordIndex]),
                  palabraReal: palabrasReal[currentRealWordIndex],
                  estado: "acierto",
                  indexReal: currentRealWordIndex,
                  indexTranscrito: currentTranscritoWordIndex,
                ),
              );
              currentRealWordIndex++;
              currentTranscritoWordIndex++;
            } else {
             comparacion.add(
                ComparacionSegmento(
                  segmentoTranscrito: textoTranscrito[currentTranscritoWordIndex].copyWith(word: palabrasTranscrito[currentTranscritoWordIndex]),
                  palabraReal: palabrasReal[currentRealWordIndex],
                  estado: "sustitucion",
                  indexReal: currentRealWordIndex,
                  indexTranscrito: currentTranscritoWordIndex,
                ),
              );
             currentRealWordIndex++;
             currentTranscritoWordIndex++;
            }

            break;
          case DIFF_DELETE:
            // Comprobamos si la palabra transcrita existe
            if (currentTranscritoWordIndex < palabrasTranscrito.length) {
              comparacion.add(
                ComparacionSegmento(
                  segmentoTranscrito: Segment(start: 0, end: 0, word: "", probability: 0),
                  palabraReal: palabrasReal[currentRealWordIndex],
                  estado: "omisión",
                  indexReal: currentRealWordIndex,
                  indexTranscrito: currentTranscritoWordIndex,
                ),
              );
            }
            currentRealWordIndex++;
            currentTranscritoWordIndex++;
            break;
          case DIFF_INSERT:
            comparacion.add(
              ComparacionSegmento(
                segmentoTranscrito: textoTranscrito[currentTranscritoWordIndex].copyWith(word: palabrasTranscrito[currentTranscritoWordIndex],realWord: textoReal[currentRealWordIndex].word),
                palabraReal: textoReal[currentRealWordIndex].word,
                estado: "inserción",
                indexReal: currentRealWordIndex,
                indexTranscrito: currentTranscritoWordIndex,
              ),
            );
            currentRealWordIndex++;
            currentTranscritoWordIndex++;
            break;
        }
      } else {
        // Si no hay palabra transcrita, se considera una omisión
        if (currentRealWordIndex < palabrasReal.length) {
          comparacion.add(
            ComparacionSegmento(
              segmentoTranscrito: Segment(start: 0, end: 0, word: "", probability: 0),
              palabraReal: palabrasReal[currentRealWordIndex],
              estado: "omisión",
              indexReal: currentRealWordIndex,
              indexTranscrito: -1,
            ),
          );
          currentRealWordIndex++;
        }
      }
    }
  }
  return comparacion;
}

void _imprimirResultados(List<Segment> textoReal, List<Segment> textoTranscrito, List<ComparacionSegmento> comparacionFinal) {
  List<String> palabrasReal = textoReal.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
  List<String> palabrasTranscrito = textoTranscrito.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
  print(comparacionFinal.length);
  for (int i = 0; i < 14 && i < comparacionFinal.length; i++) {
    print("palabrasReal[$i]: ${palabrasReal.length > i ? palabrasReal[i] : 'N/A'}");
    print("palabrasTranscrito[$i]: ${palabrasTranscrito.length > i ? palabrasTranscrito[i] : 'N/A'}");
    print(
      "comparacionFinal[$i]: ${comparacionFinal[i].indexReal} ${comparacionFinal[i].estado} ${comparacionFinal[i].indexTranscrito} ${comparacionFinal[i].palabraReal} ${comparacionFinal[i].segmentoTranscrito.word}",
    );
  }
}
