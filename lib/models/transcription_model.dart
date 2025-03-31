import 'package:collection/collection.dart';
import 'package:transcriber_whisper/models/patience_diff_js.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/models/word_association.dart';

class Transcription {
  final List<Segment> transsegments;
  final List<Segment>? realsegments;
  List<Segment>? associatedSegments; // Nueva lista para las asociaciones
  final String? fulltext;
  final List<String>? listWordsTrascription;
  final List<String>? listWordsTexto;
  List<Segment>? alignedSegments;

  Transcription({required this.transsegments, this.realsegments, this.associatedSegments, this.fulltext, this.listWordsTrascription, this.listWordsTexto, this.alignedSegments});

  factory Transcription.fromListMap(dynamic listmap, {bool generateFullText = true, String text = ""}) {
    List<Segment> transsegments = [];
    List<Segment> realsegments = [];
    List<Segment> associatedSegments = []; // Initialize as empty list
    String fullTextTranscription = "";
    List<String> textoEscritoListwords = []; // Initialize as empty list
    List<String> transcriptionListwords = []; // Initialize as empty list
    double currentTime = 0.0;

    if (text.isNotEmpty) {
      // Remove punctuation
      text = text.replaceAll(RegExp(r'[^\w\s]'), '');
      // Replace multiple spaces with single space
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      // Replace newlines with single space
      text = text.replaceAll(RegExp(r'[\r\n]+'), ' ');
      // Trim leading and trailing whitespace
      text = text.trim();
      // Convert to lowercase
      text = text.toLowerCase();
      // Split into words
      textoEscritoListwords = text.split(' ').where((word) => word.isNotEmpty).toList();
    }

    if (listmap is List) {
      //print("segmentos previstos en texto original: ${textoEscritoListwords.length}");
      //print("textoEscritoListwords: $textoEscritoListwords");
      //print("segmentos previstos en la trascripción: ${listmap.length}");

      for (int i = 0; i < listmap.length; i++) {
        var e = listmap[i];
        if (e is Map<String, dynamic>) {
          Segment segment = Segment.fromMap(e);
          transsegments.add(segment);

          String word = e["word"];
          //print("Palabra original en la transcripción: $word");
          // Remove punctuation
          word = word.replaceAll(RegExp(r'[^\w\s]'), '');
          // Replace multiple spaces with single space
          word = word.replaceAll(RegExp(r'\s+'), ' ');
          // Replace newlines with single space
          word = word.replaceAll(RegExp(r'[\r\n]+'), ' ');
          // Trim leading and trailing whitespace
          word = word.trim();
          word = word.toLowerCase();
          //print("Palabra procesada en la transcripción: $word");
          //Eliminar palabras que no deberian estar
          //if (word.length > 2) { //Eliminada
          transcriptionListwords.add(word);
          //} //Eliminada

          if (generateFullText) {
            fullTextTranscription += "${e["word"]} ";
          }
        } else {
          throw FormatException("Error: Elemento no es un mapa: $e");
        }
      }
      //Eliminar palabras repetidas //Eliminada
      //transcriptionListwords = transcriptionListwords.toSet().toList(); //Eliminada
      //print("transcriptionListwords: $transcriptionListwords");

      if (textoEscritoListwords.isNotEmpty) {
        // Iterate over the words in the written text
        int segmentIndex = 0;
        for (String writtenWord in textoEscritoListwords) {
          bool foundMatch = false;
          double start = currentTime;
          double end = currentTime + 0.5;
          realsegments.add(Segment(start: start, end: end, word: writtenWord, probability: 1.0));
          currentTime = end;
        }
      }
    }

    return Transcription(
      transsegments: transsegments,
      realsegments: realsegments,
      associatedSegments: associatedSegments,
      fulltext: fullTextTranscription,
      listWordsTrascription: transcriptionListwords,
      listWordsTexto: textoEscritoListwords,
      alignedSegments: [],
    );
  }

