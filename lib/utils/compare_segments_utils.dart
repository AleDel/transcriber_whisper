import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:diffutil_dart/diffutil.dart' as diffutil;

import '../models/comparation_model.dart';
import '../models/palabra.dart';
import '../models/palabraListDiff.dart';
import '../models/segment.dart';

class ComparacionGrupo {
  final List<ComparacionSegmento> segmentos;
  final String estado;
  final int indexRealInicial;
  final int indexRealFinal;
  final int indexTranscritoInicial;
  final int indexTranscritoFinal;

  ComparacionGrupo({
    required this.segmentos,
    required this.estado,
    required this.indexRealInicial,
    required this.indexRealFinal,
    required this.indexTranscritoInicial,
    required this.indexTranscritoFinal,
  });
}

List<Object> compararSegmentos(List<Segment> textoTranscrito, List<Segment> textoReal) {
  // 3. Procesar las diferencias para crear la lista de ComparacionSegmento
  List<Object> comparacion = _procesarDiferenciasDiffUtil(textoTranscrito, textoReal);

  // 4. Imprimir resultados (para depuración)
  _imprimirResultados(textoReal, textoTranscrito, comparacion);

  return comparacion;
}

String _prepararCadena(List<Segment> segmentos) {
  String cadena = segmentos.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).join("\n");
  return cadena.replaceAll(RegExp(r'\n+'), '\n');
}

List<Object> _procesarDiferenciasDiffUtil(List<Segment> textoTranscrito, List<Segment> textoReal) {
  List<Palabra> palabrasReal =
      textoReal.asMap().entries.map((entry) => Palabra(texto: entry.value.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ''), index: entry.key, segmento: entry.value)).toList();
  List<Palabra> palabrasTranscrito =
      textoTranscrito
          .asMap()
          .entries
          .map((entry) => Palabra(texto: entry.value.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ''), index: entry.key, segmento: entry.value))
          .toList();

  final diff = diffutil.calculateDiff(PalabraListDiff(palabrasReal, palabrasTranscrito));
  final updates = diff.getUpdates();
  List<Object> comparacion = [];
  List<ComparacionSegmento> buffer = [];
  int currentRealWordIndex = 0;
  int currentTranscritoWordIndex = 0;
  for (final update in updates) {
    update.when(
      insert: (pos, count) {
        for (int i = 0; i < count; i++) {
          buffer.add(ComparacionSegmento(segmentoTranscrito: palabrasTranscrito[pos + i].segmento, palabraReal: "", estado: "inserción", indexReal: -1, indexTranscrito: pos + i));
        }
      },
      remove: (pos, count) {
        // Procesar el buffer si hay algo
        if (buffer.isNotEmpty) {
          comparacion.add(
            ComparacionGrupo(
              segmentos: buffer,
              estado: "intento_fallido",
              indexRealInicial: buffer.first.indexReal,
              indexRealFinal: buffer.last.indexReal,
              indexTranscritoInicial: buffer.first.indexTranscrito,
              indexTranscritoFinal: buffer.last.indexTranscrito,
            ),
          );
          buffer = [];
        }
        for (int i = 0; i < count; i++) {
          comparacion.add(
            ComparacionSegmento(
              segmentoTranscrito: Segment(start: 0, end: 0, word: "", probability: 0),
              palabraReal: palabrasReal[pos + i].texto,
              estado: "omisión",
              indexReal: pos + i,
              indexTranscrito: -1,
            ),
          );
        }
      },
      change: (pos, payload) {
        if (buffer.isNotEmpty) {
          comparacion.add(
            ComparacionGrupo(
              segmentos: buffer,
              estado: "intento_fallido",
              indexRealInicial: buffer.first.indexReal,
              indexRealFinal: buffer.last.indexReal,
              indexTranscritoInicial: buffer.first.indexTranscrito,
              indexTranscritoFinal: buffer.last.indexTranscrito,
            ),
          );
          buffer = [];
        }
        comparacion.add(
          ComparacionSegmento(
            segmentoTranscrito: palabrasTranscrito[pos].segmento,
            palabraReal: palabrasReal[pos].texto,
            estado: "sustitucion",
            indexReal: pos,
            indexTranscrito: pos,
          ),
        );
      },
      move: (from, to) {
        // No se usa en este caso
      },
    );
  }
  // Procesar el buffer si hay algo al final
  if (buffer.isNotEmpty) {
    comparacion.add(
      ComparacionGrupo(
        segmentos: buffer,
        estado: "intento_fallido",
        indexRealInicial: buffer.first.indexReal,
        indexRealFinal: buffer.last.indexReal,
        indexTranscritoInicial: buffer.first.indexTranscrito,
        indexTranscritoFinal: buffer.last.indexTranscrito,
      ),
    );
  }
  // Comprobar si hay palabras reales o transcritas que no se han comparado
  while (currentRealWordIndex < palabrasReal.length || currentTranscritoWordIndex < palabrasTranscrito.length) {
    if (currentRealWordIndex < palabrasReal.length && currentTranscritoWordIndex < palabrasTranscrito.length) {
      if (palabrasReal[currentRealWordIndex].texto == palabrasTranscrito[currentTranscritoWordIndex].texto) {
        comparacion.add(
          ComparacionSegmento(
            segmentoTranscrito: palabrasTranscrito[currentTranscritoWordIndex].segmento,
            palabraReal: palabrasReal[currentRealWordIndex].texto,
            estado: "acierto",
            indexReal: currentRealWordIndex,
            indexTranscrito: currentTranscritoWordIndex,
          ),
        );
        currentRealWordIndex++;
        currentTranscritoWordIndex++;
      } else {
        buffer.add(
          ComparacionSegmento(
            segmentoTranscrito: palabrasTranscrito[currentTranscritoWordIndex].segmento,
            palabraReal: palabrasReal[currentRealWordIndex].texto,
            estado: "sustitucion",
            indexReal: currentRealWordIndex,
            indexTranscrito: currentTranscritoWordIndex,
          ),
        );
        currentRealWordIndex++;
        currentTranscritoWordIndex++;
      }
    } else if (currentRealWordIndex < palabrasReal.length) {
      comparacion.add(
        ComparacionSegmento(
          segmentoTranscrito: Segment(start: 0, end: 0, word: "", probability: 0),
          palabraReal: palabrasReal[currentRealWordIndex].texto,
          estado: "omisión",
          indexReal: currentRealWordIndex,
          indexTranscrito: -1,
        ),
      );
      currentRealWordIndex++;
    } else if (currentTranscritoWordIndex < palabrasTranscrito.length) {
      buffer.add(
        ComparacionSegmento(
          segmentoTranscrito: palabrasTranscrito[currentTranscritoWordIndex].segmento,
          palabraReal: "",
          estado: "inserción",
          indexReal: -1,
          indexTranscrito: currentTranscritoWordIndex,
        ),
      );
      currentTranscritoWordIndex++;
    }
  }
  // Procesar el buffer si hay algo al final
  if (buffer.isNotEmpty) {
    comparacion.add(
      ComparacionGrupo(
        segmentos: buffer,
        estado: "intento_fallido",
        indexRealInicial: buffer.first.indexReal,
        indexRealFinal: buffer.last.indexReal,
        indexTranscritoInicial: buffer.first.indexTranscrito,
        indexTranscritoFinal: buffer.last.indexTranscrito,
      ),
    );
  }
  return comparacion;
}

