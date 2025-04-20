import 'dart:math';
import 'package:transcriber_whisper/models/patience_diff_js.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:collection/collection.dart';

class Transcription {
  // Segmentos de la transcription del audio
  List<Segment> audioTranscriptionSegments = [];
  // Segmentos del texto de referencia (original)
  List<Segment> referenceTextOnlyWordsSegments = [];
  // Segmentos que representan la alineación entre la transcripción y el texto de referencia
  List<Segment> wordAlignmentSegments = [];
  // Segmentos de wordAlignmentSegments anadiendole la puntuacion que extraimos del texto de referecia
  List<Segment> wordAlignmentSegmentsWithPunctuation = [];
  // Texto de referencia (original) completo
  String? referenceText;
  // Palabras de la transcripción del audio
  List<String> audioTranscriptionWords = [];
  // Palabras del texto de referencia (original)
  List<String> referenceTextWords = [];
  // Segmentos del texto de referencia (original) sin procesar (incluye puntuación)
  List<Segment> referenceTextRawSegments = [];
  // Segmentos de puntuación del texto de referencia (original)
  List<Segment> referenceTextPunctuationSegments = [];

  int countReferenceWords = 0;
  int countTranscriptionWords = 0;
  int countDiffInsertions = 0;
  int countDiffDeletions = 0;
  int countDiffMatches = 0;

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
    //print("referenceText --> $referenceText");
    this.referenceText = referenceText;