  Transcription copyWith({
    List<Segment>? transsegments,
    List<Segment>? realsegments,
    List<Segment>? associatedSegments,
    String? fulltext,
    List<String>? listWordsTrascription,
    List<String>? listWordsTexto,
    List<Segment>? alignedSegments
  }) {
    return Transcription(
      transsegments: transsegments ?? this.transsegments,
      realsegments: realsegments ?? this.realsegments,
      associatedSegments: associatedSegments ?? this.associatedSegments,
      fulltext: fulltext ?? this.fulltext,
      listWordsTrascription: listWordsTrascription ?? this.listWordsTrascription,
      listWordsTexto: listWordsTexto ?? this.listWordsTexto,
      alignedSegments: alignedSegments ?? this.alignedSegments
    );
  }

  List<Segment> alignSegmentsToRealText() {
    if (realsegments == null || associatedSegments == null) {
      print("Error: realsegments or associatedSegments is null");
      return [];
    }

    List<Segment> alignedSegments = [];
    int insertionIndex = 0; // Índice para las inserciones

    // Iterar sobre las palabras del texto real
    for (int i = 0; i < realsegments!.length; i++) {
      Segment realSegment = realsegments![i];
      List<String> transcribedWords = [];
      List<double> probabilities = [];
      String? associationType;
      int? levenshteinDistance;

      // Buscar las palabras transcritas asociadas a la palabra real
      List<Segment> associatedToReal = associatedSegments!
          .where((segment) => segment.realWord == realSegment.word)
          .toList();

      // Si hay palabras transcritas asociadas, agregarlas al segmento
      if (associatedToReal.isNotEmpty) {
        for (Segment associatedSegment in associatedToReal) {
          transcribedWords.add(associatedSegment.word);
          probabilities.add(associatedSegment.probability);
          associationType = associatedSegment.associationType;
          levenshteinDistance = associatedSegment.levenshteinDistance;
        }
      }

      // Crear el segmento para la palabra real
      alignedSegments.add(
        Segment(
          realWord: realSegment.word,
          transcribedWords: transcribedWords,
          transcribedWordsProbabilities: probabilities,
          associationType: associationType,
          levenshteinDistance: levenshteinDistance,
          start: realSegment.start,
          end: realSegment.end,
          word: "", // No necesitamos la palabra transcrita aquí
          probability: 0.0, // No necesitamos la probabilidad aquí
        ),
      );

      // Intercalar las inserciones
      while (insertionIndex < associatedSegments!.length) {
        Segment insertionSegment = associatedSegments![insertionIndex];
        // Si la palabra tiene realWord, no es una insercion
        if (insertionSegment.realWord != null) {
          insertionIndex++;
          continue;
        }
        // Si la inserción está antes de la siguiente palabra real, insertarla
        if (insertionSegment.start < (i + 1 < realsegments!.length ? realsegments![i + 1].start : double.infinity)) {
          alignedSegments.add(
            Segment(
              realWord: null,
              transcribedWords: [insertionSegment.word],
              transcribedWordsProbabilities: [insertionSegment.probability],
              associationType: insertionSegment.associationType,
              levenshteinDistance: insertionSegment.levenshteinDistance,
              start: insertionSegment.start,
              end: insertionSegment.end,
              word: insertionSegment.word, // Usamos la palabra de la inserción
              probability: insertionSegment.probability, // Usamos la probabilidad de la inserción
            ),
          );
          insertionIndex++;
        } else {
          break; // La inserción va después de la palabra real actual
        }
      }
    }

    // Agregar las inserciones restantes al final
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
            word: insertionSegment.word, // Usamos la palabra de la inserción
            probability: insertionSegment.probability, // Usamos la probabilidad de la inserción
          ),
        );
      }
      insertionIndex++;
    }

    // Ordenar la lista por start
    alignedSegments.sort((a, b) => a.start.compareTo(b.start));
    this.alignedSegments = alignedSegments; // Asignar a la propiedad
    return alignedSegments;
  }

  // Función para mostrar los segmentos asociados
  void printAssociatedSegments() {
    if (associatedSegments == null || realsegments == null) {
      print("No hay segmentos asociados o segmentos reales.");
      return;
    }

    // Agrupar los segmentos asociados por palabra real
    Map<String, List<Segment>> groupedSegments = {};
    for (Segment segment in associatedSegments!) {
      if (segment.realWord != null) {
        if (!groupedSegments.containsKey(segment.realWord)) {
          groupedSegments[segment.realWord!] = [];
        }
        groupedSegments[segment.realWord!]!.add(segment);
      } else {
        // Manejar segmentos sin realWord (inserciones no asociadas)
        if (!groupedSegments.containsKey("Inserciones no asociadas")) {
          groupedSegments["Inserciones no asociadas"] = [];
        }
        groupedSegments["Inserciones no asociadas"]!.add(segment);
      }
    }

    // Ordenar los segmentos por el start
    List<MapEntry<String, List<Segment>>> sortedEntries =
        groupedSegments.entries.toList()..sort((a, b) {
          if (a.key == "Inserciones no asociadas") return 1; // Poner "Inserciones no asociadas" al final
          if (b.key == "Inserciones no asociadas") return -1; // Poner "Inserciones no asociadas" al final
          return a.value.first.start.compareTo(b.value.first.start);
        });

    // Imprimir los segmentos agrupados
    int segmentCount = 1;
    for (MapEntry<String, List<Segment>> entry in sortedEntries) {
      String realWord = entry.key;
      List<Segment> segments = entry.value;
      // Eliminar duplicados
      List<Segment> uniqueSegments = segments.toSet().toList();
      print("Segmento $segmentCount ($realWord):");
      List<String> transcribedWords = [];
      List<double> probabilities = [];
      String? associationType = "";
      int? levenshteinDistance = 0;
      for (Segment segment in uniqueSegments) {
        transcribedWords.add(segment.word);
        probabilities.add(segment.probability);
        associationType = segment.associationType;
        levenshteinDistance = segment.levenshteinDistance;
      }
      print("  Palabras Transcritas Asociadas: $transcribedWords");
      print("  Probabilidades: $probabilities");
      print("  Tipo de Asociación: $associationType");
      print("  Distancia de Levenshtein: $levenshteinDistance");
      segmentCount++;
    }
  }

  // Función para agrupar palabras transcritas cercanas
  void associateNearbyTranscribedWords(int index, String realWord, bool isCoincidence, int levenshteinDistanceValue, String type) {
    int maxDistance = 2; // Define la distancia máxima entre palabras
    int maxLevenshteinDistance = 3; // Define la distancia máxima de Levenshtein
    if (isCoincidence) {
      return;
    }
    if (levenshteinDistanceValue > maxLevenshteinDistance) {
      return;
    }
    // Buscar palabras posteriores
    for (int i = index + 1; i < transsegments.length && i <= index + maxDistance; i++) {
      Segment currentTransSegment = transsegments[i];
      // Verificar si la palabra ya está asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == currentTransSegment.word);
      if (!alreadyAssociated) {
        // Verificar el tipo de palabra actual
        String currentType = getType(currentTransSegment.word, listWordsTrascription!, listWordsTexto!);
        if (type == "inserted" && currentType == "coincidence") {
          continue; // No asociar palabras insertadas con palabras coincidentes
        }
        if (type == "eliminated" && currentType == "coincidence") {
          continue; // No asociar palabras eliminadas con palabras coincidentes
        }
        int levenshteinDistance = levenshteinDistanceF(currentTransSegment.word, realWord);
        if (levenshteinDistance > maxLevenshteinDistance) {
          continue; // No asociar palabras con una distancia de Levenshtein mayor al umbral
        }
        print("associateNearbyTranscribedWords - Associating nearby (forward) word: ${currentTransSegment.word} to $realWord");
        // Crear WordAssociation
        WordAssociation wordAssociation = WordAssociation([currentTransSegment.word], realWord, [currentTransSegment.probability]);
        // Crear un nuevo segmento para la asociación
        Segment associatedSegment = Segment(
          // Corregido aquí
          start: currentTransSegment.start, // Usar el start del transSegment
          end: currentTransSegment.end, // Usar el end del transSegment
          word: currentTransSegment.word, // Usar la palabra del transSegment
          probability: currentTransSegment.probability, // Usar la probabilidad del transSegment
          realWord: realWord, // Usar la palabra real
          wordAssociation: wordAssociation,
          transcribedWords: [currentTransSegment.word],
          transcribedWordsProbabilities: [currentTransSegment.probability],
          associationType: type == "inserted" ? "insercion cercana" : "eliminacion cercana",
          levenshteinDistance: levenshteinDistance,
        );
        // Añadir el segmento a associatedSegments
        associatedSegments!.add(associatedSegment);
      }
    }
    // Buscar palabras anteriores
    for (int i = index - 1; i >= 0 && i >= index - maxDistance; i--) {
      Segment currentTransSegment = transsegments[i];
      // Verificar si la palabra ya está asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == currentTransSegment.word);
      if (!alreadyAssociated) {
        // Verificar el tipo de palabra actual
        String currentType = getType(currentTransSegment.word, listWordsTrascription!, listWordsTexto!);
        if (type == "inserted" && currentType == "coincidence") {
          continue; // No asociar palabras insertadas con palabras coincidentes
        }
        if (type == "eliminated" && currentType == "coincidence") {
          continue; // No asociar palabras eliminadas con palabras coincidentes
        }
        int levenshteinDistance = levenshteinDistanceF(currentTransSegment.word, realWord);
        if (levenshteinDistance > maxLevenshteinDistance) {
          continue; // No asociar palabras con una distancia de Levenshtein mayor al umbral
        }
        print("associateNearbyTranscribedWords - Associating nearby (backward) word: ${currentTransSegment.word} to $realWord");
        // Crear WordAssociation
        WordAssociation wordAssociation = WordAssociation([currentTransSegment.word], realWord, [currentTransSegment.probability]);
        // Crear un nuevo segmento para la asociación
        Segment associatedSegment = Segment(
          // Corregido aquí
          start: currentTransSegment.start, // Usar el start del transSegment
          end: currentTransSegment.end, // Usar el end del transSegment
          word: currentTransSegment.word, // Usar la palabra del transSegment
          probability: currentTransSegment.probability, // Usar la probabilidad del transSegment
          realWord: realWord, // Usar la palabra real
          wordAssociation: wordAssociation,
          transcribedWords: [currentTransSegment.word],
          transcribedWordsProbabilities: [currentTransSegment.probability],
          associationType: type == "inserted" ? "insercion cercana" : "eliminacion cercana",
          levenshteinDistance: levenshteinDistance,
        );
        // Añadir el segmento a associatedSegments
        associatedSegments!.add(associatedSegment);
      }
    }
  }

  void associateWords() {
    if (realsegments == null || listWordsTrascription == null || listWordsTexto == null) {
      print("Error: realsegments, listWordsTrascription or listWordsTexto is null");
      return;
    }
    // Inicializar associatedSegments
    associatedSegments = [];
    List<String> associatedWords = [];
    // 1. Preprocesamiento (ya realizado en fromListMap)

    //print("listWordsTexto --> $listWordsTexto");
    //print("listWordsTrascription --> $listWordsTrascription");

    // 2. Alineamiento Inicial (PatienceDiffJs)
    final diff = PatienceDiffJs(listWordsTrascription!, listWordsTexto!, true);
    final result = diff.patienceDiffJs();

    // 3. Análisis de Inserciones y Eliminaciones
    for (var o in result['lines']) {
      if (o['bIndex'] < 0) {
        // Eliminada
        final aIndex = o['aIndex'];
        if (aIndex >= 0 && aIndex < transsegments.length) {
          final transSegment = transsegments[aIndex];
          print("associateWords - Eliminada: transSegment.word: ${transSegment.word}, aIndex: $aIndex");
          // Buscar la palabra real más cercana
          Map<String, dynamic> closestRealSegmentsResult = findClosestRealSegments(
            transSegment.word,
            realsegments!,
            null,
            transSegment.word.length,
            getContext(listWordsTrascription!, aIndex, 2),
          );
          List<Segment> closestRealSegments = closestRealSegmentsResult["closestSegments"];
          double minDistance = closestRealSegmentsResult["minDistance"];
          int levenshteinDistanceValue = closestRealSegmentsResult["levenshteinDistanceValue"];
          if (closestRealSegments.isNotEmpty) {
            String? closestRealWord = closestRealSegments.first.word;
            print("associateWords - Eliminada: closestRealWord: $closestRealWord");
            if (closestRealWord != null) {
              associatedWords.add(closestRealWord);
              // Verificar si ya existe un segmento asociado para esta palabra
              bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == closestRealWord && element.word == transSegment.word);
              if (!alreadyAssociated) {
                // Crear WordAssociation
                WordAssociation wordAssociation = WordAssociation([transSegment.word], closestRealWord, [transSegment.probability]);
                // Crear un nuevo segmento para la asociación
                Segment associatedSegment = Segment(
                  start: closestRealSegments.first.start, // Usar el start del realSegment
                  end: closestRealSegments.first.end, // Usar el end del realSegment
                  word: transSegment.word, // Usar la palabra del transSegment
                  probability: transSegment.probability, // Usar la probabilidad del transSegment
                  realWord: closestRealWord, // Usar la palabra real mas cercana
                  wordAssociation: wordAssociation,
                  transcribedWords: [transSegment.word],
                  transcribedWordsProbabilities: [transSegment.probability],
                  associationType: "eliminacion",
                  levenshteinDistance: levenshteinDistanceValue,
                );
                // Añadir el segmento a associatedSegments
                associatedSegments!.add(associatedSegment);
                // Agrupación de Segmentos Cercanos
                associateNearbyTranscribedWords(aIndex, closestRealWord, false, levenshteinDistanceValue, "eliminated");
              }
            }
          }
        }
      } else if (o['aIndex'] < 0) {
        // Insertada
        final bIndex = o['bIndex'];
        if (bIndex >= 0 && bIndex < realsegments!.length) {
          final transSegment = transsegments[o['bIndex']];
          final realSegment = realsegments![bIndex];
          print("associateWords - Insertada: transSegment.word: ${transSegment.word}, bIndex: $bIndex");
          // Buscar las palabras transcritas cercanas
          List<Segment> closestTransSegments = findClosestTransSegments(realSegment.word, transsegments, getContext(listWordsTexto!, bIndex, 2), true);
          List<String> transcribedWords = closestTransSegments.map((e) => e.word).toList();
          List<double> transcribedWordsProbabilities = closestTransSegments.map((e) => e.probability).toList();
          if (closestTransSegments.isNotEmpty) {
            String? closestTransWord = closestTransSegments.first.word;
            int levenshteinDistanceValue = levenshteinDistanceF(realSegment.word, closestTransWord!);
            if (closestTransWord != null) {
              associatedWords.add(realSegment.word);
              // Verificar si ya existe un segmento asociado para esta palabra real y esta palabra transcrita
              bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == realSegment.word && element.word == transSegment.word);
              if (!alreadyAssociated) {
                // Crear WordAssociation
                WordAssociation wordAssociation = WordAssociation(transcribedWords, realSegment.word, transcribedWordsProbabilities);
                // Crear un nuevo segmento para la asociación
                Segment associatedSegment = Segment(
                  start: transSegment.start, // Usar el start del transSegment
                  end: transSegment.end, // Usar el end del transSegment
                  word: transSegment.word, // Usar la palabra del trans
                  probability: transcribedWordsProbabilities.isNotEmpty ? transcribedWordsProbabilities.first : 0.0, // Usar la probabilidad del transSegment
                  realWord: realSegment.word, // Usar la palabra real
                  wordAssociation: wordAssociation,
                  transcribedWords: transcribedWords,
                  transcribedWordsProbabilities: transcribedWordsProbabilities,
                  associationType: "insercion",
                  levenshteinDistance: levenshteinDistanceValue,
                );
                // Añadir el segmento a associatedSegments
                associatedSegments!.add(associatedSegment);
                // Agrupación de Segmentos Cercanos
                associateNearbyTranscribedWords(o['bIndex'], realSegment.word, false, levenshteinDistanceValue, "inserted");
              }
            }
          } else {
            // No se encontró una palabra cercana, crear un segmento sin asociación real
            // Verificar si ya existe un segmento asociado para esta palabra transcrita
            bool alreadyAssociated = associatedSegments!.any((element) => element.word == transSegment.word);
            if (!alreadyAssociated) {
              Segment associatedSegment = Segment(
                start: transSegment.start,
                end: transSegment.end,
                word: transSegment.word,
                probability: transSegment.probability,
                realWord: null, // Sin asociación real
                wordAssociation: null, // Sin asociación real
                transcribedWords: [transSegment.word],
                transcribedWordsProbabilities: [transSegment.probability],
                associationType: "insercion",
                levenshteinDistance: 0,
              );
              associatedSegments!.add(associatedSegment);
              // Agrupación de Segmentos Cercanos
              associateNearbyTranscribedWords(o['bIndex'], "", false, 0, "inserted");
            }
          }
        }
      } else {
        // Coincidencia
        final aIndex = o['aIndex'];
        final bIndex = o['bIndex'];
        if (aIndex >= 0 && aIndex < transsegments.length && bIndex >= 0 && bIndex < realsegments!.length) {
          final transSegment = transsegments[aIndex];
          final realSegment = realsegments![bIndex];
          int levenshteinDistanceValue = levenshteinDistanceF(transSegment.word, realSegment.word);
          print("associateWords - Coincidencia: transSegment.word: ${transSegment.word}, realSegment.word: ${realSegment.word}, aIndex: $aIndex, bIndex: $bIndex");
          // Verificar si ya existe un segmento asociado para esta palabra real y esta palabra transcrita
          bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == realSegment.word && element.word == transSegment.word);
          if (!alreadyAssociated) {
            // Crear WordAssociation
            WordAssociation wordAssociation = WordAssociation([transSegment.word], realSegment.word, [transSegment.probability]);
            // Crear un nuevo segmento para la asociación
            Segment associatedSegment = Segment(
              start: transSegment.start, // Usar el start del transSegment
              end: transSegment.end, // Usar el end del transSegment
              word: transSegment.word, // Usar la palabra del transSegment
              probability: transSegment.probability, // Usar la probabilidad del transSegment
              realWord: realSegment.word, // Usar la palabra real
              wordAssociation: wordAssociation,
              transcribedWords: [transSegment.word],
              transcribedWordsProbabilities: [transSegment.probability],
              associationType: "coincidencia",
              levenshteinDistance: levenshteinDistanceValue,
            );
            // Añadir el segmento a associatedSegments
            associatedSegments!.add(associatedSegment);
          }
        }
      }
    }
    // Agregar inserciones no asociadas
    for (Segment transSegment in transsegments) {
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == transSegment.word);
      if (!alreadyAssociated) {
        Segment associatedSegment = Segment(
          start: transSegment.start,
          end: transSegment.end,
          word: transSegment.word,
          probability: transSegment.probability,
          realWord: null, // Sin asociación real
          wordAssociation: null, // Sin asociación real
          transcribedWords: [transSegment.word],
          transcribedWordsProbabilities: [transSegment.probability],
          associationType: "insercion",
          levenshteinDistance: 0,
        );
        associatedSegments!.add(associatedSegment);
      }
    }
  }

  // Función para obtener el contexto
  List<String> getContext(List<String> listWords, int index, int contextRange) {
    int start = (index - contextRange) < 0 ? 0 : index - contextRange;
    int end = (index + contextRange) > listWords.length ? listWords.length : index + contextRange; // Corrección aquí
    return listWords.sublist(start, end); // Corrección aquí
  }

  // Función para obtener el tipo de palabra
  String getType(String word, List<String> listWordsTrascription, List<String> listWordsTexto) {
    // Aquí puedes implementar la lógica para determinar si una palabra es insertada, eliminada o coincidencia
    // Por ahora, simplemente devolvemos "unknown"
    if (listWordsTrascription.contains(word) && listWordsTexto.contains(word)) {
      return "coincidence";
    } else if (listWordsTrascription.contains(word) && !listWordsTexto.contains(word)) {
      return "inserted";
    } else if (!listWordsTrascription.contains(word) && listWordsTexto.contains(word)) {
      return "eliminated";
    } else {
      return "unknown";
    }
  }
}

