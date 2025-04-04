import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/models/word_association.dart';

class Transcription {
  List<Segment> transcribedSegments; // Segmentos de la transcripción
  List<Segment>? realTextSegments; // Segmentos del texto real
  List<Segment>? associatedSegments; // Segmentos asociados (transcripción vs. texto real)
  String? fullTextTranscription; // Texto completo de la transcripción
  List<String>? transcribedWords; // Lista de palabras de la transcripción
  List<String>? realTextWords; // Lista de palabras del texto real
  List<Segment>? alignedSegments; // Segmentos alineados
  String? realText; // Texto real

  Transcription({
    required this.transcribedSegments,
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

      return Transcription(transcribedSegments: transcriptionSegments)
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
      realTextSegments: realTextSegments ?? this.realTextSegments,
      associatedSegments: associatedSegments ?? this.associatedSegments,
      fullTextTranscription: fullTextTranscription ?? this.fullTextTranscription,
      transcribedWords: transcriptionWords ?? this.transcribedWords,
      realTextWords: realTextWords ?? this.realTextWords,
      alignedSegments: alignedSegments ?? this.alignedSegments,
      realText: realText ?? this.realText,
    );
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

  String getAssociatedSegmentsInfo() {
    if (associatedSegments == null || realTextSegments == null) {
      throw TranscriptionException("No hay segmentos asociados o segmentos reales.");
    }

    StringBuffer buffer = StringBuffer();
    buffer.writeln("Información de Segmentos Asociados:");
    buffer.writeln("----------------------------------");

    for (Segment segment in associatedSegments!) {
      buffer.writeln("Palabra Transcrita: ${segment.word}");
      buffer.writeln("Palabra Real: ${segment.realWord ?? 'N/A'}");
      buffer.writeln("Tipo de Asociación: ${segment.associationType}");
      buffer.writeln("Distancia Levenshtein: ${segment.levenshteinDistance}");
      buffer.writeln("Probabilidad: ${segment.probability}");
      buffer.writeln("Inicio: ${segment.start}, Fin: ${segment.end}");
      if (segment.wordAssociation != null) {
        buffer.writeln("  Palabras Transcritas Asociadas: ${segment.wordAssociation!.transcribedWords.join(', ')}");
        buffer.writeln("  Probabilidades Asociadas: ${segment.wordAssociation!.transcribedWordsProbabilities.join(', ')}");
      }
      buffer.writeln("----------------------------------");
    }

    return buffer.toString();
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

  ///////////////

  void associateWords() {
    if (realTextSegments == null || transcribedSegments.isEmpty) {
      print("associateWords - realTextSegments o transcribedSegments son null o estan vacios. Saliendo de la función.");
      return;
    }
    realTextWords = realText!.split(' ');
    transcribedWords = transcribedSegments.map((e) => e.word).toList();
    associatedSegments = [];
    // Inicializar la lista de segmentos asociados
    associatedSegments = [];
    // Índice para recorrer realTextSegments
    int realIndex = 0;
    // Iterar sobre los segmentos transcritos
    for (int transcribedIndex = 0; transcribedIndex < transcribedSegments.length; transcribedIndex++) {
      Segment transcribedSegment = transcribedSegments[transcribedIndex];
      // Calcular el rango de búsqueda en el texto real
      int searchRangeStart = realIndex - 5; // Buscar 5 palabras antes
      int searchRangeEnd = realIndex + 5; // Buscar 5 palabras después
      // Asegurarse de que el rango esté dentro de los límites
      searchRangeStart = searchRangeStart < 0 ? 0 : searchRangeStart;
      searchRangeEnd = searchRangeEnd > realTextSegments!.length ? realTextSegments!.length : searchRangeEnd;
      // Crear una sublista de segmentos reales para la búsqueda
      List<Segment> searchRealSegments = realTextSegments!.sublist(searchRangeStart, searchRangeEnd);
      // Buscar la palabra real más cercana
      SearchParameters parameters = SearchParameters(targetWordLength: transcribedSegment.word.length);
      Map<String, dynamic> closestRealSegmentsData = findClosestSegments(
        transcribedSegment.word,
        searchRealSegments,
        getContext(realTextWords!, transcribedIndex, 2),
        parameters,
        true,
      );
      List<Segment> closestRealSegments = closestRealSegmentsData["closestSegments"].cast<Segment>();
      double minDistance = closestRealSegmentsData["minDistance"];
      int levenshteinDistanceValue = closestRealSegmentsData["levenshteinDistanceValue"];
      // Si se encontró una palabra real cercana
      if (closestRealSegments.isNotEmpty) {
        String? closestRealWord = closestRealSegments.first.word;
        // Si la palabra real más cercana es la misma que la palabra transcrita
        if (closestRealWord == transcribedSegment.word) {
          // Asociar las palabras como coincidentes
          associateCoincidentWords(transcribedIndex, realTextWords!.indexOf(closestRealWord));
          // Incrementar el índice real
          realIndex++;
        } else {
          // Asociar las palabras como eliminadas
          associateEliminatedWords(transcribedIndex, closestRealSegments, closestRealWord, minDistance, levenshteinDistanceValue);
          // Incrementar el índice real
          realIndex++;
        }
      } else {
        // Si no se encontró una palabra real cercana, buscar las palabras transcritas cercanas
        associateInsertedWords(transcribedIndex, closestRealSegments, minDistance, levenshteinDistanceValue);
      }
    }
    addUnassociatedInsertions();
  }

  void associateEliminatedWords(int transcribedIndex, List<Segment> closestRealSegments, String? closestRealWord, double minDistance, int levenshteinDistanceValue) {
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length) {
      final transcribedSegment = transcribedSegments[transcribedIndex];
      print("associateWords - Eliminada: transcribedSegment.word: ${transcribedSegment.word}, transcribedIndex: $transcribedIndex");

      if (closestRealSegments.isNotEmpty) {
        print("associateWords - Eliminada: closestRealWord: $closestRealWord");
        if (closestRealWord != null) {
          // Verificar si ya existe un segmento asociado para esta palabra
          bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == closestRealWord);
          if (!alreadyAssociated) {
            // Si la palabra real más cercana es la misma que la palabra transcrita (ignorando mayúsculas/minúsculas)
            if (closestRealWord.toLowerCase() == transcribedSegment.word.toLowerCase()) {
              // Asociar las palabras como coincidentes
              associateCoincidentWords(transcribedIndex, realTextWords!.indexOf(closestRealWord));
            } else {
              // Crear WordAssociation
              WordAssociation wordAssociation = WordAssociation([transcribedSegment.word], closestRealWord, [transcribedSegment.probability]);
              // Crear un nuevo segmento para la asociación
              Segment associatedSegment = Segment(
                start: closestRealSegments.first.start, // Usar el start del realSegment
                end: closestRealSegments.first.end, // Usar el end del realSegment
                word: transcribedSegment.word, // Usar la palabra del transcribedSegment
                probability: transcribedSegment.probability, // Usar la probabilidad del transcribedSegment
                realWord: closestRealWord, // Usar la palabra real mas cercana
                wordAssociation: wordAssociation,
                transcribedWords: [transcribedSegment.word],
                transcribedWordsProbabilities: [transcribedSegment.probability],
                associationType: "eliminacion",
                levenshteinDistance: levenshteinDistanceValue,
              );
              // Añadir el segmento a associatedSegments
              associatedSegments!.add(associatedSegment);
              // Agrupación de Segmentos Cercanos
              associateNearbyTranscribedWords(transcribedIndex, closestRealWord, false, levenshteinDistanceValue, "eliminated");
            }
          } else {
            // Si la palabra real ya está asociada, tratar la palabra transcrita como una inserción
            associateInsertedWords(transcribedIndex, closestRealSegments, minDistance, levenshteinDistanceValue);
          }
        }
      }
    }
  }