    ////////// Trabaja con la transcripción alineada de whisper, crea segmentos de las palabras desnudas
    if (generateAudioTranscriptionSegments) {
      for (Map<String, dynamic> map in listMap) {
        double start = map.containsKey('start') && map['start'] is double ? map['start'] : 0.0;
        double end = map.containsKey('end') && map['end'] is double ? map['end'] : 0.0;
        String text = map.containsKey('word') && map['word'] is String ? map['word'] : "";
        double probability = map.containsKey('probability') && map['probability'] is double ? map['probability'] : 1.0;

        // Dividir el texto del json del whisper alineado en palabras, eliminando la puntuación
        List<String> words = text.split(RegExp(r'\s+')); // Dividir por espacios en blanco
        for (String word in words) {
          String cleanedWord = word.replaceAll(RegExp(r'[.,:;!¡?¿]'), '').trim().toLowerCase(); // Eliminar puntuación y convertir a minúsculas
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
      //audioTranscriptionSegments.forEach((element) => print(element),);
      audioTranscriptionWords = audioTranscriptionWords.map((e) => e.toLowerCase().trim()).toList();
      audioTranscriptionWords = audioTranscriptionWords.where((element) => element.isNotEmpty).toList();

      // cuenta el numero total de palabras en la transcripcion
      countTranscriptionWords = audioTranscriptionWords.length;
    }

    ////////// Trabaja con el texto de referencia,
    // crea segmentos de cada elemento del texto de referencia (referenceTextRawSegments)
    // y segmentos solo de las palabras del texto de referencia (referenceTextOnlyWordsSegments)
    if (generateReferenceTextSegments && referenceText != null) {
      referenceTextRawSegments = formattedReferenceTextToSegments(referenceText);
      //referenceTextRawSegments.forEach((e) => print("rawReferenceTextSegments yyy: $e"));
      referenceTextOnlyWordsSegments = [];
      int referenceOrder = 0;
      for (int i = 0; i < referenceTextRawSegments.length; i++) {
        Segment segment = referenceTextRawSegments[i];
        if (!segment.isPunctuation) {
          referenceTextOnlyWordsSegments.add(segment.copyWith(realOrder: referenceOrder));
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
      // cuenta el numero total de palabras en el texto de referencia
      countReferenceWords = referenceTextOnlyWordsSegments.length;

      // Crear la lista de signos de puntuacion
      referenceTextPunctuationSegments = referenceTextRawSegments.where((element) => element.isPunctuation == true).toList();
    }

    // Crea Segmentos para que el texto de referencia tenga los datos del alineneamirnto de la transcripcion
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
    List<Segment>? referenceTextOnlyWordsSegments,
    List<Segment>? wordAlignmentSegments,
    List<Segment>? wordAlignmentSegmentsWithPunctuation,
    String? referenceText,
    List<String>? audioTranscriptionWords,
    List<String>? referenceTextWords,
    List<Segment>? referenceTextRawSegments,
    List<Segment>? referenceTextPunctuationSegments,
    bool? shouldInsertPunctuation,
    int? countReferenceWords,
    int? countTranscriptionWords,
    int? countDiffInsertions,
    int? countDiffDeletions,
    int? countDiffMatches,
  }) {
    return Transcription()
      ..audioTranscriptionSegments = audioTranscriptionSegments ?? this.audioTranscriptionSegments
      ..referenceTextOnlyWordsSegments = referenceTextOnlyWordsSegments ?? this.referenceTextOnlyWordsSegments
      ..wordAlignmentSegments = wordAlignmentSegments ?? this.wordAlignmentSegments
      ..wordAlignmentSegmentsWithPunctuation = wordAlignmentSegmentsWithPunctuation ?? List.from(this.wordAlignmentSegmentsWithPunctuation)
      ..referenceText = referenceText ?? this.referenceText
      ..audioTranscriptionWords = audioTranscriptionWords ?? this.audioTranscriptionWords
      ..referenceTextWords = referenceTextWords ?? this.referenceTextWords
      .._referenceSegmentsByWord = Map.from(_referenceSegmentsByWord) // Crear una nueva instancia del mapa
      .._referenceSegmentsByIndex = Map.from(_referenceSegmentsByIndex) // Crear una nueva instancia del mapa
      .._wordAlignmentSegmentsByAudioTranscriptionWord = Map.from(_wordAlignmentSegmentsByAudioTranscriptionWord) // Crear una nueva instancia del mapa
      .._wordAlignmentSegmentsByAudioTranscriptionIndex = Map.from(_wordAlignmentSegmentsByAudioTranscriptionIndex) // Crear una nueva instancia del mapa
      ..referenceTextRawSegments = referenceTextRawSegments ?? this.referenceTextRawSegments
      ..referenceTextPunctuationSegments = referenceTextPunctuationSegments ?? this.referenceTextPunctuationSegments
      ..shouldInsertPunctuation = shouldInsertPunctuation ?? this.shouldInsertPunctuation
      ..countReferenceWords = countReferenceWords ?? this.countReferenceWords
      ..countTranscriptionWords = countTranscriptionWords ?? this.countTranscriptionWords
      ..countDiffInsertions = countDiffInsertions ?? this.countDiffInsertions
      ..countDiffDeletions = countDiffDeletions ?? this.countDiffDeletions
      ..countDiffMatches = countDiffMatches ?? this.countDiffMatches;
  }

  List<Segment> formattedReferenceTextToSegments(String text) {
    //print("createRawReferenceTextSegments param text: $text");
    print("createRawReferenceTextSegments - Inicio");
    List<Segment> segments = [];
    int rawRealOrder = 0;
    int start = 0;
    // Expresión regular para separar palabras, puntuación y salto de linea teniendo en cuenta las tildes etc
    RegExp regExp = RegExp(r"([\wáéíóúüñÁÉÍÓÚÜÑ]+|[.,:;!¡?¿—]|\n)");
    Iterable<Match> matches = regExp.allMatches(text);

    // Creamos un segmento por cada elemento
    for (Match match in matches) {
      String word = match.group(0)!;
      int end = match.end;

      // Comprueba si la palabra actual es un signo de puntuación o salto de línea.
      bool isPunctuation = [".", ",", ":", ";", "!", "¡", "?", "¿", "—"].contains(word) || word == "\n";

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
    //segments.forEach((e)=>print("ppppppppppppppppppp::: ${e.word}"));
    print("createRawReferenceTextSegments - Fin");
    return segments;
  }

  // Crea Segmentos que son la comparacion entre el texto de referencia y la transcripcion
  void associateWords() {
    print("associateWords - Inicio");
    wordAlignmentSegments.clear(); // Limpiar la lista antes de empezar

    // Inicializar los contadores
    countDiffInsertions = 0;
    countDiffDeletions = 0;
    countDiffMatches = 0;

    // Crear listas de palabras para el algoritmo diff, convirtiendo a minúsculas
    List<String> referenceWords = referenceTextOnlyWordsSegments.map((s) => s.word.toLowerCase()).toList();
    List<String> transcriptionWords = audioTranscriptionWords;// audioTranscriptionSegments.map((s) => s.word.toLowerCase()).toList();
    //audioTranscriptionSegments.forEach((element) => print("audioTranscriptionSegments words -> ${element.word}"));
    //referenceTextOnlyWordsSegments.forEach((element) => print("referenceTextSegments words -> ${element.word}"));

    // Calcular las diferencias usando PatienceDiffJs
    PatienceDiffJs diff = PatienceDiffJs(referenceWords, transcriptionWords, false);
    Map<String, dynamic> diffResult = diff.patienceDiffJs();
    // Imprimir el resultado del diff
    //print("Resultado del diff: $diffResult");

    // Procesar los cambios (inserciones, eliminaciones y coincidencias)
    List<Map<String, dynamic>> lines = diffResult['lines'];

    // aIndex en este caso hace alucion a la lista de las palabras del texto de referencia
    // bIndex a la lista de palabras de la transcripcion
    for (Map<String, dynamic> line in lines) {
      int aIndex = line['aIndex'];
      int bIndex = line['bIndex'];

      if (aIndex >= 0 && bIndex >= 0) {
        // Coincidencia
        countDiffMatches++; // Incrementar el contador de coincidencias
        Segment referenceSegment = referenceTextOnlyWordsSegments[aIndex];
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
        referenceTextOnlyWordsSegments[aIndex] = referenceSegment.copyWith(
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
        countDiffDeletions++; // Incrementar el contador de eliminaciones
        Segment deletedSegment = referenceTextOnlyWordsSegments[aIndex];
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
        if (aIndex < referenceTextOnlyWordsSegments.length - 1) {
          newSegment = newSegment.copyWith(realWordAfterIndex: aIndex + 1);
        }
        wordAlignmentSegments.add(newSegment);
        referenceTextOnlyWordsSegments[aIndex] = deletedSegment.copyWith(
          associationType: AssociationType.deleted,
          realIndex: aIndex,
          transcribedIndex: null,
          realOrder: aIndex,
          transcribedOrder: null,
        );
        //print("associateWords - Palabra eliminada en el texto de referencia: ${deletedSegment.word} (índice: ${deletedSegment.realIndex})");
      } else if (aIndex < 0 && bIndex >= 0) {
        // Inserción
        countDiffInsertions++; // Incrementar el contador de inserciones
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
    // Crear una copia de wordAlignmentSegments
    List<Segment> newSegments = List.from(wordAlignmentSegments);

    // Si no hay segmentos en newSegments, se inserta el segmento
    if (newSegments.isEmpty) {
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
        newSegments.add(newPunctuationSegment);
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
        if (punctuationSegment.word == "\n") {
          // Es un salto de párrafo
          // Buscar el segmento asociado anterior
          Segment? previousAssociatedSegment;
          for (int i = punctuationSegment.rawRealOrder! - 1; i >= 0; i--) {
            previousAssociatedSegment = newSegments.lastWhereOrNull((element) => element.rawRealOrder == i);
            if (previousAssociatedSegment != null) {
              break;
            }
          }
          // Buscar el segmento asociado posterior
          Segment? nextAssociatedSegment;
          for (int i = punctuationSegment.rawRealOrder! + 1; i < referenceTextOnlyWordsSegments.length; i++) {
            nextAssociatedSegment = newSegments.firstWhereOrNull((element) => element.rawRealOrder == i);
            if (nextAssociatedSegment != null) {
              break;
            }
          }
          // Calcular la posición de inserción
          if (previousAssociatedSegment != null) {
            insertIndex = newSegments.indexOf(previousAssociatedSegment) + 1;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: previousAssociatedSegment.end, end: previousAssociatedSegment.end);
          } else if (nextAssociatedSegment != null) {
            insertIndex = newSegments.indexOf(nextAssociatedSegment);
            newPunctuationSegment = newPunctuationSegment.copyWith(start: nextAssociatedSegment.start, end: nextAssociatedSegment.start);
          } else {
            insertIndex = newSegments.length;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: newSegments.last.end, end: newSegments.last.end);
          }
        } else {
          // No es un salto de párrafo, mantener la lógica anterior
          // Buscar el segmento asociado en newSegments
          Segment? associatedSegment = newSegments.lastWhereOrNull((element) => element.rawRealOrder == punctuationSegment.rawRealOrder! - 1);
          if (associatedSegment != null) {
            insertIndex = newSegments.indexOf(associatedSegment) + 1;
            newPunctuationSegment = newPunctuationSegment.copyWith(start: associatedSegment.end, end: associatedSegment.end);
          } else {
            // Si no hay segmento asociado, insertar al principio o al final
            if (punctuationSegment.rawRealOrder! < newSegments.first.rawRealOrder!) {
              insertIndex = 0;
              newPunctuationSegment = newPunctuationSegment.copyWith(start: newSegments.first.start, end: newSegments.first.start);
            } else {
              insertIndex = newSegments.length;
              newPunctuationSegment = newPunctuationSegment.copyWith(start: newSegments.last.end, end: newSegments.last.end);
            }
          }
        }
        // Insertar en la posición correcta
        newSegments.insert(insertIndex, newPunctuationSegment);
      }
    }
    // Reemplazar wordAlignmentSegmentsWithPunctuation con newSegments
    wordAlignmentSegmentsWithPunctuation.clear();
    wordAlignmentSegmentsWithPunctuation.addAll(newSegments);
    //wordAlignmentSegmentsWithPunctuation.forEach((element) => print("wordAlignmentSegmentsWithPunctuation elementos word: ${element.word}"),);
    print("_insertPunctuation - Fin");
  }
}
