import 'dart:math';
import 'package:transcriber_whisper/models/segment.dart';

class Transcription {
  // Segmentos de la transcripción del audio
  List<Segment> audioTranscriptionSegments = [];
// Segmentos del texto de referencia (original)
  List<Segment> referenceTextSegments = [];
  // Segmentos que representan la alineación entre la transcripción y el texto de referencia
  List<Segment>? wordAlignmentSegments = [];
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
        audioTranscriptionSegments.add(Segment(start: start, end: end, word: text, probability: probability, transcribedOrder: audioTranscriptionSegments.length));
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
        Segment segment = Segment(start: start.toDouble(), end: end.toDouble(), word: writtenWord, probability: 1.0, realOrder: referenceOrder, rawRealOrder: i);
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

  List<Segment> createRawReferenceTextSegments(String? referenceText) {
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
          segments.add(Segment(start: start, end: end, word: currentWord, probability: 1.0, rawRealOrder: index));
          index++;
          currentWord = "";
          start = end + 1;
        }
        if ([".", ",", ":", ";", "!", "?"].contains(char)) {
          end = start + char.length;
          segments.add(Segment(start: start, end: end, word: char, probability: 1.0, associationType: "Puntuación", isPunctuation: true, rawRealOrder: index));
          index++;
          start = end + 1;
        }
        if (char == "\n") {
          end = start + 1;
          segments.add(Segment(start: start, end: end, word: "¶", probability: 1.0, rawRealOrder: index));
          index++;
          start = end + 1;
        }
      } else {
        currentWord += char;
      }
    }
    if (currentWord.isNotEmpty) {
      end = start + currentWord.length;
      segments.add(Segment(start: start, end: end, word: currentWord, probability: 1.0, rawRealOrder: index));}
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

  void printWordAlignmentSegmentsInfo() {
    print("Información de Segmentos Alineados:");
    print("----------------------------------");
    for (int i = 0; i < wordAlignmentSegments!.length; i++) {
      Segment segment = wordAlignmentSegments![i];
      print("Segmento numero: ${i + 1}");
      print("Palabra de Referencia: ${segment.realIndex} --> ${segment.realWord}");
      print("Palabra de la Transcripción: ${segment.transcribedIndex} --> ${segment.word}");
      print("Tipo de Alineación: ${segment.associationType}");
      print("Distancia Levenshtein: ${segment.levenshteinDistance}");
      print("Probabilidad: ${segment.probability}");
      print("Inicio: ${segment.start}, Fin: ${segment.end}");
      print("  Palabras de la Transcripción Asociadas: ${segment.transcribedWords?.join(", ")}");
      print("  Probabilidades Asociadas: ${segment.transcribedWordsProbabilities?.join(", ")}");
      print("  rawReferenceOrder: ${segment.rawRealOrder}");
      if (segment.associationType == "Inserción") {
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
      if (segment.associationType == "Eliminada") {
        print("  Posición en el audio: Entre ${segment.realWordBeforeEnd} y ${segment.realWordAfterStart}");
      }
      print("----------------------------------");
    }
  }

  void associateWords() {
    print("associateWords - Inicio");
    // Asociar las palabras exactas
    _associateExactMatches();
    // Asociar las palabras parecidas
    //_associateNonExactMatches();
    // Añadir las palabras reales no asociadas
    //_addUnassociatedReferenceWords();
    // Añadir las inserciones no asociadas
    //addUnassociatedInsertions();
    // Reordenar las inserciones
    //_reorderInsertions();
    print("associateWords - Fin");
  }

  void _associateExactMatches() {
    print("_associateExactMatches - Inicio");
    // Crear un conjunto para llevar un registro de las palabras transcritas asociadas
    Set<int> associatedAudioTranscriptionIndexes = {};
    // Crear un conjunto para llevar un registro de las palabras reales asociadas
    Set<int> associatedReferenceIndexes = {};
    // Iterar sobre los segmentos reales
    for (int referenceIndex = 0; referenceIndex < referenceTextSegments.length; referenceIndex++) {
      Segment referenceSegment = referenceTextSegments[referenceIndex];
      // Iterar sobre los segmentos transcritos
      for (int audioTranscriptionIndex = 0; audioTranscriptionIndex < audioTranscriptionSegments.length; audioTranscriptionIndex++) {
        Segment audioTranscriptionSegment = audioTranscriptionSegments[audioTranscriptionIndex]; // Añadido: Ignorar segmentos de puntuación
        if (audioTranscriptionSegment.isPunctuation) {
          print("_associateExactMatches - Ignorando segmento de puntuación en transcripción: ${audioTranscriptionSegment.word}");
          continue;
        }
        // Verificar si la palabra transcrita ya está asociada
        if (associatedAudioTranscriptionIndexes.contains(audioTranscriptionIndex)) {
          print("_associateExactMatches - La palabra transcrita ${audioTranscriptionSegment.word} ya está asociada en el indice $audioTranscriptionIndex. No se asocia");
          continue;
        }
        // Verificar si las palabras coinciden exactamente
        if (audioTranscriptionSegment.word == referenceSegment.word) {
          print(
            "_associateExactMatches - Asociando: audioTranscriptionSegment.word: ${audioTranscriptionSegment.word}, referenceSegment.word: ${referenceSegment.word}, referenceIndex: $referenceIndex, audioTranscriptionIndex: $audioTranscriptionIndex",
          );
          // Crear y añadir el segmento asociado
          _createAndAddWordAlignmentSegment(
            audioTranscriptionSegment: audioTranscriptionSegment,
            referenceSegment: referenceSegment,
            alignmentType: "Coincidencia",
            levenshteinDistance: 0,
            referenceIndex: referenceIndex,
            audioTranscriptionIndex: audioTranscriptionIndex,
          );
          // Añadir los índices a los conjuntos de asociados
          associatedAudioTranscriptionIndexes.add(audioTranscriptionIndex);
          associatedReferenceIndexes.add(referenceIndex);
          // Salir del bucle interno ya que ya se ha encontrado una coincidencia
          break;
        }
      }
    }
    print("_associateExactMatches - Fin");
  }

  void _associateNonExactMatches() {
    print("_associateNonExactMatches - Inicio");
    // Recorrer las palabras reales
    for (int referenceIndex = 0; referenceIndex < referenceTextSegments.length; referenceIndex++) {
      Segment referenceSegment = referenceTextSegments[referenceIndex];
      // Añadido: Ignorar segmentos de puntuación
      if (referenceSegment.isPunctuation) {
        print("_associateNonExactMatches - Ignorando segmento de puntuación en texto real: ${referenceSegment.word}");
        continue;
      }
      // Recorrer las palabras transcritas
      for (int audioTranscriptionIndex = 0; audioTranscriptionIndex < audioTranscriptionSegments.length; audioTranscriptionIndex++) {
        Segment audioTranscriptionSegment = audioTranscriptionSegments[audioTranscriptionIndex];
        // Añadido: Ignorar segmentos de puntuación
        if (audioTranscriptionSegment.isPunctuation) {
          print("_associateNonExactMatches - Ignorando segmento de puntuación en transcripción: ${audioTranscriptionSegment.word}");
          continue;
        }
        // Calcular la distancia de Levenshtein
        int correctLevenshteinDistance = calculateLevenshteinDistance(audioTranscriptionSegment.word, referenceSegment.word);
        // Verificar si las palabras son similares (basado en la distancia de Levenshtein)
        if (correctLevenshteinDistance <= 3) {
          // Umbral de similitud (ajustable)
          print(
            "_associateNonExactMatches - Parecida: audioTranscriptionSegment.word: ${audioTranscriptionSegment.word}, referenceWord: ${referenceSegment.word},audioTranscriptionIndex: $audioTranscriptionIndex, referenceIndex: $referenceIndex, correctLevenshteinDistance: $correctLevenshteinDistance",
          );
          _createAndAddWordAlignmentSegment(
            audioTranscriptionSegment: audioTranscriptionSegment,
            referenceSegment: referenceSegment,
            alignmentType: "Parecida",
            levenshteinDistance: correctLevenshteinDistance,
            referenceIndex: referenceIndex,
            audioTranscriptionIndex: audioTranscriptionIndex,
          );
        }
      }
    }
    print("_associateNonExactMatches - Fin");
  }

  void _addUnassociatedReferenceWords() {
    print("_addUnassociatedReferenceWords - Inicio");
    // Recorrer las palabras reales
    for (int referenceIndex = 0; referenceIndex < referenceTextSegments.length; referenceIndex++) {
      Segment referenceSegment = referenceTextSegments[referenceIndex];
      // Añadido: Ignorar segmentos de puntuación
      if (referenceSegment.isPunctuation) {
        print("_addUnassociatedReferenceWords - Ignorando segmento de puntuación en texto real: ${referenceSegment.word}");
        continue;
      }
      // Verificar si la palabra real ya está asociada
      bool alreadyAssociated = wordAlignmentSegments!.any((element) => element.realIndex == referenceIndex);
      if (!alreadyAssociated) {
        print("_addUnassociatedReferenceWords - Añadiendo palabra real no asociada: ${referenceSegment.word} en el indice $referenceIndex");
        // Buscar la palabra asociada anterior
        Segment? previousAssociatedSegment;
        for (int i = referenceIndex - 1; i >= 0; i--) {
          previousAssociatedSegment = wordAlignmentSegments!.firstWhere((element) => element.realIndex == i, orElse: () => Segment(start: 0, end: 0, word: "", probability: 0));
          if (previousAssociatedSegment.associationType != "Eliminada" && !previousAssociatedSegment.isPunctuation) {
            break;
          }
          previousAssociatedSegment = null;
        }
        // Buscar la palabra asociada posterior
        Segment? nextAssociatedSegment;
        for (int i = referenceIndex + 1; i < referenceTextSegments.length; i++) {
          nextAssociatedSegment = wordAlignmentSegments!.firstWhere((element) => element.realIndex == i, orElse: () => Segment(start: 0, end: 0, word: "", probability: 0));
          if (nextAssociatedSegment.associationType != "Eliminada" && !nextAssociatedSegment.isPunctuation) {
            break;
          }
          nextAssociatedSegment = null;
        }
        // Calcular el start y el end
        double start = 0.0;
        double end = 0.0;
        if (previousAssociatedSegment != null) {
          start = previousAssociatedSegment.end;
        }
        if (nextAssociatedSegment != null) {
          end = nextAssociatedSegment.start;
        } else {
          end = start + 0.5; // Valor arbitrario si no hay siguiente
        }
        // Crear un nuevo segmento para la palabra real no asociada
        Segment associatedSegment = Segment(
          start: start,
          end: end,
          word: referenceSegment.word,
          probability: 0.0, // Probabilidad baja por defecto
          realWord: referenceSegment.word,
          transcribedWords: [],
          transcribedWordsProbabilities: [],
          associationType: "Eliminada",
          levenshteinDistance: 0,
          realIndex: referenceIndex,
          transcribedIndex: null,
          transcribedOrder: null,
          insertionOrder: null,
          realOrder: referenceIndex,
          realWordBeforeEnd: previousAssociatedSegment?.end, // Nuevo
          realWordAfterStart: nextAssociatedSegment?.start, // Nuevo
          rawRealOrder: referenceSegment.rawRealOrder,
        );
        // Añadir el segmento a associatedSegments
        wordAlignmentSegments!.add(associatedSegment);
      } else {
        print("_addUnassociatedReferenceWords - Ya asociado: ${referenceSegment.word} en el indice $referenceIndex");
      }
    }
    print("_addUnassociatedReferenceWords - Fin");
  }

  void addUnassociatedInsertions() {
    print("addUnassociatedInsertions - Inicio");
    List<Segment> segmentsToAdd = [];
    // Iterar sobre los segmentos transcritos
    for (int audioTranscriptionIndex = 0; audioTranscriptionIndex < audioTranscriptionSegments.length; audioTranscriptionIndex++) {
      Segment audioTranscriptionSegment = audioTranscriptionSegments[audioTranscriptionIndex];
      // Verificar si la palabra transcrita ya está asociada
      bool alreadyAssociated = wordAlignmentSegments!.any((element) => element.transcribedIndex == audioTranscriptionIndex);
      if (!alreadyAssociated) {
        print("addUnassociatedInsertions - Añadiendo inserción: ${audioTranscriptionSegment.word} en el indice $audioTranscriptionIndex");
        // Buscar las palabras asociadas cercanas en el texto real
        int? referenceWordBeforeRawRealOrder;
        int? referenceWordAfterRawRealOrder;
        // Buscar la palabra real antes de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! < audioTranscriptionSegment.transcribedOrder! && currentSegment.rawRealOrder != null) {
            if (referenceWordBeforeRawRealOrder == null || currentSegment.rawRealOrder! > referenceWordBeforeRawRealOrder!) {
              referenceWordBeforeRawRealOrder = currentSegment.rawRealOrder;
            }
          }
        }
        // Buscar la palabra real despues de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! > audioTranscriptionSegment.transcribedOrder! && currentSegment.rawRealOrder != null) {
            if (referenceWordAfterRawRealOrder == null || currentSegment.rawRealOrder! < referenceWordAfterRawRealOrder!) {
              referenceWordAfterRawRealOrder = currentSegment.rawRealOrder;
            }
          }
        }
        // Calcular la posición de la inserción en el texto real
        int? referenceOrder;
        if (referenceWordBeforeRawRealOrder != null && referenceWordAfterRawRealOrder != null) {
          referenceOrder = (referenceWordBeforeRawRealOrder + referenceWordAfterRawRealOrder) ~/ 2;
        } else if (referenceWordBeforeRawRealOrder != null) {
          referenceOrder = referenceWordBeforeRawRealOrder + 1;
        } else if (referenceWordAfterRawRealOrder != null) {
          referenceOrder = referenceWordAfterRawRealOrder;
        } else {
          referenceOrder = rawReferenceTextSegments.length; // Si no hay contexto, al final
        }
        Segment associatedSegment = Segment(
          start: audioTranscriptionSegment.start,
          end: audioTranscriptionSegment.end,
          word: audioTranscriptionSegment.word,
          probability: audioTranscriptionSegment.probability,
          realWord: null, // Sin asociación real
          transcribedWords: [audioTranscriptionSegment.word],
          transcribedWordsProbabilities: [audioTranscriptionSegment.probability],
          associationType: "Inserción",
          levenshteinDistance: 0,
          realIndex: null, // Sin índice real
          transcribedIndex: audioTranscriptionIndex, // Añadir el índice de la palabra transcrita
          transcribedOrder: audioTranscriptionIndex, // Añadir el orden de la palabra transcrita
          insertionOrder: null, // Añadir el orden de la insercion
          realOrder: null, // Añadir el orden en el texto real
          realWordBeforeIndex: null, // Añadir el índice de la palabra real antes
          realWordAfterIndex: null, // Añadir el índice de la palabra real después
          rawRealOrder: referenceOrder,
        );
        segmentsToAdd.add(associatedSegment);
      } else {
        print("addUnassociatedInsertions - Ya asociado: ${audioTranscriptionSegment.word} en el indice $audioTranscriptionIndex");
      }
    }
    // Insertar las inserciones en la posición correcta
    for (Segment segmentToAdd in segmentsToAdd) {
      int insertIndex = 0;
      for (int i = 0; i < wordAlignmentSegments!.length; i++) {
        Segment currentSegment = wordAlignmentSegments![i];
        // Si ambos tienen rawRealOrder, ordenar por rawRealOrder
        if (segmentToAdd.rawRealOrder != null && currentSegment.rawRealOrder != null) {
          if (segmentToAdd.rawRealOrder! < currentSegment.rawRealOrder!) {
            insertIndex = i;
            break;
          } else {
            insertIndex = i + 1;
          }
        } else if (segmentToAdd.rawRealOrder == null && currentSegment.rawRealOrder == null) {
          if (segmentToAdd.transcribedOrder! < currentSegment.transcribedOrder!) {
            insertIndex = i;
            break;
          } else {
            insertIndex = i + 1;
          }
        } else if (segmentToAdd.rawRealOrder != null) {
          insertIndex = i;
          break;
        } else{
          insertIndex = i + 1;
        }
      }
      // Insertar la inserción en la posición correcta
      wordAlignmentSegments!.insert(insertIndex, segmentToAdd);
    }
    // Asignar el insertionOrder a las inserciones
    int insertionOrder = 0;
    for (Segment segment in wordAlignmentSegments!) {
      if (segment.associationType == "Inserción") {
        segment.insertionOrder = insertionOrder;
        insertionOrder++;
      }
    }
    // Actualizar la posicion de la insercion
    for (Segment segment in wordAlignmentSegments!) {
      if (segment.associationType == "Inserción") {
        // Buscar las palabras asociadas cercanas en el texto real
        int? referenceWordBeforeRawRealOrder;
        int? referenceWordAfterRawRealOrder;
        // Buscar la palabra real antes de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! < segment.transcribedOrder! && currentSegment.rawRealOrder != null) {
            if (referenceWordBeforeRawRealOrder == null || currentSegment.rawRealOrder! > referenceWordBeforeRawRealOrder!) {
              referenceWordBeforeRawRealOrder = currentSegment.rawRealOrder;
            }
          }
        }
        // Buscar la palabra real despues de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! > segment.transcribedOrder! && currentSegment.rawRealOrder != null) {
            if (referenceWordAfterRawRealOrder == null || currentSegment.rawRealOrder! < referenceWordAfterRawRealOrder!) {
              referenceWordAfterRawRealOrder = currentSegment.rawRealOrder;
            }
          }
        }
        // Calcular la posición de la inserción en el texto real
        int? referenceOrder;
        if (referenceWordBeforeRawRealOrder != null && referenceWordAfterRawRealOrder != null) {
          referenceOrder = (referenceWordBeforeRawRealOrder + referenceWordAfterRawRealOrder) ~/ 2;
        } else if (referenceWordBeforeRawRealOrder != null) {
          referenceOrder = referenceWordBeforeRawRealOrder + 1;
        } else if (referenceWordAfterRawRealOrder != null) {
          referenceOrder = referenceWordAfterRawRealOrder;
        } else {
          referenceOrder = rawReferenceTextSegments.length; // Si no hay contexto, al final
        }
        segment.rawRealOrder = referenceOrder;
        // Buscar las palabras asociadas cercanas en el texto real
        int? referenceWordBeforeIndex;
        int? referenceWordAfterIndex;
        // Buscar la palabra real antes de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! < segment.transcribedOrder! && currentSegment.realIndex != null) {
            if (referenceWordBeforeIndex == null || currentSegment.realIndex! > referenceWordBeforeIndex!) {
              referenceWordBeforeIndex = currentSegment.realIndex;
            }
          }
        }
        // Buscar la palabra real despues de la insercion
        for (int i = 0; i < wordAlignmentSegments!.length; i++) {
          Segment currentSegment = wordAlignmentSegments![i];
          // Añadido: Ignorar segmentos de puntuación
          if (currentSegment.isPunctuation) continue;
          // Cambio: Usar realOrder en lugar de transcribedOrder
          if (currentSegment.realOrder != null && currentSegment.realOrder! > segment.transcribedOrder! && currentSegment.realIndex != null) {
            if (referenceWordAfterIndex == null || currentSegment.realIndex! < referenceWordAfterIndex!) {
              referenceWordAfterIndex = currentSegment.realIndex;
            }
          }
        }
        segment.realWordBeforeIndex = referenceWordBeforeIndex;
        segment.realWordAfterIndex = referenceWordAfterIndex;
      }
    }
    print("addUnassociatedInsertions - Fin");
  }

  void _reorderInsertions() {
    print("_reorderInsertions - Inicio");
    // 1. Extraer las inserciones
    List<Segment> insertions = wordAlignmentSegments!.where((segment) => segment.associationType == "Inserción").toList();
    // 2. Eliminar las inserciones
    wordAlignmentSegments!.removeWhere((segment) => segment.associationType == "Inserción");
    // 3. Ordenar las inserciones por start
    insertions.sort((a, b) => a.start.compareTo(b.start));
    // 4. Reinsertar las inserciones
    for (Segment insertion in insertions) {
      int insertIndex = 0;
      for (int i = 0; i < wordAlignmentSegments!.length; i++) {
        Segment currentSegment = wordAlignmentSegments![i];
        if (insertion.start < currentSegment.start) {
          insertIndex = i;
          break;
        } else {
          insertIndex = i + 1;
        }
      }
      wordAlignmentSegments!.insert(insertIndex, insertion);
    }
    // 5. Asignar el insertionOrder a las inserciones
    int insertionOrder = 0;
    for (Segment segment in wordAlignmentSegments!) {
      if (segment.associationType == "Inserción") {
        segment.insertionOrder = insertionOrder;
        insertionOrder++;
      }
    }
    print("_reorderInsertions - Fin");
  }

  void _insertPunctuation() {
    print("_insertPunctuation - Inicio");
    for (Segment punctuationSegment in referenceTextPunctuationSegments) {
      // Buscar el segmento anterior que no sea puntuación
      Segment? previousSegment;
      for (int i = wordAlignmentSegments!.length - 1; i >= 0; i--) {
        Segment tempSegment = wordAlignmentSegments![i];
        if (tempSegment.rawRealOrder != null &&
            tempSegment.rawRealOrder! < punctuationSegment.rawRealOrder! &&
            !tempSegment.isPunctuation) {
          previousSegment = tempSegment;
          break;
        }
      }
      // Crear el segmento de auto-asociación
      Segment associatedSegment = Segment(
        start: 0.0, // Valor por defecto si no hay segmento anterior
        end: 0.0, // Valor por defecto si no hay segmento anterior
        word: punctuationSegment.word, // La palabra es el signo de puntuación
        probability: 1.0, // Probabilidad alta por ser auto-asociación
        realWord: punctuationSegment.word, // La palabra real es el signo de puntuación
        transcribedWords: [], // No hay palabras transcritas asociadas
        transcribedWordsProbabilities: [], // No hay probabilidades asociadas
        associationType: "Puntuación", // Tipo de asociación: Puntuación
        levenshteinDistance: 0, // Distancia de Levenshtein: 0
        realIndex: null, // No hay índice real
        transcribedIndex: null, // No hay índice transcrito
        transcribedOrder: null, // No hay orden transcrito
        insertionOrder: null, // No hay orden de inserción
        realOrder: null, // Orden real
        isPunctuation: true, // Es un signo de puntuación
        rawRealOrder: punctuationSegment.rawRealOrder,
      );
      // Insertar el segmento en la posición correcta
      int insertIndex = 0;
      for (int i = 0; i < wordAlignmentSegments!.length; i++) {
        Segment currentSegment = wordAlignmentSegments![i];
        if (currentSegment.rawRealOrder != null) {
          if (punctuationSegment.rawRealOrder! < currentSegment.rawRealOrder!) {
            insertIndex = i;
            break;
          } else {
            insertIndex = i + 1;
          }
        } else {
          insertIndex = i;
          break;
        }
      }
      wordAlignmentSegments!.insert(insertIndex, associatedSegment);
      // Actualizar el start y el end del segmento de puntuación
      if (previousSegment != null) {
        associatedSegment.start = previousSegment.end;
        associatedSegment.end = previousSegment.end;
      } else {
        // Si no hay segmento anterior, usar el inicio del primer segmento o 0.0
        if (wordAlignmentSegments!.isNotEmpty) {
          associatedSegment.start = wordAlignmentSegments!.first.start;
          associatedSegment.end = wordAlignmentSegments!.first.start;
        } else {
          associatedSegment.start = 0.0;
          associatedSegment.end = 0.0;
        }
      }
    }
    print("_insertPunctuation - Fin");
  }

  void _createAndAddWordAlignmentSegment({
    required Segment audioTranscriptionSegment,
    required Segment? referenceSegment,
    required String alignmentType,
    required int levenshteinDistance,
    required int? referenceIndex,
    required int audioTranscriptionIndex,
  }) {
    // Verificar si la palabra real ya está asociada
    if (referenceSegment != null && referenceIndex != null) {
      bool referenceWordAlreadyAssociated = wordAlignmentSegments!.any((element) => element.realIndex == referenceIndex);
      if (referenceWordAlreadyAssociated) {
        print("_createAndAddWordAlignmentSegment - La palabra real ${referenceSegment.word} ya está asociada en el indice $referenceIndex. No se asocia");
        return;
      }
    }
    // Verificar si la palabra transcrita ya está asociada
    bool audioTranscriptionWordAlreadyAssociated = wordAlignmentSegments!.any((element) => element.transcribedIndex == audioTranscriptionIndex);
    if (audioTranscriptionWordAlreadyAssociated) {
      print("_createAndAddWordAlignmentSegment - La palabra transcrita ${audioTranscriptionSegment.word} ya está asociada en el indice $audioTranscriptionIndex. No se asocia");
      return;
    }
    // Crear el segmento asociado
    Segment associatedSegment = Segment(
        start: audioTranscriptionSegment.start,
        end: audioTranscriptionSegment.end,
        word: audioTranscriptionSegment.word,
        probability: audioTranscriptionSegment.probability,
        realWord: referenceSegment?.word,
        transcribedWords: [audioTranscriptionSegment.word],
        transcribedWordsProbabilities: [audioTranscriptionSegment.probability],
        associationType: alignmentType,
        levenshteinDistance: levenshteinDistance,
        realIndex: referenceIndex,
        transcribedIndex: audioTranscriptionIndex,
        transcribedOrder: audioTranscriptionSegment.transcribedOrder,
      insertionOrder: null,
      realOrder: referenceIndex,
      rawRealOrder: referenceSegment?.rawRealOrder,
    );
    // Añadir el segmento a associatedSegments
    wordAlignmentSegments!.add(associatedSegment);
    // Poblar el mapa
    if (audioTranscriptionSegment.word != null) {
      if (!_wordAlignmentSegmentsByAudioTranscriptionWord.containsKey(audioTranscriptionSegment.word)) {
        _wordAlignmentSegmentsByAudioTranscriptionWord[audioTranscriptionSegment.word] = [];
      }
      _wordAlignmentSegmentsByAudioTranscriptionWord[audioTranscriptionSegment.word]!.add(associatedSegment);
    }
    // Poblar el mapa por indice
    _wordAlignmentSegmentsByAudioTranscriptionIndex[audioTranscriptionIndex] = associatedSegment;
  }
}