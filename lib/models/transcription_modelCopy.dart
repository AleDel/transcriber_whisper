import 'package:transcriber_whisper/models/patience_diff_js.dart';
import 'package:transcriber_whisper/models/segment.dart';
import 'package:transcriber_whisper/models/word_association.dart';
import 'package:collection/collection.dart';

class Transcription {
  final List<Segment> transsegments;
  final List<Segment>? realsegments;
  List<Segment>? associatedSegments; // Nueva lista para las asociaciones
  final String? fulltext;
  final List<String>? listWordsTrascription;
  final List<String>? listWordsTexto;

  Transcription({required this.transsegments, this.realsegments, this.associatedSegments, this.fulltext, this.listWordsTrascription, this.listWordsTexto});

  factory Transcription.fromListMap(dynamic listmap, {bool generateFullText = true, String text = ""}) {
    List<Segment> transsegments = [];
    List<Segment> realsegments = [];
    List<Segment> associatedSegments = []; // Initialize as empty list
    String fullTextTranscription = "";
    List<String> textoEscritoListwords = []; // Initialize as empty list
    List<String> transcriptionListwords = []; // Initialize as empty list

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
        double currentTime = 0.0;
        for (String writtenWord in textoEscritoListwords) {
          bool foundMatch = false;
          realsegments.add(Segment(start: 0, end: 0, word: writtenWord, probability: 0.0));
        }
      }
    } else {
      throw FormatException("Error: No es una lista");
    }
    return Transcription(
      transsegments: transsegments,
      realsegments: text.isNotEmpty ? realsegments : null,
      associatedSegments: text.isNotEmpty ? associatedSegments : null,
      fulltext: generateFullText ? fullTextTranscription : null,
      listWordsTrascription: transcriptionListwords,
      listWordsTexto: textoEscritoListwords,
    );
  }

  Transcription copyWith({
    List<Segment>? transsegments,
    List<Segment>? realsegments,
    List<Segment>? associatedSegments,
    String? fulltext,
    List<String>? listWordsTrascription,
    List<String>? listWordsTexto,
  }) {
    return Transcription(
      transsegments: transsegments ?? this.transsegments,
      realsegments: realsegments ?? this.realsegments,
      associatedSegments: associatedSegments ?? this.associatedSegments,
      fulltext: fulltext ?? this.fulltext,
      listWordsTrascription: listWordsTrascription ?? this.listWordsTrascription,
      listWordsTexto: listWordsTexto ?? this.listWordsTexto,
    );
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
    final diff = PatienceDiffJs(listWordsTrascription!, listWordsTexto!, false);
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
              // Verificar si ya existe un segmento asociado para esta palabra real
              bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == closestRealWord);
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
                );
                // Añadir el segmento a associatedSegments
                associatedSegments!.add(associatedSegment);
                // Agrupación de Segmentos Cercanos
                associateNearbyTranscribedWords(aIndex, closestRealWord, false, levenshteinDistanceValue);
              }
            }
          }
        }
      } else if (o['aIndex'] < 0) {
        // Insertada
        final bIndex = o['bIndex'];
        if (bIndex >= 0 && bIndex < realsegments!.length) {
          final realSegment = realsegments![bIndex];
          print("associateWords - Insertada: realSegment.word: ${realSegment.word}, bIndex: $bIndex");
          // Verificar si ya existe un segmento asociado para esta palabra real
          bool alreadyAssociated = associatedSegments!.any((element) => element.realWord == realSegment.word);
          if (!alreadyAssociated) {
            // Buscar las palabras transcritas cercanas
            List<Segment> closestTransSegments = findClosestTransSegments(realSegment.word, transsegments, getContext(listWordsTexto!, bIndex, 2));
            List<String> transcribedWords = closestTransSegments.map((e) => e.word).toList();
            List<double> transcribedWordsProbabilities = closestTransSegments.map((e) => e.probability).toList();
            if (closestTransSegments.isNotEmpty) {
              String? closestTransWord = closestTransSegments.first.word;
              if (closestTransWord != null) {
                associatedWords.add(realSegment.word);
                // Crear WordAssociation
                WordAssociation wordAssociation = WordAssociation(transcribedWords, realSegment.word, transcribedWordsProbabilities);
                // Crear un nuevo segmento para la asociación
                Segment associatedSegment = Segment(
                  start: realSegment.start, // Usar el start del realSegment
                  end: realSegment.end, // Usar el end del realSegment
                  word: closestTransWord, // Usar la palabra del transSegment
                  probability: transcribedWordsProbabilities.isNotEmpty ? transcribedWordsProbabilities.first : 0.0, // Usar la probabilidad del transSegment
                  realWord: realSegment.word, // Usar la palabra real
                  wordAssociation: wordAssociation,
                  transcribedWords: transcribedWords,
                  transcribedWordsProbabilities: transcribedWordsProbabilities,
                );
                // Añadir el segmento a associatedSegments
                associatedSegments!.add(associatedSegment);
              }
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
          print("associateWords - Coincidencia: transSegment.word: ${transSegment.word}, realSegment.word: ${realSegment.word}, aIndex: $aIndex, bIndex: $bIndex");
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
          );
          // Añadir el segmento a associatedSegments
          associatedSegments!.add(associatedSegment);
          // Agrupación de Segmentos Cercanos
          associateNearbyTranscribedWords(aIndex, realSegment.word, true, 0);
        }
      }
    }
  }

  // Función para agrupar palabras transcritas cercanas
  void associateNearbyTranscribedWords(int index, String realWord, bool isCoincidence, int levenshteinDistanceValue) {
    int maxDistance = 2; // Define la distancia máxima entre palabras
    if (isCoincidence) {
      return;
    }
    if (levenshteinDistanceValue < 3) {
      return;
    }
    // Buscar palabras posteriores
    for (int i = index + 1; i < transsegments.length && i <= index + maxDistance; i++) {
      Segment currentTransSegment = transsegments[i];
      // Verificar si la palabra ya está asociada
      bool alreadyAssociated = associatedSegments!.any((element) => element.word == currentTransSegment.word);
      if (!alreadyAssociated) {
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
        );
        // Añadir el segmento a associatedSegments
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

  // Función para mostrar los segmentos asociados
  void printAssociatedSegments() {
    if (associatedSegments == null) {
      print("No hay segmentos asociados.");
      return;
    }
    // Agrupar los segmentos asociados por palabra real
    Map<String, List<Segment>> groupedSegments = {};
    for (Segment segment in associatedSegments!) {
      if (!groupedSegments.containsKey(segment.realWord)) {
        groupedSegments[segment.realWord!] = [];
      }
      groupedSegments[segment.realWord!]!.add(segment);
    }
    // Imprimir los segmentos agrupados
    int segmentCount = 1;
    for (MapEntry<String, List<Segment>> entry in groupedSegments.entries) {
      String realWord = entry.key;
      List<Segment> segments = entry.value;
      print("Segmento $segmentCount ($realWord):");
      List<String> transcribedWords = [];
      List<double> probabilities = [];
      for (Segment segment in segments) {
        transcribedWords.add(segment.word);
        probabilities.add(segment.probability);
      }
      print("  Palabras Transcritas Asociadas: $transcribedWords");
      print("  Probabilidades: $probabilities");
      segmentCount++;
    }
  }
}

// Función de similitud fonética (ejemplo con Levenshtein distance)
int levenshteinDistance(String a, String b) {
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
  for (int i = 0; i < realSegments.length; i++) {
    Segment realSegment = realSegments[i];
    print("findClosestRealSegments - Checking realSegment.word: ${realSegment.word} at index $i");
    // Calcular la distancia de Levenshtein
    levenshteinDistanceValue = levenshteinDistance(transcribedWord, realSegment.word);
    // Calcular la distancia de contexto
    int contextDistance = 0;
    if (context.contains(realSegment.word)) {
      contextDistance = 0;
    } else {
      contextDistance = 1;
    }
    // Combinar las distancias (ajusta los pesos según sea necesario)
    double totalDistance = levenshteinDistanceValue + (contextDistance * 2); // Damos menos peso a la distancia de contexto
    // Si hay una palabra real asociada, darle más peso a esa palabra
    if (associatedRealWord != null && realSegment.word == associatedRealWord) {
      totalDistance -= 3; // Reducir la distancia para darle más peso
    }
    // Si la palabra transcrita es muy corta, darle más peso a la posibilidad de que sea una fragmentación
    if (transcribedWordLength <= 3) {
      totalDistance -= 2; // Reducir la distancia para darle más peso
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
List<Segment> findClosestTransSegments(String realWord, List<Segment> transSegments, List<String> context) {
  print("findClosestTransSegments - realWord: $realWord");
  List<Segment> closestSegments = [];
  int minDistance = double.maxFinite.toInt();
  for (Segment transSegment in transSegments) {
    int distance = levenshteinDistance(realWord, transSegment.word);
    // Calcular la distancia de contexto
    int contextDistance = 0;
    if (context.contains(transSegment.word)) {
      contextDistance = 0;
    } else {
      contextDistance = 1;
    }
    distance += contextDistance * 2;
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