// Función para calcular la distancia de Levenshtein
int levenshteinDistanceF(String a, String b) {
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
      int substitutions = previousRow[j] + (a[i] != b[j] ? 1 : 0);
      currentRow.add([insertions, deletions, substitutions].reduce((a, b) => a < b ? a : b));
    }
    previousRow = currentRow;
  }
  return previousRow.last;
}

// Función para encontrar la palabra real más cercana
Map<String, dynamic> findClosestRealSegments(String transcribedWord, List<Segment> realSegments, String? associatedRealWord, int transcribedWordLength, List<String> context) {
  print("findClosestRealSegments - transcribedWord: $transcribedWord");
  List<Segment> closestSegments = [];
  double bestTotalDistance = double.maxFinite;
  double minDistance = double.maxFinite;
  int levenshteinDistanceValue = 0;
  int maxLevenshteinDistance = 3; // Define la distancia máxima de Levenshtein
  for (int i = 0; i < realSegments.length; i++) {
    Segment realSegment = realSegments[i];
    print("findClosestRealSegments - Checking realSegment.word: ${realSegment.word} at index $i");
    // Calcular la distancia de Levenshtein
    levenshteinDistanceValue = levenshteinDistanceF(transcribedWord, realSegment.word);
    // Si la distancia de Levenshtein es mayor al umbral, no considerar esta palabra
    if (levenshteinDistanceValue > maxLevenshteinDistance) {
      print("findClosestRealSegments - Levenshtein distance $levenshteinDistanceValue is greater than the threshold $maxLevenshteinDistance. Skipping word ${realSegment.word}");
      continue;
    }
    // Calcular la distancia de contexto
    int contextDistance = 0;
    if (context.contains(realSegment.word)) {
      contextDistance = 0;
    } else {
      contextDistance = 1;
    }
    // Combinar las distancias (ajusta los pesos según sea necesario)
    double totalDistance = levenshteinDistanceValue * 0.8 + (contextDistance * 2); // Damos mas peso a la distancia de Levenshtein
    // Si hay una palabra real asociada, darle más peso a esa palabra
    if (associatedRealWord != null && realSegment.word == associatedRealWord) {
      totalDistance -= 3; // Reducir la distancia para darle más peso
    }
    // Si la palabra transcrita es muy corta, darle más peso a la posibilidad de que sea una fragmentación
    if (transcribedWordLength <= 3) {
      totalDistance -= 1; // Reducir la distancia para darle más peso
    }
    print(
      "findClosestRealSegments - Distance between $transcribedWord and ${realSegment.word}: Levenshtein: $levenshteinDistanceValue, Context: $contextDistance, Total: $totalDistance",
    );
    if (totalDistance < bestTotalDistance) {
      bestTotalDistance = totalDistance;
      closestSegments = [realSegment];
      minDistance = levenshteinDistanceValue.toDouble(); // Corregido aquí
      print("findClosestRealSegments - New closest word: ${realSegment.word}");
    }
  }
  print("findClosestRealSegments - Returning closest word: ${closestSegments.isNotEmpty ? closestSegments.first.word : null}");
  return {"closestSegments": closestSegments, "minDistance": minDistance, "levenshteinDistanceValue": levenshteinDistanceValue};
}

