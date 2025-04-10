import 'dart:math';
import 'package:transcriber_whisper/models/patience_diff_js.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:collection/collection.dart';

class Transcription {
  // Segmentos de la transcription del audio
  List<Segment> audioTranscriptionSegments = [];
  // Segmentos del texto de referencia (original)
  List<Segment> referenceTextSegments = [];
  // Segmentos que representan la alineación entre la transcripción y el texto de referencia
  List<Segment> wordAlignmentSegments = [];
  // Texto de referencia (original) completo
  String? referenceText;
  // Palabras de la transcripción del audio
  List<String> audioTranscriptionWords = [];
  // Palabras del texto de referencia (original)
  List<String> referenceTextWords = [];
  // Segmentos del texto de referencia (original) sin procesar (incluye puntuación)
  List<Segment> rawReferenceTextSegments = [];
  // Segmentos de puntuación del texto de referencia (original)
  List<Segment> referenceTextPunctuationSegments = [];

  // Mapas para indexar segmentos
  // Segmentos del texto de referencia (original) indexados por palabra
  Map<String, List<Segment>> _referenceSegmentsByWord = {};
  // Segmentos del texto de referencia (original) indexados por índice
  Map<int, Segment> _referenceSegmentsByIndex = {};
  // Segmentos de alineación indexados por palabra de la transcripción
  Map<String, List<Segment>> _wordAlignmentSegmentsByAudioTranscriptionWord = {};
  // Segmentos de alineación indexados por índice de la transcripción
  Map<int, Segment> _wordAlignmentSegmentsByAudioTranscriptionIndex = {};
  // Indica si se debe insertar la puntuación en la lista de segmentos asociados
  bool shouldInsertPunctuation = false;

  // Constructor sin nombre (por defecto)
  Transcription();

  Transcription.fromListMap({
    required List<Map<String, dynamic>> listMap,
    bool generateAudioTranscriptionSegments = true,
    bool generateReferenceTextSegments = true,
    bool generateWordAlignmentSegments = true,
    bool generateRawReferenceTextSegments = true,
    String? referenceText,
    this.shouldInsertPunctuation = false, // Nuevo parámetro
  }) {
    //print("listMap --> $listMap");
    this.referenceText = referenceText;
    if (generateAudioTranscriptionSegments) {
      for (Map<String, dynamic> map in listMap) {
        double start = map.containsKey('start') && map['start'] is double ? map['start'] : 0.0;
        double end = map.containsKey('end') && map['end'] is double ? map['end'] : 0.0;
        String text = map.containsKey('word') && map['word'] is String ? map['word'] : "";
        double probability = map.containsKey('probability') && map['probability'] is double ? map['probability'] : 1.0;
        // Dividir el texto en palabras, eliminando la puntuación
        List<String> words = text.split(RegExp(r'\s+')); // Dividir por espacios en blanco
        for (String word in words) {
          String cleanedWord = word.replaceAll(RegExp(r'[.,:;!?]'), '').trim().toLowerCase(); // Eliminar puntuación y convertir a minúsculas
          if (cleanedWord.isNotEmpty) {
            audioTranscriptionSegments.add(
              Segment(
                start: start,
                end: end,
                word: cleanedWord,
                probability: probability,
                transcribedOrder: audioTranscriptionSegments.length,
                associationType: AssociationType.none,
              ),
            );
            audioTranscriptionWords.add(cleanedWord);
          }
        }
      }
      audioTranscriptionWords = audioTranscriptionWords.map((e) => e.toLowerCase().trim()).toList();
      audioTranscriptionWords = audioTranscriptionWords.where((element) => element.isNotEmpty).toList();
    }
    if (generateReferenceTextSegments && referenceText != null) {
      rawReferenceTextSegments = createRawReferenceTextSegments(referenceText);
      referenceTextSegments = [];
      int referenceOrder = 0;
      for (int i = 0; i < rawReferenceTextSegments.length; i++) {
        Segment segment = rawReferenceTextSegments[i];
        if (!segment.isPunctuation) {
          referenceTextSegments.add(segment.copyWith(realOrder: referenceOrder));
          // Poblar el mapa
          if (!_referenceSegmentsByWord.containsKey(segment.word)) {
            _referenceSegmentsByWord[segment.word] = [];
          }
          _referenceSegmentsByWord[segment.word]!.add(segment);
          // Poblar el mapa por indice
          _referenceSegmentsByIndex[referenceOrder] = segment;
          referenceOrder++;
        }
      }
      // Crear la lista de signos de puntuacion
      referenceTextPunctuationSegments = rawReferenceTextSegments.where((element) => element.isPunctuation == true).toList();
    }
    if (generateWordAlignmentSegments) {
      wordAlignmentSegments = [];
      associateWords();
      if (shouldInsertPunctuation) {
        _insertPunctuation();
      }
    }
  }

