import 'dart:math';

import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/models/word_association.dart';

class Transcription {
  List<Segment> transcribedSegments; // Segmentos de la transcripción
  List<Segment>? rawRealTextSegments; // segmento con puntuacion y saltos de parrafo como segmentos
  List<Segment>? realTextSegments; // Segmentos del texto real
  List<Segment>? associatedSegments; // Segmentos asociados (transcripción vs. texto real)
  String? fullTextTranscription; // Texto completo de la transcripción
  List<String>? transcribedWords; // Lista de palabras de la transcripción
  List<String>? realTextWords; // Lista de palabras del texto real
  List<Segment>? alignedSegments; // Segmentos alineados
  String? realText; // Texto real

  Transcription({
    required this.transcribedSegments,
    this.rawRealTextSegments,
    this.realTextSegments,
    this.associatedSegments,
    this.fullTextTranscription,
    this.transcribedWords,
    this.realTextWords,
    this.alignedSegments,
    this.realText,
  });

  factory Transcription.fromListMap(
    dynamic transcriptionDataList, {
    bool processRealText = true,
    bool generateRealTextSegments = true,
    bool generateTranscriptionSegments = true,
    bool generateTranscriptionWords = true,
    bool generateRealTextWords = true,
    bool generateFullTextTranscription = true,
    bool generateAssociatedSegments = true,
    required String realText,
  }) {
    List<Segment> transcriptionSegments = [];
    List<Segment> realTextSegments = [];
    List<Segment> associatedSegments = [];
    String fullTextTranscription = "";
    List<String> realTextWords = [];
    List<String> transcriptionWords = [];

    try {
      // Procesar el texto real si es necesario
      if (processRealText && realText.isNotEmpty) {
        String formattedText = realText;
        // Remove punctuation
        formattedText = formattedText.replaceAll(RegExp(r'[^\w\s]'), '');
        // Replace multiple spaces with single space
        formattedText = formattedText.replaceAll(RegExp(r'\s+'), ' ');
        // Replace newlines with single space
        formattedText = formattedText.replaceAll(RegExp(r'[\r\n]+'), ' ');
        // Trim leading and trailing whitespace
        formattedText = formattedText.trim();
        // Convert to lowercase
        formattedText = formattedText.toLowerCase();
        // Split into words
        if (generateRealTextWords) {
          realTextWords = formattedText.split(' ').where((word) => word.isNotEmpty).toList();
        }
      }

      // Procesar la lista de mapas si es necesario
      if (transcriptionDataList is List) {
        for (int i = 0; i < transcriptionDataList.length; i++) {
          var segmentData = transcriptionDataList[i];
          if (segmentData is Map<String, dynamic>) {
            if (generateTranscriptionSegments) {
              Segment segment = Segment.fromMap(segmentData);
              transcriptionSegments.add(segment);
            }

            if (generateTranscriptionWords && segmentData.containsKey("word")) {
              String word = segmentData["word"];
              // Remove punctuation
              word = word.replaceAll(RegExp(r'[^\w\s]'), '');
              // Replace multiple spaces with single space
              word = word.replaceAll(RegExp(r'\s+'), ' ');
              // Replace newlines with single space
              word = word.replaceAll(RegExp(r'[\r\n]+'), ' ');
              // Trim leading and trailing whitespace
              word = word.trim();
              word = word.toLowerCase();
              transcriptionWords.add(word);
            }

            if (generateFullTextTranscription && segmentData.containsKey("word")) {
              fullTextTranscription += "${segmentData["word"]} ";
            }
          } else {
            throw TranscriptionException("Error: Elemento no es un mapa: $segmentData");
          }
        }
      } else if (transcriptionDataList != null) {
        throw TranscriptionException("Error: transcriptionDataList no es una lista: $transcriptionDataList");
      }

      // Generar segmentos de texto real si es necesario
      if (generateRealTextSegments && realTextWords.isNotEmpty) {
        int start = 0;
        for (String writtenWord in realTextWords) {
          int end = start + writtenWord.length;
          realTextSegments.add(Segment(start: start.toDouble(), end: end.toDouble(), word: writtenWord, probability: 1.0));
          start = end + 1; // +1 para el espacio en blanco
        }
      }

      if (generateAssociatedSegments) {
        associatedSegments = [];
      }

      // Crear los segmentos raw
      List<Segment> rawRealTextSegments = createRawRealTextSegments(realText);

      return Transcription(transcribedSegments: transcriptionSegments)
        ..rawRealTextSegments = rawRealTextSegments
        ..realTextSegments = realTextSegments
        ..associatedSegments = associatedSegments
        ..transcribedWords = transcriptionWords
        ..realTextWords = realTextWords
        ..fullTextTranscription = fullTextTranscription
        ..realText = realText;
    } on TranscriptionException catch (e) {
      rethrow;
    } catch (e) {
      throw TranscriptionException("Error inesperado al crear la transcripción: $e");
    }
  }

  Transcription copyWith({
    List<Segment>? transcriptionSegments,
    List<Segment>? rawRealTextSegments,
    List<Segment>? realTextSegments,
    List<Segment>? associatedSegments,
    String? fullTextTranscription,
    List<String>? transcriptionWords,
    List<String>? realTextWords,
    List<Segment>? alignedSegments,
    String? realText,
  }) {
    return Transcription(
      transcribedSegments: transcriptionSegments ?? this.transcribedSegments,
      rawRealTextSegments: rawRealTextSegments ?? this.rawRealTextSegments,
      realTextSegments: realTextSegments ?? this.realTextSegments,
      associatedSegments: associatedSegments ?? this.associatedSegments,
      fullTextTranscription: fullTextTranscription ?? this.fullTextTranscription,
      transcribedWords: transcriptionWords ?? this.transcribedWords,
      realTextWords: realTextWords ?? this.realTextWords,
      alignedSegments: alignedSegments ?? this.alignedSegments,
      realText: realText ?? this.realText,
    );
  }

