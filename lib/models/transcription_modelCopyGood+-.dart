import 'dart:math';
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
    print("listMap --> $listMap");
    this.referenceText = referenceText;
    if (generateAudioTranscriptionSegments) {
      for (Map<String, dynamic> map in listMap) {
        double start = map.containsKey('start') && map['start'] is double ? map['start'] : 0.0;
        double end = map.containsKey('end') && map['end'] is double ? map['end'] : 0.0;
        String text = map.containsKey('word') && map['word'] is String ? map['word'] : "";
        double probability = map.containsKey('probability') && map['probability'] is double ? map['probability'] : 1.0;
        audioTranscriptionSegments.add(
          Segment(start: start, end: end, word: text, probability: probability, transcribedOrder: audioTranscriptionSegments.length, associationType: AssociationType.none),
        );
        audioTranscriptionWords.add(text);
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
    // Expresión regular para separar palabras y puntuación
    RegExp regExp = RegExp(r"(\w+|[.,:;!?]|\n\n)");
    Iterable<Match> matches = regExp.allMatches(text);

    for (Match match in matches) {
      String word = match.group(0)!;
      int end = match.end;
      bool isPunctuation = [".", ",", ":", ";", "!", "?"].contains(word) || word == "\n\n";

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

  // Función para calcular la distancia de Levenshtein
  int calculateLevenshteinDistance(String a, String b) {
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
  }

  List<String> _getUnassociatedReferenceWords() {
    List<String> unassociatedWords = [];
    // Recorrer los segmentos de referencia
    for (Segment referenceSegment in referenceTextSegments) {
      // Verificar si el segmento ya está asociado
      bool isAssociated = false;
      isAssociated = wordAlignmentSegments.any((alignedSegment) => alignedSegment.rawRealOrder == referenceSegment.rawRealOrder);
      // Si no está asociado, añadir la palabra a la lista
      if (!isAssociated) {
        unassociatedWords.add(referenceSegment.word);
      }
    }
    return unassociatedWords;
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
      print("Tipo de Alineación: ${segment.associationType}");
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
    // Asociar las palabras
    _associateWords();

    // Contar palabras no asociadas
    List<String> unassociatedWords = _getUnassociatedReferenceWords();
    int unassociatedWordCount = unassociatedWords.length;
    print("associateWords - Palabras no asociadas en el texto de referencia antes de addUnassociatedInsertions(): $unassociatedWordCount");
    print("associateWords - Lista de palabras no asociadas en el texto de referencia antes de addUnassociatedInsertions(): $unassociatedWords");
    // Añadir las inserciones no asociadas
    addUnassociatedInsertions();
    print("associateWords - Fin");
  }

  void _associateWords() {
    print("_associateWords - Inicio");
    // Inicializar transcribedOrder
    int transcribedOrder = 0;
    for (int i = 0; i < audioTranscriptionSegments.length; i++) {
      audioTranscriptionSegments[i].transcribedOrder = transcribedOrder++;
      audioTranscriptionSegments[i].transcribedIndex = i;
    }
    // Lista para almacenar palabras eliminadas potenciales
    List<Segment> potentialDeletedWords = [];
    // Recorrer las palabras reales
    for (int referenceIndex = 0; referenceIndex < referenceTextSegments.length; referenceIndex++) {
      Segment referenceSegment = referenceTextSegments[referenceIndex];
      // Añadido: Ignorar segmentos de puntuación
      if (referenceSegment.isPunctuation) {
        print("_associateWords - Ignorando segmento de puntuación en texto real: ${referenceSegment.word}");
        continue;
      }
      // Buscar la palabra asociada
      Segment? associatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.realIndex == referenceIndex);
      if (associatedSegment == null) {
        // Buscar coincidencia exacta que no esté asociada
        Segment? exactMatchSegment;
        for (int i = 0; i < audioTranscriptionSegments.length; i++) {
          Segment transcriptionSegment = audioTranscriptionSegments[i];
          if (referenceSegment.word == transcriptionSegment.word) {
            // Comprobar si la palabra ya está asociada
            bool isAssociated = wordAlignmentSegments.any((element) => element.transcribedIndex == transcriptionSegment.transcribedIndex);
            if (!isAssociated) {
              exactMatchSegment = transcriptionSegment;
              break;
            }
          }
        }
        if (exactMatchSegment != null) {
          // Crear un nuevo segmento para la palabra asociada
          Segment newAssociatedSegment = Segment(
            start: exactMatchSegment.start,
            end: exactMatchSegment.end,
            word: exactMatchSegment.word,
            probability: exactMatchSegment.probability,
            realWord: referenceSegment.word,
            transcribedWords: [exactMatchSegment.word],
            transcribedWordsProbabilities: [exactMatchSegment.probability],
            associationType: AssociationType.coincidence,
            levenshteinDistance: 0,
            realIndex: referenceIndex,
            transcribedIndex: exactMatchSegment.transcribedIndex,
            transcribedOrder: exactMatchSegment.transcribedOrder,
            realOrder: referenceIndex,
            rawRealOrder: referenceSegment.rawRealOrder,
          );
          // Añadir el segmento a la lista de segmentos asociados
          _createAndAddWordAlignmentSegment(newAssociatedSegment, referenceIndex, exactMatchSegment.transcribedIndex);
        } else {
          // Buscar la palabra más parecida en la transcripción
          Segment? closestSegment;
          int minDistance = 1000;
          for (int i = 0; i < audioTranscriptionSegments.length; i++) {
            Segment transcriptionSegment = audioTranscriptionSegments[i];
            int distance = calculateLevenshteinDistance(referenceSegment.word.toLowerCase(), transcriptionSegment.word.toLowerCase());
            if (distance < minDistance && distance < 8) {
              minDistance = distance;
              closestSegment = transcriptionSegment;
            }
          }
          if (closestSegment != null) {
            // Crear un nuevo segmento para la palabra asociada
            Segment newAssociatedSegment = Segment(
              start: closestSegment.start,
              end: closestSegment.end,
              word: closestSegment.word,
              probability: closestSegment.probability,
              realWord: referenceSegment.word,
              transcribedWords: [closestSegment.word],
              transcribedWordsProbabilities: [closestSegment.probability],
              associationType: minDistance == 0 ? AssociationType.coincidence : AssociationType.similar,
              levenshteinDistance: minDistance,
              realIndex: referenceIndex,
              transcribedIndex: closestSegment.transcribedIndex,
              transcribedOrder: closestSegment.transcribedOrder,
              realOrder: referenceIndex,
              rawRealOrder: referenceSegment.rawRealOrder,
            );
            // Añadir el segmento a la lista de segmentos asociados
            _createAndAddWordAlignmentSegment(newAssociatedSegment, referenceIndex, closestSegment.transcribedIndex);
          } else {
            print("_associateWords - No se ha encontrado palabra parecida para: ${referenceSegment.word} en el indice $referenceIndex");
            // Añadir a la lista de palabras eliminadas potenciales
            Segment newDeletedSegment = Segment(
              start: referenceSegment.start,
              end: referenceSegment.end,
              word: referenceSegment.word,
              probability: referenceSegment.probability,
              realWord: referenceSegment.word,
              transcribedWords: [],
              transcribedWordsProbabilities: [],
              associationType: AssociationType.deleted,
              levenshteinDistance: 0,
              realIndex: referenceIndex,
              transcribedIndex: null,
              transcribedOrder: null,
              realOrder: referenceIndex,
              rawRealOrder: referenceSegment.rawRealOrder,
            );
            potentialDeletedWords.add(newDeletedSegment);
          }
        }
      } else {
        print("_associateWords - Ya asociado: ${referenceSegment.word} en el indice $referenceIndex");
      }
    }
    // Buscar inserciones parecidas para las palabras eliminadas potenciales
    for (Segment deletedWord in potentialDeletedWords) {
      // Buscar la palabra más parecida en la transcripción
      Segment? closestSegment;
      int minDistance = 1000;
      // Calcular el rango de búsqueda
      int searchRangeStart = deletedWord.realIndex! - 2;
      int searchRangeEnd = deletedWord.realIndex! + 2;
      if (searchRangeStart < 0) {
        searchRangeStart = 0;
      }
      if (searchRangeEnd > audioTranscriptionSegments.length - 1) {
        searchRangeEnd = audioTranscriptionSegments.length - 1;
      }
      for (int i = searchRangeStart; i <= searchRangeEnd; i++) {
        Segment transcriptionSegment = audioTranscriptionSegments[i];
        // Verificar si la palabra ya está asociada
        bool isAssociated = wordAlignmentSegments.any((element) => element.transcribedIndex == transcriptionSegment.transcribedIndex);
        if (!isAssociated) {
          int distance = calculateLevenshteinDistance(deletedWord.word.toLowerCase(), transcriptionSegment.word.toLowerCase());
          if (distance < minDistance && distance < 8) {
            minDistance = distance;
            closestSegment = transcriptionSegment;
          }
        }
      }
      if (closestSegment != null) {
        print("_associateWords - Se ha encontrado una inserción parecida para la palabra eliminada: ${deletedWord.word} -> ${closestSegment.word}");
        // Crear un nuevo segmento para la palabra asociada
        Segment newAssociatedSegment = Segment(
          start: closestSegment.start,
          end: closestSegment.end,
          word: closestSegment.word,
          probability: closestSegment.probability,
          realWord: deletedWord.word,
          transcribedWords: [closestSegment.word],
          transcribedWordsProbabilities: [closestSegment.probability],
          associationType: AssociationType.similar,
          levenshteinDistance: minDistance,
          realIndex: deletedWord.realIndex,
          transcribedIndex: closestSegment.transcribedIndex,
          transcribedOrder: closestSegment.transcribedOrder,
          realOrder: deletedWord.realIndex,
          rawRealOrder: deletedWord.rawRealOrder,
        );
        // Añadir el segmento a la lista de segmentos asociados
        _createAndAddWordAlignmentSegment(newAssociatedSegment, deletedWord.realIndex, closestSegment.transcribedIndex);
      } else {
        print("_associateWords - No se ha encontrado palabra parecida para la palabra eliminada: ${deletedWord.word}");
      }
    }
    print("_associateWords - Fin");
  }

  void _createAndAddWordAlignmentSegment(Segment newAssociatedSegment, int? referenceIndex, int? audioTranscriptionIndex) {
    // Verificar si la palabra real o la palabra transcrita ya están asociadas
    if (wordAlignmentSegments.any((element) => element.realIndex == referenceIndex || element.transcribedIndex == audioTranscriptionIndex)) {
      if (wordAlignmentSegments.any((element) => element.realIndex == referenceIndex)) {
        print("_createAndAddWordAlignmentSegment - La palabra real ${newAssociatedSegment.realWord} ya está asociada en el indice $referenceIndex. No se asocia");
      }
      if (wordAlignmentSegments.any((element) => element.transcribedIndex == audioTranscriptionIndex)) {
        print(
          "_createAndAddWordAlignmentSegment - La palabra transcrita ${newAssociatedSegment.transcribedWords.first} ya está asociada en el indice $audioTranscriptionIndex. No se asocia",
        );
      }
      return;
    }
    // Añadir el segmento a associatedSegments
    wordAlignmentSegments.add(newAssociatedSegment);
    // Poblar el mapa
    if (newAssociatedSegment.transcribedWords.isNotEmpty) {
      if (!_wordAlignmentSegmentsByAudioTranscriptionWord.containsKey(newAssociatedSegment.transcribedWords.first)) {
        _wordAlignmentSegmentsByAudioTranscriptionWord[newAssociatedSegment.transcribedWords.first] = [];
      }
      _wordAlignmentSegmentsByAudioTranscriptionWord[newAssociatedSegment.transcribedWords.first]!.add(newAssociatedSegment);
    }
    // Poblar el mapa por indice
    if (audioTranscriptionIndex != null) {
      _wordAlignmentSegmentsByAudioTranscriptionIndex[audioTranscriptionIndex] = newAssociatedSegment;
    }
  }

  /*void _insertPunctuation() {
    print("_insertPunctuation - Inicio");
    List<Segment> newSegments = [];
    for (Segment punctuationSegment in referenceTextPunctuationSegments) {
      // Buscar el segmento asociado en wordAlignmentSegments
      Segment? associatedSegment = wordAlignmentSegments.firstWhereOrNull(
              (element) => element.rawRealOrder == punctuationSegment.rawRealOrder! - 1);
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
      newSegments.add(newPunctuationSegment);
    }
    // Insertar los nuevos segmentos en la posición correcta
    for (Segment newSegment in newSegments) {
      // Buscar el segmento asociado anterior
      Segment? previousAssociatedSegment;
      for (int i = newSegment.rawRealOrder! - 1; i >= 0; i--) {
        previousAssociatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.rawRealOrder == i);
        if (previousAssociatedSegment != null) {
          break;
        }
      }
      // Buscar el segmento asociado posterior
      Segment? nextAssociatedSegment;
      for (int i = newSegment.rawRealOrder! + 1; i < referenceTextSegments.length; i++) {
        nextAssociatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.rawRealOrder == i);
        if (nextAssociatedSegment != null) {
          break;
        }
      }
      // Calcular la posición de inserción
      int insertIndex = 0;
      if (previousAssociatedSegment != null) {
        insertIndex = wordAlignmentSegments.indexOf(previousAssociatedSegment) + 1;
      } else if (nextAssociatedSegment != null) {
        insertIndex = wordAlignmentSegments.indexOf(nextAssociatedSegment);
      } else {
        insertIndex = wordAlignmentSegments.length;
      }
      // Insertar en la posición correcta
      wordAlignmentSegments.insert(insertIndex, newSegment);
    }
    print("_insertPunctuation - Fin");
  }*/

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

  void addUnassociatedInsertions() {
    print("addUnassociatedInsertions - Inicio");
    // Crear una lista temporal para almacenar los nuevos segmentos
    List<Segment> newSegments = [];
    // 1. Recorrer audioTranscriptionSegments
    for (int audioTranscriptionIndex = 0; audioTranscriptionIndex < audioTranscriptionSegments.length; audioTranscriptionIndex++) {
      Segment audioTranscriptionSegment = audioTranscriptionSegments[audioTranscriptionIndex];
      // 2. Verificar si la palabra ya está asociada
      bool isAssociated = wordAlignmentSegments.any((element) => element.transcribedIndex == audioTranscriptionIndex);
      if (!isAssociated) {
        print("addUnassociatedInsertions - Añadiendo inserción no asociada: ${audioTranscriptionSegment.word} en el indice $audioTranscriptionIndex");
        // 3. Crear el segmento de inserción
        Segment insertionSegment = Segment(
          start: audioTranscriptionSegment.start,
          end: audioTranscriptionSegment.end,
          word: audioTranscriptionSegment.word,
          probability: audioTranscriptionSegment.probability,
          realWord: null, // No hay palabra de referencia
          transcribedWords: [audioTranscriptionSegment.word],
          transcribedWordsProbabilities: [audioTranscriptionSegment.probability],
          associationType: AssociationType.inserted,
          levenshteinDistance: 0, // No hay comparación con referencia
          realIndex: null, // No hay índice de referencia
          transcribedIndex: audioTranscriptionIndex,
          transcribedOrder: audioTranscriptionSegment.transcribedOrder,
          realOrder: null,
          rawRealOrder: null,
        );
        // Añadir el segmento a la lista temporal
        newSegments.add(insertionSegment);
      }
    }
    // Insertar los nuevos segmentos en la posición correcta
    for (Segment newSegment in newSegments) {
      // Buscar el segmento asociado anterior
      Segment? previousAssociatedSegment;
      for (int i = newSegment.transcribedIndex! - 1; i >= 0; i--) {
        previousAssociatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.transcribedIndex == i);
        if (previousAssociatedSegment != null) {
          break;
        }
      }
      // Buscar el segmento asociado posterior
      Segment? nextAssociatedSegment;
      for (int i = newSegment.transcribedIndex! + 1; i < audioTranscriptionSegments.length; i++) {
        nextAssociatedSegment = wordAlignmentSegments.firstWhereOrNull((element) => element.transcribedIndex == i);
        if (nextAssociatedSegment != null) {
          break;
        }
      }
      // Calcular la posición de inserción
      int insertIndex = 0;
      if (previousAssociatedSegment != null) {
        insertIndex = wordAlignmentSegments.indexOf(previousAssociatedSegment) + 1;
      } else if (nextAssociatedSegment != null) {
        insertIndex = wordAlignmentSegments.indexOf(nextAssociatedSegment);
      } else {
        insertIndex = wordAlignmentSegments.length;
      }
      // Insertar en la posición correcta
      wordAlignmentSegments.insert(insertIndex, newSegment);
    }
    print("addUnassociatedInsertions - Fin");
  }
}