  Transcription copyWith({
    List<Segment>? audioTranscriptionSegments,
    List<Segment>? referenceTextSegments,
    List<Segment>? wordAlignmentSegments,
    String? referenceText,
    List<String>? audioTranscriptionWords,
    List<String>? referenceTextWords,
    List<Segment>? rawReferenceTextSegments,
    List<Segment>? referenceTextPunctuationSegments,
    bool? shouldInsertPunctuation,
  }) {
    return Transcription()
      ..audioTranscriptionSegments = audioTranscriptionSegments ?? this.audioTranscriptionSegments
      ..referenceTextSegments = referenceTextSegments ?? this.referenceTextSegments
      ..wordAlignmentSegments = wordAlignmentSegments ?? this.wordAlignmentSegments
      ..referenceText = referenceText ?? this.referenceText
      ..audioTranscriptionWords = audioTranscriptionWords ?? this.audioTranscriptionWords
      ..referenceTextWords = referenceTextWords ?? this.referenceTextWords
      .._referenceSegmentsByWord = Map.from(_referenceSegmentsByWord) // Crear una nueva instancia del mapa
      .._referenceSegmentsByIndex = Map.from(_referenceSegmentsByIndex) // Crear una nueva instancia del mapa
      .._wordAlignmentSegmentsByAudioTranscriptionWord = Map.from(_wordAlignmentSegmentsByAudioTranscriptionWord) // Crear una nueva instancia del mapa
      .._wordAlignmentSegmentsByAudioTranscriptionIndex = Map.from(_wordAlignmentSegmentsByAudioTranscriptionIndex) // Crear una nueva instancia del mapa
      ..rawReferenceTextSegments = rawReferenceTextSegments ?? this.rawReferenceTextSegments
      ..referenceTextPunctuationSegments = referenceTextPunctuationSegments ?? this.referenceTextPunctuationSegments
      ..shouldInsertPunctuation = shouldInsertPunctuation ?? this.shouldInsertPunctuation;
  }

  List<Segment> createRawReferenceTextSegments(String text) {
    print("createRawReferenceTextSegments - Inicio");
    List<Segment> segments = [];
    int rawRealOrder = 0;
    int start = 0;
    // Expresión regular para separar palabras y puntuación, incluyendo el guion "—"
    RegExp regExp = RegExp(r"(\w+|[.,:;!?—]|\n\n)"); // Añadido "—" a la expresión regular
    Iterable<Match> matches = regExp.allMatches(text);

    for (Match match in matches) {
      String word = match.group(0)!;
      int end = match.end;
      // Añadido "—" a la lista de caracteres de puntuación
      bool isPunctuation = [".", ",", ":", ";", "!", "?", "—"].contains(word) || word == "\n\n";

      Segment segment = Segment(
        start: start.toDouble(),
        end: end.toDouble(),
        word: word,
        probability: 1.0,
        realOrder: null,
        rawRealOrder: rawRealOrder,
        associationType: AssociationType.none,
        isPunctuation: isPunctuation,
      );
      segments.add(segment);
      rawRealOrder++;
      start = end;
    }
    print("createRawReferenceTextSegments - Fin");
    return segments;
  }