  static List<Segment> createRawRealTextSegments(String? realText) {
    if (realText == null) return [];
    List<Segment> segments = [];
    List<String> wordList = [];
    List<String> lines = realText.split("\n");
    for (String line in lines) {
      if (line.isEmpty) {
        wordList.add("¶");
      } else {
        List<String> words = line.split(RegExp(r"(\s)"));
        for (String word in words) {
          if (word.isNotEmpty && word != " ") {
            wordList.add(word);
          }
        }
      }
    }
    for (String word in wordList) {
      segments.add(Segment(start: 0, end: 0, word: word, probability: 1.0));
    }
    return segments;
  }

  List<Segment> alignSegmentsToRealText() {
    if (realTextSegments == null || associatedSegments == null) {
      print("Error: realTextSegments or associatedSegments is null");
      return [];
    }

    List<Segment> alignedSegments = [];
    int insertionIndex = 0;

    for (int i = 0; i < realTextSegments!.length; i++) {
      Segment realSegment = realTextSegments![i];
      List<String> transcribedWords = [];
      List<double> probabilities = [];
      String? associationType;
      int? levenshteinDistance;

      List<Segment> associatedToReal = associatedSegments!.where((segment) => segment.realWord == realSegment.word).toList();

      if (associatedToReal.isNotEmpty) {
        for (Segment associatedSegment in associatedToReal) {
          transcribedWords.add(associatedSegment.word);
          probabilities.add(associatedSegment.probability);
          associationType = associatedSegment.associationType;
          levenshteinDistance = associatedSegment.levenshteinDistance;
        }
      }

      alignedSegments.add(
        Segment(
          realWord: realSegment.word,
          transcribedWords: transcribedWords,
          transcribedWordsProbabilities: probabilities,
          associationType: associationType,
          levenshteinDistance: levenshteinDistance,
          start: realSegment.start,
          end: realSegment.end,
          word: "",
          probability: 0.0,
        ),
      );

      while (insertionIndex < associatedSegments!.length) {
        Segment insertionSegment = associatedSegments![insertionIndex];
        if (insertionSegment.realWord != null) {
          insertionIndex++;
          continue;
        }
        if (insertionSegment.start < (i + 1 < realTextSegments!.length ? realTextSegments![i + 1].start : double.infinity)) {
          alignedSegments.add(
            Segment(
              realWord: null,
              transcribedWords: [insertionSegment.word],
              transcribedWordsProbabilities: [insertionSegment.probability],
              associationType: insertionSegment.associationType,
              levenshteinDistance: insertionSegment.levenshteinDistance,
              start: insertionSegment.start,
              end: insertionSegment.end,
              word: insertionSegment.word,
              probability: insertionSegment.probability,
            ),
          );
          insertionIndex++;
        } else {
          break;
        }
      }
    }

    while (insertionIndex < associatedSegments!.length) {
      Segment insertionSegment = associatedSegments![insertionIndex];
      if (insertionSegment.realWord == null) {
        alignedSegments.add(
          Segment(
            realWord: null,
            transcribedWords: [insertionSegment.word],
            transcribedWordsProbabilities: [insertionSegment.probability],
            associationType: insertionSegment.associationType,
            levenshteinDistance: insertionSegment.levenshteinDistance,
            start: insertionSegment.start,
            end: insertionSegment.end,
            word: insertionSegment.word,
            probability: insertionSegment.probability,
          ),
        );
      }
      insertionIndex++;
    }

    alignedSegments.sort((a, b) => a.start.compareTo(b.start));
    this.alignedSegments = alignedSegments;
    return alignedSegments;
  }