// Función para encontrar las palabras transcritas más cercanas
List<Segment> findClosestTransSegments(String realWord, List<Segment> transSegments, List<String> context, bool isInsertion) {
  print("findClosestTransSegments - realWord: $realWord");
  List<Segment> closestSegments = [];
  int minDistance = double.maxFinite.toInt();
  int maxDistance = 5; // Aumentamos el maxDistance
  int maxLevenshteinDistance = 3; // Define la distancia máxima de Levenshtein
  for (Segment transSegment in transSegments) {
    int distance = levenshteinDistanceF(realWord, transSegment.word);
    // Si la distancia de Levenshtein es mayor al umbral, no considerar esta palabra
    if (distance > maxLevenshteinDistance) {
      print("findClosestTransSegments - Levenshtein distance $distance is greater than the threshold $maxLevenshteinDistance. Skipping word ${transSegment.word}");
      continue;
    }
    // Calcular la distancia de contexto
    int contextDistance = 0;
    if (context.contains(transSegment.word)) {
      contextDistance = 0;
    } else {
      contextDistance = 1;
    }
    distance += contextDistance * 1; // Ajustamos el peso del contexto
    // Si es una inserción, aplicar un umbral más estricto
    if (isInsertion && distance > maxDistance) {
      continue; // Saltar esta palabra si la distancia es demasiado grande
    }
    print("findClosestTransSegments - Distance between $realWord and ${transSegment.word}: $distance");
    if (distance < minDistance) {
      minDistance = distance;
      closestSegments = [transSegment];
      print("findClosestTransSegments - New closest word: ${transSegment.word}");
    }
  }
  print("findClosestTransSegments - Returning closest word: ${closestSegments.isNotEmpty ? closestSegments.first.word : null}");
  return closestSegments;
}