/*Transcription.fromListMap({
    required List<Map<String, dynamic>> listMap,
    bool generateAudioTranscriptionSegments = true,
    bool generateReferenceTextSegments = true,
    bool generateWordAlignmentSegments = true,
    bool generateRawReferenceTextSegments = true,
    String? referenceText,
    this.shouldInsertPunctuation = false, // Nuevo parámetro
  }) {
    print("listMap --> $listMap");
    this.referenceText = referenceText;
    if (generateAudioTranscriptionSegments) {
      for (Map<String, dynamic> map in listMap) {
        double start = map.containsKey('start') && map['start'] is double ? map['start'] : 0.0;
        double end = map.containsKey('end') && map['end'] is double ? map['end'] : 0.0;
        String text = map.containsKey('word') && map['word'] is String ? map['word'] : "";
        double probability = map.containsKey('probability') && map['probability'] is double ? map['probability'] : 1.0;
        audioTranscriptionSegments.add(
          Segment(start: start, end: end, word: text, probability: probability, transcribedOrder: audioTranscriptionSegments.length, associationType: AssociationType.none),
        );
        audioTranscriptionWords.add(text);
      }
      audioTranscriptionWords = audioTranscriptionWords.map((e) => e.toLowerCase().trim()).toList();
      audioTranscriptionWords = audioTranscriptionWords.where((element) => element.isNotEmpty).toList();
    }
    if (generateReferenceTextSegments && referenceText != null) {
      rawReferenceTextSegments = createRawReferenceTextSegments(referenceText);
      referenceTextWords = referenceText.split(' ');
      int start = 0;
      int referenceOrder = 0;
      for (int i = 0; i < referenceTextWords.length; i++) {
        String writtenWord = referenceTextWords[i];
        int end = start + writtenWord.length;
        Segment segment = Segment(
          start: start.toDouble(),
          end: end.toDouble(),
          word: writtenWord,
          probability: 1.0,
          realOrder: referenceOrder,
          rawRealOrder: i,
          associationType: AssociationType.none,
        );
        referenceTextSegments.add(segment);
        // Poblar el mapa
        if (!_referenceSegmentsByWord.containsKey(writtenWord)) {
          _referenceSegmentsByWord[writtenWord] = [];
        }
        _referenceSegmentsByWord[writtenWord]!.add(segment);
        // Poblar el mapa por indice
        _referenceSegmentsByIndex[referenceOrder] = segment;
        start = end + 1; // +1 para el espacio en blanco
        referenceOrder++;
      }
      // Crear la lista de signos de puntuacion
      referenceTextPunctuationSegments = rawReferenceTextSegments.where((element) => element.isPunctuation == true).toList();
      // Eliminar los signos de puntuación de referenceTextWords y referenceTextSegments
      referenceTextWords.removeWhere((word) => [".", ",", ":", ";", "!", "?"].contains(word));
      referenceTextSegments.removeWhere((segment) => [".", ",", ":", ";", "!", "?"].contains(segment.word));
      // Eliminar las referencias a la puntuación de _referenceSegmentsByIndex y _referenceSegmentsByWord
      _referenceSegmentsByIndex.removeWhere((key, value) => value.isPunctuation);
      _referenceSegmentsByWord.removeWhere((key, value) => value.any((element) => element.isPunctuation));
    }
    if (generateWordAlignmentSegments) {
      wordAlignmentSegments = [];
      associateWords();
      if (shouldInsertPunctuation) {
        _insertPunctuation();
      }
    }
  }*/