  String getAlignedSegmentsInfo() {
    if (alignedSegments == null || realTextSegments == null) {
      throw TranscriptionException("No hay segmentos alineados o segmentos reales.");
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("Información de Segmentos Alineados:");
    buffer.writeln("----------------------------------");

    for (Segment segment in alignedSegments!) {
      buffer.writeln("Palabra Real: ${segment.realWord ?? 'N/A'}");
      buffer.writeln("Palabras Transcritas: ${segment.transcribedWords?.isNotEmpty == true ? segment.transcribedWords!.join(', ') : 'N/A'}");
      buffer.writeln("Probabilidades Transcritas: ${segment.transcribedWordsProbabilities?.isNotEmpty == true ? segment.transcribedWordsProbabilities!.join(', ') : 'N/A'}");
      buffer.writeln("Tipo de Asociación: ${segment.associationType ?? 'N/A'}");
      buffer.writeln("Distancia Levenshtein: ${segment.levenshteinDistance ?? 'N/A'}");
      buffer.writeln("Inicio: ${segment.start}, Fin: ${segment.end}");
      buffer.writeln("----------------------------------");
    }

    return buffer.toString();
  }

  bool areWordsSimilar(String word1, String word2) {
    // Comprobar si comparten al menos dos letras
    int sharedLettersCount = 0;
    for (String letter in word1.split('')) {
      if (word2.contains(letter)) {
        sharedLettersCount++;
      }
    }
    bool shareEnoughLetters = sharedLettersCount >= 2;

    // Comprobar la longitud relativa (hacerlo más estricto)
    double lengthRatio = word1.length > word2.length ? word1.length / word2.length : word2.length / word1.length;
    bool similarLength = lengthRatio <= 1.5; // Ajustar el umbral de longitud relativa según sea necesario

    // Comprobar si comparten las mismas primeras letras
    bool shareSameFirstLetters = word1.isNotEmpty && word2.isNotEmpty && word1[0] == word2[0];

    // Comprobar si comparten las mismas últimas letras
    bool shareSameLastLetters = word1.isNotEmpty && word2.isNotEmpty && word1[word1.length - 1] == word2[word2.length - 1];

    // Comprobar si comparten las mismas vocales
    String vowels1 = word1.replaceAll(RegExp(r'[^aeiouAEIOU]'), '');
    String vowels2 = word2.replaceAll(RegExp(r'[^aeiouAEIOU]'), '');
    bool shareSameVowels = vowels1 == vowels2;

    // Comprobar si comparten las mismas consonantes
    String consonants1 = word1.replaceAll(RegExp(r'[aeiouAEIOU]'), '');
    String consonants2 = word2.replaceAll(RegExp(r'[aeiouAEIOU]'), '');
    bool shareSameConsonants = consonants1 == consonants2;

    // Comprobar si comparten las mismas letras en el mismo orden
    bool shareSameLettersInOrder = word1.length == word2.length && word1 == word2;

    // Comprobar si comparten las mismas letras en el mismo orden pero con una letra de diferencia
    bool shareSameLettersInOrderOneDifference = word1.length == word2.length && calculateLevenshteinDistance(word1, word2) == 1;

    // Comprobar si comparten las mismas letras en el mismo orden pero con dos letras de diferencia
    bool shareSameLettersInOrderTwoDifference = word1.length == word2.length && calculateLevenshteinDistance(word1, word2) == 2;

    // Comprobar si comparten las mismas letras en el mismo orden pero con tres letras de diferencia
    bool shareSameLettersInOrderThreeDifference = word1.length == word2.length && calculateLevenshteinDistance(word1, word2) == 3;

    print(
      "areWordsSimilar --> $word1 vs $word2 (shareEnoughLetters: $shareEnoughLetters, lengthRatio: $lengthRatio, similarLength: $similarLength, shareSameFirstLetters: $shareSameFirstLetters, shareSameLastLetters: $shareSameLastLetters, shareSameVowels: $shareSameVowels, shareSameConsonants: $shareSameConsonants, shareSameLettersInOrder: $shareSameLettersInOrder, shareSameLettersInOrderOneDifference: $shareSameLettersInOrderOneDifference, shareSameLettersInOrderTwoDifference: $shareSameLettersInOrderTwoDifference, shareSameLettersInOrderThreeDifference: $shareSameLettersInOrderThreeDifference)",
    );

    // Combinación de ambos criterios (ahora más estricta)
    return shareEnoughLetters &&
        similarLength &&
        (shareSameFirstLetters ||
            shareSameLastLetters ||
            shareSameVowels ||
            shareSameConsonants ||
            shareSameLettersInOrder ||
            shareSameLettersInOrderOneDifference ||
            shareSameLettersInOrderTwoDifference ||
            shareSameLettersInOrderThreeDifference);
  }

  ///////////
  void associateWords() {
    print("associateWords - Inicio");
    // Limpiar la lista de segmentos asociados
    associatedSegments!.clear();
    // Asociar las palabras que coinciden exactamente
    _associateExactMatches();
    // Asociar las palabras que no coinciden exactamente
    _associateNonExactMatches();
    print("associateWords - Fin");
  }

  // Función privada para crear y añadir un segmento asociado
  void _createAndAddAssociatedSegment({
    required Segment transcribedSegment,
    required Segment? realSegment,
    required String associationType,
    required int levenshteinDistance,
    required int? realIndex,
    required int transcribedIndex,
  }) {
    // Verificar si la palabra real ya está asociada
    if (realSegment != null) {
      bool realWordAlreadyAssociated = associatedSegments!.any((element) => element.realWord == realSegment.word && element.realIndex == realIndex);
      if (realWordAlreadyAssociated) {
        print("_createAndAddAssociatedSegment - La palabra real ${realSegment.word} ya está asociada en el indice $realIndex. No se asocia");
        return;
      }
    }
    // Verificar si la palabra transcrita ya está asociada
    bool transcribedWordAlreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word && element.transcribedIndex == transcribedIndex);
    if (transcribedWordAlreadyAssociated) {
      print("_createAndAddAssociatedSegment - La palabra transcrita ${transcribedSegment.word} ya está asociada en el indice $transcribedIndex. No se asocia");
      return;
    }
    // Crear WordAssociation
    WordAssociation wordAssociation = WordAssociation([transcribedSegment.word], realSegment?.word, [transcribedSegment.probability]);
    // Crear un nuevo segmento para la asociación
    Segment associatedSegment = Segment(
      start: transcribedSegment.start,
      end: transcribedSegment.end,
      word: transcribedSegment.word,
      probability: transcribedSegment.probability,
      realWord: realSegment?.word,
      wordAssociation: wordAssociation,
      transcribedWords: [transcribedSegment.word],
      transcribedWordsProbabilities: [transcribedSegment.probability],
      associationType: associationType,
      levenshteinDistance: levenshteinDistance,
      realIndex: realIndex,
      transcribedIndex: transcribedIndex,
      transcribedOrder: transcribedIndex,
      realOrder: realIndex,
    );
    print(
      "_createAndAddAssociatedSegment - Tipo de asociacion: ${associatedSegment.associationType}, correctLevenshteinDistance: $levenshteinDistance, transcribedSegment.word: ${transcribedSegment.word}, realSegment.word: ${realSegment?.word}, realIndex: $realIndex, transcribedIndex: $transcribedIndex",
    );
    // Añadir el segmento a associatedSegments
    associatedSegments!.add(associatedSegment);
  }