void _imprimirResultados(List<Segment> textoReal, List<Segment> textoTranscrito, List<Object> comparacionFinal) {
  List<String> palabrasReal = textoReal.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
  List<String> palabrasTranscrito = textoTranscrito.map((segment) => segment.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
  print(comparacionFinal.length);
  for (int i = 0; i < 14 && i < comparacionFinal.length; i++) {
    if (comparacionFinal[i] is ComparacionSegmento) {
      ComparacionSegmento segmento = comparacionFinal[i] as ComparacionSegmento;
      print("palabrasReal[$i]: ${palabrasReal.length > i ? palabrasReal[i] : 'N/A'}");
      print("palabrasTranscrito[$i]: ${palabrasTranscrito.length > i ? palabrasTranscrito[i] : 'N/A'}");
      print("comparacionFinal[$i]: ${segmento.indexReal} ${segmento.estado} ${segmento.indexTranscrito} ${segmento.palabraReal} ${segmento.segmentoTranscrito.word}");
    } else if (comparacionFinal[i] is ComparacionGrupo) {
      ComparacionGrupo grupo = comparacionFinal[i] as ComparacionGrupo;
      print("Grupo de intento fallido:");
      print("  Estado: ${grupo.estado}");
      print("  Índice Real Inicial: ${grupo.indexRealInicial}");
      print("  Índice Real Final: ${grupo.indexRealFinal}");
      print("  Índice Transcrito Inicial: ${grupo.indexTranscritoInicial}");
      print("  Índice Transcrito Final: ${grupo.indexTranscritoFinal}");
      for (var segmento in grupo.segmentos) {
        print("    - ${segmento.estado}: ${segmento.palabraReal} -> ${segmento.segmentoTranscrito.word}");
      }
    }
  }
}