/*List<Segment> createRawReferenceTextSegments(String? referenceText) {
    print("createRawReferenceTextSegments - Inicio");
    List<Segment> segments = [];
    if (referenceText == null) return segments;
    String currentWord = "";
    double start = 0.0;
    double end = 0.0;
    int index = 0;
    for (int i = 0; i < referenceText.length; i++) {
      String char = referenceText[i];
      if (char == " " || char == "\n" || [".", ",", ":", ";", "!", "?"].contains(char)) {
        if (currentWord.isNotEmpty) {
          end = start + currentWord.length;
          segments.add(Segment(start: start, end: end, word: currentWord, probability: 1.0, rawRealOrder: index, associationType: AssociationType.none));
          index++;
          currentWord = "";
          start = end + 1;
        }
        if ([".", ",", ":", ";", "!", "?"].contains(char)) {
          end = start + char.length;
          segments.add(Segment(start: start, end: end, word: char, probability: 1.0, associationType: AssociationType.punctuation, isPunctuation: true, rawRealOrder: index));
          index++;
          start = end + 1;
        }
        if (char == "\n") {
          end = start + 1;
          segments.add(Segment(start: start, end: end, word: "¶", probability: 1.0, rawRealOrder: index, associationType: AssociationType.none));
          index++;
          start = end + 1;
        }
      } else {
        currentWord += char;
      }
    }
    if (currentWord.isNotEmpty) {
      end = start + currentWord.length;
      segments.add(Segment(start: start, end: end, word: currentWord, probability: 1.0, rawRealOrder: index, associationType: AssociationType.none));
    }
    print("createRawReferenceTextSegments - Fin");
    return segments;
  }*/