  void _associateExactMatches() {
    print("_associateExactMatches - Inicio");
    // Crear un conjunto para llevar un registro de las palabras transcritas asociadas
    Set<int> associatedTranscribedIndexes = {};
    // Crear un conjunto para llevar un registro de las palabras reales asociadas
    Set<int> associatedRealIndexes = {};
    // Iterar sobre los segmentos reales
    for (int realIndex = 0; realIndex < realTextSegments!.length; realIndex++) {
      Segment realSegment = realTextSegments![realIndex];
      // Verificar si la palabra real ya está asociada
      if (associatedRealIndexes.contains(realIndex)) {
        print("_associateExactMatches - La palabra real ${realSegment.word} ya está asociada en el indice $realIndex. No se asocia");
        continue;
      }
      // Iterar sobre los segmentos transcritos
      for (int transcribedIndex = 0; transcribedIndex < transcribedSegments.length; transcribedIndex++) {
        Segment transcribedSegment = transcribedSegments[transcribedIndex];
        // Verificar si la palabra transcrita ya está asociada
        if (associatedTranscribedIndexes.contains(transcribedIndex)) {
          print("_associateExactMatches - La palabra transcrita ${transcribedSegment.word} ya está asociada en el indice $transcribedIndex. No se asocia");
          continue;
        }
        // Si la palabra real es la misma que la palabra transcrita (ignorando mayúsculas/minúsculas)
        if (realSegment.word.toLowerCase() == transcribedSegment.word.toLowerCase()) {
          _createAndAddAssociatedSegment(
            transcribedSegment: transcribedSegment,
            realSegment: realSegment,
            associationType: "Coincidencia",
            levenshteinDistance: 0,
            realIndex: realIndex,
            transcribedIndex: transcribedIndex,
          );
          print(
            "_associateExactMatches - Asociando: transcribedSegment.word: ${transcribedSegment.word}, realSegment.word: ${realSegment.word}, realIndex: $realIndex, transcribedIndex: $transcribedIndex",
          );
          // Añadir el índice de la palabra transcrita al conjunto de palabras asociadas
          associatedTranscribedIndexes.add(transcribedIndex);
          // Añadir el índice de la palabra real al conjunto de palabras asociadas
          associatedRealIndexes.add(realIndex);
          break; // Salir del bucle interno porque ya se encontró una coincidencia
        }
      }
    }
    print("_associateExactMatches - Fin");
  }