  void printWordAlignmentSegmentsInfo() {
    var aa = referenceTextSegments
        .asMap()
        .entries
        .map((entry) {
          int index = entry.key;
          Segment segment = entry.value;
          return "$index. ${segment.word}";
        })
        .join(" ");
    print("referenceTextSegments con indices: $aa");
    var bb = audioTranscriptionSegments
        .asMap()
        .entries
        .map((entry) {
          int index = entry.key;
          Segment segment = entry.value;
          return "$index. ${segment.word}";
        })
        .join(" ");
    print("audioTranscriptionSegments con indices: $bb");
    print("Información de Segmentos Alineados:");
    print("----------------------------------");
    for (int i = 0; i < wordAlignmentSegments.length; i++) {
      Segment segment = wordAlignmentSegments[i];
      print("Segmento numero: ${i + 1}");
      print("Palabra de Referencia: ${segment.realIndex} --> ${segment.realWord}");
      print("Palabra de la Transcripción: ${segment.transcribedIndex} --> ${segment.word}");
      print("Tipo de Alineación: ${segment.associationType == AssociationType.similar ? 'similar' : segment.associationType}");
      print("Distancia Levenshtein: ${segment.levenshteinDistance}");
      print("Probabilidad: ${segment.probability}");
      print("Inicio: ${segment.start}, Fin: ${segment.end}");
      print("  Palabras de la Transcripción Asociadas: ${segment.transcribedWords.join(", ")}");
      print("  Probabilidades Asociadas: ${segment.transcribedWordsProbabilities.join(", ")}");
      print("  rawReferenceOrder: ${segment.rawRealOrder}");
      if (segment.associationType == AssociationType.inserted) {
        if (segment.realWordBeforeIndex != null && segment.realWordAfterIndex != null) {
          print("  Posiciónen el texto de referencia: Entre ${segment.realWordBeforeIndex} y ${segment.realWordAfterIndex}");
        } else if (segment.realWordBeforeIndex != null) {
          print("  Posiciónen el texto de referencia: Después de ${segment.realWordBeforeIndex}");
        } else if (segment.realWordAfterIndex != null) {
          print("  Posiciónen el texto de referencia: Antes de ${segment.realWordAfterIndex}");
        } else {
          print("  Posiciónen el texto de referencia: Al final");
        }
      }
      if (segment.associationType == AssociationType.deleted) {
        print("  Posición en el audio: Entre ${segment.realWordBeforeEnd} y ${segment.realWordAfterStart}");
      }
      print("----------------------------------");
    }
  }