  void associateInsertedWords(int transcribedIndex, List<Segment> closestRealSegments, double minDistance, int levenshteinDistanceValue) {
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length) {
      final transcribedSegment = transcribedSegments[transcribedIndex];
      print("associateWords - Insertada: transcribedSegment.word: ${transcribedSegment.word}, transcribedIndex: $transcribedIndex");

      // Verificar si la palabra ya ha sido asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word);
      if (alreadyAssociated) return;

      // Verificar si hay palabras reales cercanas
      if (closestRealSegments.isNotEmpty) {
        // Intentar asociar a la palabra real más cercana
        Segment closestRealSegment = closestRealSegments.first;
        if (shouldAssociate(transcribedSegment, closestRealSegment.word, "inserted", levenshteinDistanceValue)) {
          createAndAddAssociatedSegment(transcribedSegment, closestRealSegment.word, "inserted");
          return; // Ya se asoció, no es una inserción pura
        }
      }

      // Si no se pudo asociar a una palabra real cercana, es una inserción pura
      Segment associatedSegment = Segment(
        start: transcribedSegment.start,
        end: transcribedSegment.end,
        word: transcribedSegment.word,
        probability: transcribedSegment.probability,
        realWord: null,
        wordAssociation: null,
        transcribedWords: [transcribedSegment.word],
        transcribedWordsProbabilities: [transcribedSegment.probability],
        associationType: "inserted",
        levenshteinDistance: 0,
      );
      associatedSegments!.add(associatedSegment);
      // Agrupación de Segmentos Cercanos
      associateNearbyTranscribedWords(transcribedIndex, transcribedSegment.word, true, levenshteinDistanceValue, "inserted");
    }
  }

  void associateCoincidentWords(int transcribedIndex, int realIndex) {
    if (transcribedIndex >= 0 && transcribedIndex < transcribedSegments.length && realIndex >= 0 && realIndex < realTextWords!.length) {
      final transcribedSegment = transcribedSegments[transcribedIndex];
      final realWord = realTextWords![realIndex];
      print("associateWords - Coincidente: transcribedSegment.word: ${transcribedSegment.word}, realWord: $realWord, transcribedIndex: $transcribedIndex, realIndex: $realIndex");
      // Verificar si ya existe un segmento asociado para esta palabra
      bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == realWord && element.word == transcribedSegment.word);
      if (!alreadyAssociated) {
        // Crear WordAssociation
        WordAssociation wordAssociation = WordAssociation([transcribedSegment.word], realWord, [transcribedSegment.probability]);
        // Crear un nuevo segmento para la asociación
        Segment associatedSegment = Segment(
          start: transcribedSegment.start, // Usar el start del transcribedSegment
          end: transcribedSegment.end, // Usar el end del transcribedSegment
          word: transcribedSegment.word, // Usar la palabra del transcribedSegment
          probability: transcribedSegment.probability, // Usar la probabilidad del transcribedSegment
          realWord: realWord, // Usar la palabra real
          wordAssociation: wordAssociation,
          transcribedWords: [transcribedSegment.word],
          transcribedWordsProbabilities: [transcribedSegment.probability],
          associationType: "coincidencia",
          levenshteinDistance: 0,
        );
        // Añadir el segmento a associatedSegments
        associatedSegments!.add(associatedSegment);
      }
    }
  }

  void addUnassociatedInsertions() {
    for (Segment transcribedSegment in transcribedSegments) {
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == transcribedSegment.word);
      if (!alreadyAssociated) {
        Segment associatedSegment = Segment(
          start: transcribedSegment.start,
          end: transcribedSegment.end,
          word: transcribedSegment.word,
          probability: transcribedSegment.probability,
          realWord: null, // Sin asociación real
          wordAssociation: null, // Sin asociación real
          transcribedWords: [transcribedSegment.word],
          transcribedWordsProbabilities: [transcribedSegment.probability],
          associationType: "insercion",
          levenshteinDistance: 0,
        );
        associatedSegments!.add(associatedSegment);
      }
    }
  }

  ////////
  // Función para agrupar palabras transcritas cercanas
  //
  /*void associateNearbyTranscribedWords(int transcribedIndex, String? realWord, bool isInserted, int levenshteinDistanceValue, String associationType) {
    int maxDistance = 2; // Define la distancia máxima entre palabras
    int maxLevenshteinDistance = 3; // Define la distancia máxima de Levenshtein
    if (isInserted || levenshteinDistanceValue > maxLevenshteinDistance) {
      return;
    }
    associateForward(transcribedIndex, realWord, associationType);
    associateBackward(transcribedIndex, realWord, associationType);
  }*/

  void associateNearbyTranscribedWords(int transcribedIndex, String word, bool isInserted, int levenshteinDistanceValue, String type) {
    // Implementar la lógica de asociación de palabras cercanas aquí
    // Puedes usar transcribedIndex para acceder a las palabras cercanas en transcribedSegments
    // Puedes usar word para comparar con las palabras cercanas en realTextWords
    // Puedes usar isInserted para saber si la palabra es una inserción
    // Puedes usar levenshteinDistanceValue para la distancia maxima
    // Puedes usar type para saber si es una insercion o eliminacion
    // Ejemplo:
    print("associateNearbyTranscribedWords - transcribedIndex: $transcribedIndex, word: $word, isInserted: $isInserted, levenshteinDistanceValue: $levenshteinDistanceValue, type: $type");
  }

  void associateForward(int index, String? realWord, String type) {
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
      Map<String, dynamic> result = findClosestSegments(realWord!, searchTranscribedSegments, getContext(transcribedWords!, i, 2), parameters, false);
      List<Segment> closestTransSegments = result["closestSegments"].cast<Segment>();
      int levenshteinDistanceValue = result["levenshteinDistanceValue"];
      if (closestTransSegments.contains(currentTranscribedSegment) && levenshteinDistanceValue <= 3) {
        print("associateNearbyTranscribedWords - Associating nearby (forward) word: ${currentTranscribedSegment.word} to $realWord");
        createAndAddAssociatedSegment(currentTranscribedSegment, realWord, type);
      }
    }
  }

  void associateBackward(int index, String? realWord, String type) {
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
      Map<String, dynamic> result = findClosestSegments(realWord!, searchTranscribedSegments, getContext(transcribedWords!, i, 2), parameters, false);
      List<Segment> closestTransSegments = result["closestSegments"].cast<Segment>();
      int levenshteinDistanceValue = result["levenshteinDistanceValue"];
      if (closestTransSegments.contains(currentTranscribedSegment) && levenshteinDistanceValue <= 3) {
        print("associateNearbyTranscribedWords - Associating nearby (backward) word: ${currentTranscribedSegment.word} to $realWord");
        createAndAddAssociatedSegment(currentTranscribedSegment, realWord, type);
      }
    }
  }

  void createAndAddAssociatedSegment(Segment currentTranscribedSegment, String? realWord, String type) {
    WordAssociation wordAssociation = WordAssociation([currentTranscribedSegment.word], realWord, [currentTranscribedSegment.probability]);
    Segment associatedSegment = Segment(
      start: currentTranscribedSegment.start,
      end: currentTranscribedSegment.end,
      word: currentTranscribedSegment.word,
      probability: currentTranscribedSegment.probability,
      realWord: realWord,
      wordAssociation: wordAssociation,
      transcribedWords: [currentTranscribedSegment.word],
      transcribedWordsProbabilities: [currentTranscribedSegment.probability],
      associationType: type, // Usar el tipo directamente
      levenshteinDistance: realWord != null ? calculateLevenshteinDistance(currentTranscribedSegment.word, realWord) : 0,
    );
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
  ///////

  ///////////////////////
  // Función para encontrar la palabra más cercana (genérica)
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
      print("findClosestSegments - Checking currentSegment.word: ${currentSegment.word} at index $i");
      // Convertir la palabra actual a minúsculas
      String lowerCaseCurrentWord = currentSegment.word.toLowerCase();
      // Calcular la distancia de Levenshtein
      levenshteinDistanceValue = calculateLevenshteinDistance(lowerCaseTargetWord, lowerCaseCurrentWord);
      // Si la distancia de Levenshtein es mayor al umbral, no considerar esta palabra
      if (levenshteinDistanceValue > parameters.maxLevenshteinDistance) {
        print(
          "findClosestSegments - Levenshtein distance $levenshteinDistanceValue is greater than the threshold ${parameters.maxLevenshteinDistance}. Skipping word ${currentSegment.word}",
        );
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
      print(
        "findClosestSegments - Distance between $targetWord and ${currentSegment.word}: Levenshtein: $levenshteinDistanceValue, Context: $contextDistance, Total: $totalDistance",
      );
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
  int calculateLevenshteinDistance(String a, String? b) {
    if (b == null) return 0; // Si b es null, la distancia es 0
    String lowerCaseA = a.toLowerCase();
    String lowerCaseB = b.toLowerCase();
    if (lowerCaseA.isEmpty) {
      return lowerCaseB.length;
    }
    if (lowerCaseB.isEmpty) {
      return lowerCaseA.length;
    }
    List<int> previousRow = List.generate(lowerCaseB.length + 1, (i) => i);
    for (int i = 0; i < lowerCaseA.length; i++) {
      List<int> currentRow = [i + 1];
      for (int j = 0; j < lowerCaseB.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (lowerCaseA[i] != lowerCaseB[j] ? 1 : 0);
        currentRow.add([insertions, deletions, substitutions].reduce((a, b) => a < b ? a : b));
      }
      previousRow = currentRow;
    }
    return previousRow.last;
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