  void _associateNonExactMatches() {
    print("_associateNonExactMatches - Inicio");
    // Recorrer las palabras reales
    for (int realIndex = 0; realIndex < realTextSegments!.length; realIndex++) {
      Segment realSegment = realTextSegments![realIndex];
      // Verificar si la palabra real ya está asociada
      bool realWordAlreadyAssociated = associatedSegments!.any((element) => element.realWord == realSegment.word && element.realIndex == realIndex);
      if (realWordAlreadyAssociated) {
        print("_associateNonExactMatches - La palabra real ${realSegment.word} ya está asociada en _associateExactMatches en el indice $realIndex. No se asocia");
        continue;
      }
      // Recorrer las palabras transcritas
      for (int transcribedIndex = 0; transcribedIndex < transcribedSegments.length; transcribedIndex++) {
        Segment transcribedSegment = transcribedSegments[transcribedIndex];
        // Verificar si la palabra transcrita ya está asociada
        bool transcribedWordAlreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word && element.transcribedIndex == transcribedIndex);
        if (transcribedWordAlreadyAssociated) {
          print(
            "_associateNonExactMatches - La palabra transcrita ${transcribedSegment.word} ya está asociada en _associateExactMatches en el indice $transcribedIndex. No se asocia",
          );
          continue;
        }
        // Calcular la distancia de Levenshtein
        int correctLevenshteinDistance = calculateLevenshteinDistance(transcribedSegment.word, realSegment.word);
        // Verificar si las palabras son similares (basado en la distancia de Levenshtein)
        if (correctLevenshteinDistance <= 3) {
          // Umbral de similitud (ajustable)
          print(
            "_associateNonExactMatches - Parecida: transcribedSegment.word: ${transcribedSegment.word}, realWord: ${realSegment.word},transcribedIndex: $transcribedIndex, realIndex: $realIndex, correctLevenshteinDistance: $correctLevenshteinDistance",
          );
          _createAndAddAssociatedSegment(
            transcribedSegment: transcribedSegment,
            realSegment: realSegment,
            associationType: "Parecida",
            levenshteinDistance: correctLevenshteinDistance,
            realIndex: realIndex,
            transcribedIndex: transcribedIndex,
          );
        }
      }
    } // Añadir las inserciones no asociadas
    addUnassociatedInsertions();
    // Asociar las palabras cercanas
    for (int transcribedIndex = 0; transcribedIndex < transcribedSegments.length; transcribedIndex++) {
      Segment transcribedSegment = transcribedSegments[transcribedIndex];
      // Verificar si la palabra transcrita ya está asociada
      bool transcribedWordAlreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word && element.transcribedIndex == transcribedIndex);
      if (!transcribedWordAlreadyAssociated) {
        associateNearbyTranscribedWords(transcribedIndex, transcribedSegment.word, true, 0, "Cercana");
      }
    }
    print("_associateNonExactMatches - Fin");
  }

  String getAssociatedSegmentsInfo() {
    print("getAssociatedSegmentsInfo - Inicio");
    String info = "Información de Segmentos Asociados:\n----------------------------------\n";
    // Ordenar los segmentos por realOrder si existe, si no por transcribedOrder
    associatedSegments!.sort((a, b) {
      if (a.realOrder != null && b.realOrder != null) {
        return a.realOrder!.compareTo(b.realOrder!);
      } else if (a.realOrder != null) {
        return -1; // a va primero
      } else if (b.realOrder != null) {
        return 1; // b va primero
      } else {
        return a.transcribedOrder!.compareTo(b.transcribedOrder!);
      }
    });
    int segmentNumber = 1; // Inicializar el contador de segmentos
    for (Segment segment in associatedSegments!) {
      info += "Segmento numero: $segmentNumber\n"; // Mostrar el número de segmento
      info += "Palabra Real: ${segment.realIndex ?? 'null'} --> ${segment.realWord ?? 'null'}\n";
      info += "Palabra Transcrita: ${segment.transcribedIndex ?? 'null'} --> ${segment.word}\n";
      info += "Tipo de Asociación: ${segment.associationType}\n";
      info += "Distancia Levenshtein: ${segment.levenshteinDistance}\n";
      info += "Probabilidad: ${segment.probability}\n";
      info += "Inicio: ${segment.start}, Fin: ${segment.end}\n";
      info += "  Palabras Transcritas Asociadas: ${segment.transcribedWords?.join(', ') ?? 'null'}\n";
      info += "  Probabilidades Asociadas: ${segment.transcribedWordsProbabilities?.join(', ') ?? 'null'}\n";
      if (segment.associationType == "Inserción") {
        info += "  Posición en el texto real: ";
        if (segment.realWordBeforeIndex != null && segment.realWordAfterIndex != null) {
          info += "Entre ${segment.realWordBeforeIndex} y ${segment.realWordAfterIndex}\n";
        } else if (segment.realWordBeforeIndex != null) {
          info += "Después de ${segment.realWordBeforeIndex}\n";
        } else if (segment.realWordAfterIndex != null) {
          info += "Antes de ${segment.realWordAfterIndex}\n";
        } else {
          info += "Al final del texto\n";
        }
      }
      info += "----------------------------------\n";
      segmentNumber++; // Incrementar el contador de segmentos
    }
    print("getAssociatedSegmentsInfo - Fin");
    return info;
  }

  int associateEliminatedWords(
    int transcribedIndex,
    List<Segment> closestRealSegments,
    String? closestRealWord,
    double minDistance,
    int levenshteinDistanceValue,
    int levenshteinThreshold,
    int realIndex,
  ) {
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length) {
      final transcribedSegment = transcribedSegments[transcribedIndex];
      if (closestRealSegments.isNotEmpty) {
        if (closestRealWord != null) {
          if (levenshteinDistanceValue <= levenshteinThreshold) {
            // Calcular la distancia de Levenshtein correcta
            int correctLevenshteinDistance = calculateLevenshteinDistance(transcribedSegment.word, closestRealWord);
            _createAndAddAssociatedSegment(
              transcribedSegment: transcribedSegment,
              realSegment: closestRealSegments.first,
              associationType: correctLevenshteinDistance <= 3 ? "Parecida" : "Eliminada",
              levenshteinDistance: correctLevenshteinDistance,
              realIndex: realIndex,
              transcribedIndex: transcribedIndex,
            );
            print(
              "associateEliminatedWords - Asociando: transcribedSegment.word: ${transcribedSegment.word}, realSegment.word: ${closestRealSegments.first.word}, realIndex: $realIndex, transcribedIndex: $transcribedIndex",
            );
            realIndex++;
          } else {
            _createAndAddAssociatedSegment(
              transcribedSegment: transcribedSegment,
              realSegment: null,
              associationType: "Eliminada",
              levenshteinDistance: levenshteinDistanceValue,
              realIndex: realIndex,
              transcribedIndex: transcribedIndex,
            );
            print(
              "associateEliminatedWords - Asociando: transcribedSegment.word: ${transcribedSegment.word}, realSegment.word: null, realIndex: $realIndex, transcribedIndex: $transcribedIndex",
            );
            realIndex++;
          }
        }
      }
    }
    return realIndex;
  }

  int associateInsertedWords(int transcribedIndex, List<Segment> closestRealSegments, double minDistance, int levenshteinDistanceValue, int realIndex) {
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length) {
      final transcribedSegment = transcribedSegments[transcribedIndex];
      _createAndAddAssociatedSegment(
        transcribedSegment: transcribedSegment,
        realSegment: null,
        associationType: "Insertada",
        levenshteinDistance: levenshteinDistanceValue,
        realIndex: realIndex,
        transcribedIndex: transcribedIndex,
      );
      print(
        "associateInsertedWords - Insertando: transcribedSegment.word: ${transcribedSegment.word}, realSegment.word: null, realIndex: $realIndex, transcribedIndex: $transcribedIndex",
      );
    }
    return realIndex;
  }

  void addUnassociatedInsertions() {
    print("addUnassociatedInsertions - Inicio");
    List<Segment> segmentsToAdd = [];
    // Iterar sobre los segmentos transcritos
    for (int transcribedIndex = 0; transcribedIndex < transcribedSegments.length; transcribedIndex++) {
      Segment transcribedSegment = transcribedSegments[transcribedIndex];
      // Verificar si la palabra transcrita ya está asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word);
      if (!alreadyAssociated) {
        print("addUnassociatedInsertions - Añadiendo inserción: ${transcribedSegment.word} en el indice $transcribedIndex");
        // Buscar las palabras asociadas cercanas en el texto real
        int? realWordBeforeIndex;
        int? realWordAfterIndex;
        // Buscar la palabra real antes de la insercion
        for (int i = 0; i < associatedSegments!.length; i++) {
          Segment currentSegment = associatedSegments![i];
          if (currentSegment.transcribedOrder != null && currentSegment.transcribedOrder! < transcribedIndex && currentSegment.realIndex != null) {
            if (realWordBeforeIndex == null || currentSegment.realIndex! > realWordBeforeIndex!) {
              realWordBeforeIndex = currentSegment.realIndex;
            }
          }
        }
        // Buscar la palabra real despues de la insercion
        for (int i = 0; i < associatedSegments!.length; i++) {
          Segment currentSegment = associatedSegments![i];
          if (currentSegment.transcribedOrder != null && currentSegment.transcribedOrder! > transcribedIndex && currentSegment.realIndex != null) {
            if (realWordAfterIndex == null || currentSegment.realIndex! < realWordAfterIndex!) {
              realWordAfterIndex = currentSegment.realIndex;
            }
          }
        }
        // Calcular la posición de la inserción en el texto real
        int? realOrder;
        if (realWordBeforeIndex != null && realWordAfterIndex != null) {
          realOrder = (realWordBeforeIndex + realWordAfterIndex) ~/ 2;
        } else if (realWordBeforeIndex != null) {
          realOrder = realWordBeforeIndex + 1;
        } else if (realWordAfterIndex != null) {
          realOrder = realWordAfterIndex - 1;
        } else {
          realOrder = associatedSegments!.length; // Si no hay contexto, al final
        }
        Segment associatedSegment = Segment(
          start: transcribedSegment.start,
          end: transcribedSegment.end,
          word: transcribedSegment.word,
          probability: transcribedSegment.probability,
          realWord: null, // Sin asociación real
          wordAssociation: null, // Sin asociación real
          transcribedWords: [transcribedSegment.word],
          transcribedWordsProbabilities: [transcribedSegment.probability],
          associationType: "Inserción",
          levenshteinDistance: 0,
          realIndex: null, // Sin índice real
          transcribedIndex: transcribedIndex, // Añadir el índice de la palabra transcrita
          transcribedOrder: transcribedIndex, // Añadir el orden de la palabra transcrita
          insertionOrder: null, // Añadir el orden de la insercion
          realOrder: realOrder, // Añadir el orden en el texto real
          realWordBeforeIndex: realWordBeforeIndex, // Añadir el índice de la palabra real antes
          realWordAfterIndex: realWordAfterIndex, // Añadir el índice de la palabra real después
        );
        segmentsToAdd.add(associatedSegment);
      } else {
        print("addUnassociatedInsertions - Ya asociado: ${transcribedSegment.word} en el indice $transcribedIndex");
      }
    }
    // Insertar las inserciones en la posición correcta
    for (Segment segmentToAdd in segmentsToAdd) {
      int insertIndex = 0;
      for (int i = 0; i < associatedSegments!.length; i++) {
        Segment currentSegment = associatedSegments![i];
        // Si ambos tienen realOrder, ordenar por realOrder
        if (segmentToAdd.realOrder != null && currentSegment.realOrder != null) {
          if (segmentToAdd.realOrder! < currentSegment.realOrder!) {
            insertIndex = i;
            break;
          } else {
            insertIndex = i + 1;
          }
        } else if (segmentToAdd.realOrder == null && currentSegment.realOrder == null) {
          if (segmentToAdd.transcribedOrder! < currentSegment.transcribedOrder!) {
            insertIndex = i;
            break;
          } else {
            insertIndex = i + 1;
          }
        } else if (segmentToAdd.realOrder != null) {
          insertIndex = i;
          break;
        } else {
          insertIndex = i + 1;
        }
      }
      // Insertar la inserción en la posición correcta
      associatedSegments!.insert(insertIndex, segmentToAdd);
    }
    // Asignar el insertionOrder a las inserciones
    int insertionOrder = 0;
    for (Segment segment in associatedSegments!) {
      if (segment.associationType == "Inserción") {
        segment.insertionOrder = insertionOrder;
        insertionOrder++;
      }
    }
    print("addUnassociatedInsertions - Fin");
  }

  void associateNearbyTranscribedWords(int transcribedIndex, String transcribedWord, bool isInserted, int correctLevenshteinDistance, String associationType) {
    print("associateNearbyTranscribedWords - Inicio");
    // Verificar si el índice está dentro de los límites
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length) {
      Segment transcribedSegment = transcribedSegments[transcribedIndex];
      // Verificar si la palabra ya está asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word);
      if (!alreadyAssociated) {
        // Crear WordAssociation
        WordAssociation wordAssociation = WordAssociation([transcribedSegment.word], null, [transcribedSegment.probability]);
        // Crear un nuevo segmento para la asociación
        Segment associatedSegment = Segment(
          start: transcribedSegment.start, // Usar el start del transcribedSegment
          end: transcribedSegment.end, // Usar el end del transcribedSegment
          word: transcribedSegment.word, // Usar la palabra del transcribedSegment
          probability: transcribedSegment.probability, // Usar la probabilidad del transcribedSegment
          realWord: null, // No hay palabra real asociada
          wordAssociation: wordAssociation,
          transcribedWords: [transcribedSegment.word],
          transcribedWordsProbabilities: [transcribedSegment.probability],
          associationType: associationType,
          levenshteinDistance: correctLevenshteinDistance,
          realIndex: null, // No hay índice real asociado
          transcribedIndex: transcribedIndex, // Añadir el índice de la palabra transcrita
          transcribedOrder: transcribedIndex, // Añadir el orden de la palabra transcrita
        );
        print(
          "associateNearbyTranscribedWords - Tipo de asociacion: ${associatedSegment.associationType}, correctLevenshteinDistance: $correctLevenshteinDistance, transcribedSegment.word: ${transcribedSegment.word}",
        );
        // Añadir el segmento a associatedSegments
        associatedSegments!.add(associatedSegment);
      } else {
        print("associateNearbyTranscribedWords - La palabra ${transcribedSegment.word} ya está asociada. No se asocia");
      }
    } else {
      print("associateNearbyTranscribedWords - Índice fuera de rango: transcribedIndex: $transcribedIndex");
    }
    print("associateNearbyTranscribedWords - Fin");
  }

  void associateForward(int index, String? transcribedWord, String type) {
    int maxDistance = 2; // Define la distancia máxima entre palabras
    for (int i = index + 1; i < transcribedSegments.length && i <= index + maxDistance; i++) {
      Segment currentTranscribedSegment = transcribedSegments[i];
      // Calcular el rango de búsqueda en el texto transcrito
      int searchRangeStart = i - 2; // Buscar 2 palabras antes
      int searchRangeEnd = i + 2; // Buscar 2 palabras después
      // Asegurarse de que el rango esté dentro de los límites
      searchRangeStart = searchRangeStart < 0 ? 0 : searchRangeStart;
      searchRangeEnd = searchRangeEnd > transcribedSegments.length ? transcribedSegments.length : searchRangeEnd;
      // Crear una sublista de segmentos transcritos para la búsqueda
      List<Segment> searchTranscribedSegments = transcribedSegments.sublist(searchRangeStart, searchRangeEnd);
      SearchParameters parameters = SearchParameters(levenshteinWeight: 1, contextWeight: 1, maxDistance: 5);
      Map<String, dynamic> result = findClosestSegments(transcribedWord!, searchTranscribedSegments, getContext(transcribedWords!, i, 2), parameters, false);
      List<Segment> closestTransSegments = result["closestSegments"].cast<Segment>();
      int levenshteinDistanceValue = result["levenshteinDistanceValue"];
      if (closestTransSegments.contains(currentTranscribedSegment) && levenshteinDistanceValue <= 3) {
        print("associateNearbyTranscribedWords - Associating nearby (forward) word: ${currentTranscribedSegment.word} to $transcribedWord");
        createAndAddAssociatedSegment(currentTranscribedSegment, transcribedWord, type);
      }
    }
  }

  void associateBackward(int index, String? transcribedWord, String type) {
    int maxDistance = 2; // Define la distancia máxima entre palabras
    for (int i = index - 1; i >= 0 && i >= index - maxDistance; i--) {
      Segment currentTranscribedSegment = transcribedSegments[i];
      // Calcular el rango de búsqueda en el texto transcrito
      int searchRangeStart = i - 2; // Buscar 2 palabras antes
      int searchRangeEnd = i + 2; // Buscar 2 palabras después
      // Asegurarse de que el rango esté dentro de los límites
      searchRangeStart = searchRangeStart < 0 ? 0 : searchRangeStart;
      searchRangeEnd = searchRangeEnd > transcribedSegments.length ? transcribedSegments.length : searchRangeEnd;
      // Crear una sublista de segmentos transcritos para la búsqueda
      List<Segment> searchTranscribedSegments = transcribedSegments.sublist(searchRangeStart, searchRangeEnd);
      SearchParameters parameters = SearchParameters(levenshteinWeight: 1, contextWeight: 1, maxDistance: 5);
      Map<String, dynamic> result = findClosestSegments(transcribedWord!, searchTranscribedSegments, getContext(transcribedWords!, i, 2), parameters, false);
      List<Segment> closestTransSegments = result["closestSegments"].cast<Segment>();
      int levenshteinDistanceValue = result["levenshteinDistanceValue"];
      if (closestTransSegments.contains(currentTranscribedSegment) && levenshteinDistanceValue <= 3) {
        print("associateNearbyTranscribedWords - Associating nearby (backward) word: ${currentTranscribedSegment.word} to $transcribedWord");
        createAndAddAssociatedSegment(currentTranscribedSegment, transcribedWord, type);
      }
    }
  }

  void createAndAddAssociatedSegment(Segment currentTranscribedSegment, String? transcribedWord, String type) {
    print("createAndAddAssociatedSegment - currentTranscribedSegment: ${currentTranscribedSegment.word}, transcribedWord: $transcribedWord, type: $type");
    // Buscar el segmento real correspondiente a la palabra transcrita
    Segment? realSegment;
    if (transcribedWord != null) {
      int realIndex = realTextWords!.indexOf(transcribedWord);
      if (realIndex != -1) {
        realSegment = realTextSegments![realIndex];
      }
    }
    // Crear WordAssociation
    WordAssociation wordAssociation = WordAssociation([currentTranscribedSegment.word], transcribedWord, [currentTranscribedSegment.probability]);
    // Crear un nuevo segmento para la asociación
    Segment associatedSegment = Segment(
      start: currentTranscribedSegment.start, // Usar el start del transcribedSegment
      end: currentTranscribedSegment.end, // Usar el end del transcribedSegment
      word: currentTranscribedSegment.word, // Usar la palabra del transcribedSegment
      probability: currentTranscribedSegment.probability, // Usar la probabilidad del transcribedSegment
      realWord: transcribedWord, // Usar la palabra real mas cercana
      wordAssociation: wordAssociation,
      transcribedWords: [currentTranscribedSegment.word],
      transcribedWordsProbabilities: [currentTranscribedSegment.probability],
      associationType: type,
      levenshteinDistance: 0,
    );
    // Añadir el segmento a associatedSegments
    associatedSegments!.add(associatedSegment);
  }

  bool shouldAssociate(Segment currentTranscribedSegment, String? realWord, String type, int maxLevenshteinDistance) {
    bool alreadyAssociated = associatedSegments!.any((element) => element.word == currentTranscribedSegment.word);
    if (alreadyAssociated) return false;

    String currentAssociationType = getType(currentTranscribedSegment.word, transcribedWords!, realTextWords!);
    if ((type == "inserted" && currentAssociationType == "coincidence") || (type == "eliminated" && currentAssociationType == "coincidence")) {
      return false;
    }
    if (realWord == null) return false;
    int levenshteinDistance = calculateLevenshteinDistance(currentTranscribedSegment.word, realWord);
    if (levenshteinDistance > maxLevenshteinDistance) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> findClosestSegments(
    String targetWord,
    List<Segment> segmentList,
    List<String> context,
    SearchParameters parameters,
    bool isTranscribedWord, {
    String? associatedRealWord,
  }) {
    print("findClosestSegments - targetWord: $targetWord");
    List<Segment> closestSegments = [];
    double bestTotalDistance = double.maxFinite;
    double minDistance = double.maxFinite;
    int levenshteinDistanceValue = 0;

    // Convertir la palabra objetivo a minúsculas
    String lowerCaseTargetWord = targetWord.toLowerCase();

    for (int i = 0; i < segmentList.length; i++) {
      Segment currentSegment = segmentList[i];
      //print("findClosestSegments - Checking currentSegment.word: ${currentSegment.word} at index $i");
      // Convertir la palabra actual a minúsculas
      String lowerCaseCurrentWord = currentSegment.word.toLowerCase();
      // Calcular la distancia de Levenshtein
      levenshteinDistanceValue = calculateLevenshteinDistance(lowerCaseTargetWord, lowerCaseCurrentWord);
      // Si la distancia de Levenshtein es mayor al umbral, no considerar esta palabra
      if (levenshteinDistanceValue > parameters.maxLevenshteinDistance) {
        //print("findClosestSegments - Levenshtein distance $levenshteinDistanceValue is greater than the threshold ${parameters.maxLevenshteinDistance}. Skipping word ${currentSegment.word}",);
        continue;
      }
      // Calcular la distancia de contexto
      int contextDistance = context.map((e) => e.toLowerCase()).contains(lowerCaseCurrentWord) ? 0 : 1;
      // Combinar las distancias (ajusta los pesos según sea necesario)
      double totalDistance = levenshteinDistanceValue * parameters.levenshteinWeight + (contextDistance * parameters.contextWeight);
      // Si hay una palabra real asociada, darle más peso a esa palabra
      if (associatedRealWord != null && lowerCaseCurrentWord == associatedRealWord.toLowerCase()) {
        totalDistance -= 3; // Reducir la distancia para darle más peso
      }
      // Si la palabra transcrita es muy corta, darle más peso a la posibilidad de que sea una fragmentación
      if (isTranscribedWord && parameters.targetWordLength != null && parameters.targetWordLength! <= 3) {
        totalDistance -= 1; // Reducir la distancia para darle más peso
      }
      // Si es una inserción, aplicar un umbral más estricto
      if (!isTranscribedWord && parameters.maxDistance != null && totalDistance > parameters.maxDistance!) {
        continue; // Saltar esta palabra si la distancia es demasiado grande
      }
      //print("findClosestSegments - Distance between $targetWord and ${currentSegment.word}: Levenshtein: $levenshteinDistanceValue, Context: $contextDistance, Total: $totalDistance",);
      if (totalDistance < bestTotalDistance) {
        bestTotalDistance = totalDistance;
        closestSegments = [currentSegment];
        minDistance = levenshteinDistanceValue.toDouble();
        print("findClosestSegments - New closest word: ${currentSegment.word}");
      }
    }
    print("findClosestSegments - Returning closest word: ${closestSegments.isNotEmpty ? closestSegments.first.word : null}");
    return {"closestSegments": closestSegments, "minDistance": minDistance, "levenshteinDistanceValue": levenshteinDistanceValue};
  }

  ////////////////////////////

  // Función para obtener el contexto
  List<String> getContext(List<String> listWords, int index, int contextRange) {
    int start = (index - contextRange) < 0 ? 0 : index - contextRange;
    int end = (index + contextRange) > listWords.length ? listWords.length : index + contextRange;
    return listWords.sublist(start, end);
  }

  // Función para obtener el tipo de palabra
  String getType(String word, List<String> listWordsTrascription, List<String> listWordsTexto) {
    String lowerCaseWord = word.toLowerCase();
    if (listWordsTrascription.map((e) => e.toLowerCase()).contains(lowerCaseWord)) {
      if (listWordsTexto.map((e) => e.toLowerCase()).contains(lowerCaseWord)) {
        return "coincidence";
      } else {
        return "inserted";
      }
    } else {
      return "eliminated";
    }
  }

  // Función para calcular la distancia de Levenshtein
  int calculateLevenshteinDistance(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    List<int> costs = List.generate(b.length + 1, (i) => i);
    for (int i = 1; i <= a.length; i++) {
      costs[0] = i;
      int upperLeft = i - 1;
      for (int j = 1; j <= b.length; j++) {
        int upper = costs[j];
        if (a[i - 1] == b[j - 1]) {
          costs[j] = upperLeft;
        } else {
          costs[j] = min(upperLeft, min(costs[j - 1], upper)) + 1;
        }
        upperLeft = upper;
      }
    }
    return costs[b.length];
  }

  // Función para obtener el texto real
  String? getRealText() {
    return realText;
  }
}

class SearchParameters {
  final int maxLevenshteinDistance;
  final double levenshteinWeight;
  final double contextWeight;
  final int? maxDistance;
  final int? targetWordLength;

  SearchParameters({this.maxLevenshteinDistance = 3, this.levenshteinWeight = 0.8, this.contextWeight = 2, this.maxDistance, this.targetWordLength});
}

class TranscriptionException implements Exception {
  final String message;

  TranscriptionException(this.message);

  @override
  String toString() => 'TranscriptionException: $message';
}