  void associateWords() {
    print("associateWords - Inicio");
    wordAlignmentSegments.clear(); // Limpiar la lista antes de empezar

    // Crear listas de palabras para el algoritmo diff, convirtiendo a minúsculas
    List<String> referenceWords = referenceTextSegments.map((s) => s.word.toLowerCase()).toList();
    List<String> transcriptionWords = audioTranscriptionSegments.map((s) => s.word.toLowerCase()).toList();

    // Imprimir los strings que se pasan a Diff
    //print("referenceWords: $referenceWords");
    //print("transcriptionWords: $transcriptionWords");

    // Calcular las diferencias usando PatienceDiffJs
    PatienceDiffJs diff = PatienceDiffJs(referenceWords, transcriptionWords, false);
    Map<String, dynamic> diffResult = diff.patienceDiffJs();
    // Imprimir el resultado del diff
    //print("Resultado del diff: $diffResult");

    // Procesar los cambios (inserciones, eliminaciones y coincidencias)
    List<Map<String, dynamic>> lines = diffResult['lines'];
    // Imprimir las lineas del diff
    //print("Lineas del diff: $lines");
    for (Map<String, dynamic> line in lines) {
      int aIndex = line['aIndex'];
      int bIndex = line['bIndex'];

      if (aIndex >= 0 && bIndex >= 0) {
        // Coincidencia
        Segment referenceSegment = referenceTextSegments[aIndex];
        Segment transcriptionSegment = audioTranscriptionSegments[bIndex];

        Segment newSegment = Segment(
          start: transcriptionSegment.start,
          end: transcriptionSegment.end,
          word: transcriptionSegment.word,
          probability: transcriptionSegment.probability,
          realWord: referenceSegment.word,
          transcribedWords: [transcriptionSegment.word],
          transcribedWordsProbabilities: [transcriptionSegment.probability],
          associationType: AssociationType.coincidence,
          levenshteinDistance: 0,
          realIndex: aIndex,
          transcribedIndex: bIndex,
          transcribedOrder: bIndex,
          realOrder: aIndex,
          rawRealOrder: referenceSegment.rawRealOrder,
        );
        wordAlignmentSegments.add(newSegment);
        referenceTextSegments[aIndex] = referenceSegment.copyWith(
          associationType: AssociationType.coincidence,
          realIndex: aIndex,
          transcribedIndex: bIndex,
          realOrder: aIndex,
          transcribedOrder: bIndex,
        );
        audioTranscriptionSegments[bIndex] = transcriptionSegment.copyWith(
          associationType: AssociationType.coincidence,
          realIndex: aIndex,
          transcribedIndex: bIndex,
          realOrder: aIndex,
          transcribedOrder: bIndex,
        );
        //print("associateWords - Palabra asociada por coincidencia exacta: ${referenceSegment.word} (índice ref: $aIndex, índice trans: $bIndex)");
      } else if (aIndex >= 0 && bIndex < 0) {
        // Eliminación
        Segment deletedSegment = referenceTextSegments[aIndex];
        Segment newSegment = Segment(
          start: 0.0, // Valor por defecto
          end: 0.0, // Valor por defecto
          word: deletedSegment.word,
          probability: 1.0, // Valor por defecto
          realWord: deletedSegment.word,
          transcribedWords: [],
          transcribedWordsProbabilities: [],
          associationType: AssociationType.deleted,
          levenshteinDistance: 0,
          realIndex: aIndex,
          transcribedIndex: null,
          transcribedOrder: null,
          realOrder: aIndex,
          rawRealOrder: deletedSegment.rawRealOrder,
        );
        if (aIndex > 0) {
          newSegment = newSegment.copyWith(realWordBeforeIndex: aIndex - 1);
        }
        if (aIndex < referenceTextSegments.length - 1) {
          newSegment = newSegment.copyWith(realWordAfterIndex: aIndex + 1);
        }
        wordAlignmentSegments.add(newSegment);
        referenceTextSegments[aIndex] = deletedSegment.copyWith(
          associationType: AssociationType.deleted,
          realIndex: aIndex,
          transcribedIndex: null,
          realOrder: aIndex,
          transcribedOrder: null,
        );
        //print("associateWords - Palabra eliminada en el texto de referencia: ${deletedSegment.word} (índice: ${deletedSegment.realIndex})");
      } else if (aIndex < 0 && bIndex >= 0) {
        // Inserción
        Segment insertedSegment = audioTranscriptionSegments[bIndex];
        Segment newSegment = Segment(
          start: insertedSegment.start,
          end: insertedSegment.end,
          word: insertedSegment.word,
          probability: insertedSegment.probability,
          realWord: null,
          transcribedWords: [insertedSegment.word],
          transcribedWordsProbabilities: [insertedSegment.probability],
          associationType: AssociationType.inserted,
          levenshteinDistance: 0,
          realIndex: null,
          transcribedIndex: bIndex,
          transcribedOrder: bIndex,
          realOrder: null,
          rawRealOrder: null,
        );
        if (bIndex > 0) {
          newSegment = newSegment.copyWith(realWordBeforeEnd: audioTranscriptionSegments[bIndex - 1].end);
        }
        if (bIndex < audioTranscriptionSegments.length - 1) {
          newSegment = newSegment.copyWith(realWordAfterStart: audioTranscriptionSegments[bIndex + 1].start);
        }
        wordAlignmentSegments.add(newSegment);
        audioTranscriptionSegments[bIndex] = insertedSegment.copyWith(
          associationType: AssociationType.inserted,
          realIndex: null,
          transcribedIndex: bIndex,
          realOrder: null,
          transcribedOrder: bIndex,
        );
        //print("associateWords - Palabra insertada en la transcripción: ${insertedSegment.word} (índice: ${insertedSegment.transcribedIndex})");
      }
    }
    print("associateWords - Fin");
  }

  void _insertPunctuation() {
    print("_insertPunctuation - Inicio");
    List<Segment> newSegments = [];
    // Si no hay segmentos en wordAlignmentSegments, se inserta el segmento
    if (wordAlignmentSegments.isEmpty) {
      for (Segment punctuationSegment in referenceTextPunctuationSegments) {
        // Crear el segmento de auto-asociación
        Segment newPunctuationSegment = Segment(
          start: 0.0, // Valor por defecto
          end: 0.0, // Valor por defecto
          word: punctuationSegment.word, // La palabra es el signo de puntuación
          probability: 1.0, // Probabilidad alta por ser auto-asociación
          realWord: punctuationSegment.word, // La palabra real es el signo de puntuación
          transcribedWords: [], // No hay palabras transcritas asociadas
          transcribedWordsProbabilities: [], // No hay probabilidades asociadas
          associationType: AssociationType.punctuation, // Tipo de asociación: Puntuación
          levenshteinDistance: 0, // Distancia de Levenshtein: 0
          realIndex: null, // No hay índice real
          transcribedIndex: null, // No hay índice transcrito
          transcribedOrder: null, // Asignar transcribedOrder
          realOrder: null, // Orden real
          isPunctuation: true, // Es un signo de puntuación
          rawRealOrder: punctuationSegment.rawRealOrder,
        );
        wordAlignmentSegments.add(newPunctuationSegment);
      }
    } else {
      for (Segment punctuationSegment in referenceTextPunctuationSegments) {
        // Crear el segmento de auto-asociación
        Segment newPunctuationSegment = Segment(
          start: 0.0, // Valor por defecto
          end: 0.0, // Valor por defecto
          word: punctuationSegment.word, // La palabra es el signo de puntuación
          probability: 1.0, // Probabilidad alta por ser auto-asociación
          realWord: punctuationSegment.word, // La palabra real es el signo de puntuación
          transcribedWords: [], // No hay palabras transcritas asociadas
          transcribedWordsProbabilities: [], // No hay probabilidades asociadas
          associationType: AssociationType.punctuation, // Tipo de asociación: Puntuación
          levenshteinDistance: 0, // Distancia de Levenshtein: 0
          realIndex: null, // No hay índice real
          transcribedIndex: null, // No hay índice transcrito
          transcribedOrder: null, // Asignar transcribedOrder
          realOrder: null, // Orden real
          isPunctuation: true, // Es un signo de puntuación
          rawRealOrder: punctuationSegment.rawRealOrder,
        );
        // Insertar el segmento en la posición correcta
        int insertIndex = 0;
        if (punctuationSegment.word == "\n\n") {
          // Es un salto de párrafo
          // Buscar el segmento asociado anterior
          Segment? previousAssociatedSegment;
          for (int i = punctuationSegment.rawRealOrder! - 1; i >= 0; i--) {
            previousAssociatedSegment = wordAlignmentSegments.lastWhereOrNull((element) => element.rawRealOrder == i);
            if (previousAssociatedSegment != null) {
              break;
            }
          }
          // Buscar el segmento asociado posterior
          Segment? nextAssociatedSegment;
          for (int i = punctuationSegment.rawRealOrder! + 1; i < referenceTextSegments.length; i++) {
            nextAssociatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.rawRealOrder == i);
            if (nextAssociatedSegment != null) {
              break;
            }
          }
          // Calcular la posición de inserción
          if (previousAssociatedSegment != null) {
            insertIndex = wordAlignmentSegments.indexOf(previousAssociatedSegment) + 1;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: previousAssociatedSegment.end, end: previousAssociatedSegment.end);
          } else if (nextAssociatedSegment != null) {
            insertIndex = wordAlignmentSegments.indexOf(nextAssociatedSegment);
            newPunctuationSegment = newPunctuationSegment.copyWith(start: nextAssociatedSegment.start, end: nextAssociatedSegment.start);
          } else {
            insertIndex = wordAlignmentSegments.length;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: wordAlignmentSegments.last.end, end: wordAlignmentSegments.last.end);
          }
        } else {
          // No es un salto de párrafo, mantener la lógica anterior
          // Buscar el segmento asociado en wordAlignmentSegments
          Segment? associatedSegment = wordAlignmentSegments.lastWhereOrNull((element) => element.rawRealOrder == punctuationSegment.rawRealOrder! - 1);
          if (associatedSegment != null) {
            insertIndex = wordAlignmentSegments.indexOf(associatedSegment) + 1;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: associatedSegment.end, end: associatedSegment.end);
          } else {
            // Si no hay segmento asociado, insertar al principio o al final
            if (punctuationSegment.rawRealOrder! < wordAlignmentSegments.first.rawRealOrder!) {
              insertIndex = 0;
              newPunctuationSegment = newPunctuationSegment.copyWith(start: wordAlignmentSegments.first.start, end: wordAlignmentSegments.first.start);
            } else {
              insertIndex = wordAlignmentSegments.length;
              newPunctuationSegment = newPunctuationSegment.copyWith(start: wordAlignmentSegments.last.end, end: wordAlignmentSegments.last.end);
            }
          }
        }
        // Insertar en la posición correcta
        wordAlignmentSegments.insert(insertIndex, newPunctuationSegment);
      }
    }
    print("_insertPunctuation - Fin");
  }
}

// Función para calcular la distancia de Levenshtein
/*int calculateLevenshteinDistance(String a, String b) {
    if (a.isEmpty) {
      return b.length;
    }
    if (b.isEmpty) {
      return a.length;
    }
    List<int> previousRow = List.generate(b.length + 1, (i) => i);
    for (int i = 0; i < a.length; i++) {
      List<int> currentRow = [i + 1];
      for (int j = 0; j < b.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (a[i] == b[j] ? 0 : 1);
        currentRow.add([insertions, deletions, substitutions].reduce(min));
      }
      previousRow = currentRow;
    }
    return previousRow.last;
  }*/
