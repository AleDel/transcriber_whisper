import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/segment_context_menu.dart';
import 'package:transcriber_whisper/transcribe_state.dart';
import 'package:transcriber_whisper/utils/compare_segments_utils.dart';

import 'mockData/textotest.dart';
import 'models/alignment_mfa_data.dart';
import 'models/comparation_model.dart';
import 'models/patience_diff.dart';
import 'models/patience_diff_js.dart';
import 'models/segment.dart';
import 'models/word_with_spans.dart';

class _BuildWordSpansResult {
  final List<TextSpan> spans;
  final DiffType diffType;

  _BuildWordSpansResult({required this.spans, required this.diffType});
}

/// Representa el resultado de la función [_prepareLists].
class _PrepareListsResult {
  /// La nueva lista de palabras transcritas.
  final List<String> newTransWords;

  /// La nueva lista de palabras reales.
  final List<String> newRealWords;

  /// Constructor de [_PrepareListsResult].
  _PrepareListsResult(this.newTransWords, this.newRealWords);
}

class TranscribeCubit extends Cubit<TranscribeState> {
  TranscribeCubit() : super(const TranscribeState(status: TranscribeStatus.initial)) {
    //initSocket();
    initAudioPlayer();
  }

  final ScrollController scrollController = ScrollController();
  final AudioPlayer audioPlayer = AudioPlayer();
  late IO.Socket socket;
  Transcription? transcription;
  String textoRealformadoparrafos = "";
  //Transcription? realtextComoTranscription;
  AlignmentMFAData? alignmentData_texto; // alineamiento del audio con el texto escrito
  bool _autoScrollEnabled = true;
  bool _userSelectedWord = false;
  bool _isPlayingWord = false;
  Timer? _wordPlayTimer;
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;

  static Map<String, Color> availableTags = {
    'Omisioa': Colors.red[200]!,
    'Ordezkapena': Colors.green[200]!,
    'Asmaketa': Colors.blue[200]!,
    'Berrirakurtzea': Colors.purple[200]!,
    'Zuzenketa': Colors.orange[200]!,
    'Gehikuntza': Colors.pink[200]!,
    'Inbertsioa': Colors.yellow[200]!,
    'Jauzia': Colors.teal[200]!,
    'Errepikapena': Colors.indigo[200]!,
  };
  static Map<String, String> tagToSymbol = {
    'Omisioa': '-',
    'Ordezkapena': 'O',
    'Asmaketa': 'A',
    'Berrirakurtzea': 'B',
    'Zuzenketa': 'Z',
    'Gehikuntza': '+',
    'Inbertsioa': 'I',
    'Jauzia': 'J',
    'Errepikapena': 'E',
  };

  void initSocket() {
    socket = IO.io('http://192.168.1.10:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });
    socket.onConnect((_) {
      print('connect');
      emit(state.copyWith(status: TranscribeStatus.loaded));
    });
    socket.onDisconnect((_) => print('disconnect'));
    socket.on('connect_error', (data) {
      print('connect_error: $data');
      emit(state.copyWith(status: TranscribeStatus.noserver));
    });
    socket.on('connect_timeout', (data) {
      print('connect_timeout: $data');
      emit(state.copyWith(status: TranscribeStatus.noserver));
    });
  }

  void initAudioPlayer() {
    audioPlayer.onDurationChanged.listen((Duration d) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioDuration: d)));
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioPosition: p)));
      updateCurrentWord();
    });
    audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (s == PlayerState.playing) {
        emit(state.copyWith(status: TranscribeStatus.isPlayerplaying));
      } else if (s == PlayerState.paused) {
        emit(state.copyWith(status: TranscribeStatus.isPlayerpause));
      } else if (s == PlayerState.stopped) {
        emit(state.copyWith(status: TranscribeStatus.isPlayerstopped));
      } else if (s == PlayerState.completed) {
        emit(state.copyWith(status: TranscribeStatus.isPlayercompleted));
      }
    });
    audioPlayer.onPlayerComplete.listen((event) {
      emit(state.copyWith(status: TranscribeStatus.isPlayercompleted));
    });
  }

  Future<void> alignAudio(PlatformFile audioFile, String text) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final url = Uri.parse('http://127.0.0.1:5000/align');
      var request = http.MultipartRequest('POST', url);

      // Añadir el texto como un campo de formulario
      request.fields['text'] = text;

      // Añadir el archivo de audio como un campo de formulario
      Uint8List? fileBytes;
      if (audioFile.bytes != null) {
        fileBytes = audioFile.bytes;
      } else if (audioFile.path != null) {
        fileBytes = await File(audioFile.path!).readAsBytes();
      } else {
        throw Exception("No se pudo leer el archivo");
      }

      // Verificar si fileBytes es nulo
      if (fileBytes == null) {
        throw Exception("No se pudo leer el archivo");
      }

      var multipartFile = http.MultipartFile.fromBytes(
        'audio', // Nombre del campo en el servidor
        fileBytes.toList(),
        filename: audioFile.name,
        contentType: MediaType('application', 'octet-stream'), // Tipo de contenido
      );
      request.files.add(multipartFile);

      // Enviar la solicitud
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        print(jsonResponse);
        // ... procesar la respuesta
        emit(state.copyWith(status: TranscribeStatus.loaded));
      } else {
        print("Error en la respuesta: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
        throw Exception('Failed to align audio');
      }
    } catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error));
    }
  }

  Future<void> transcribeAudio(PlatformFile audioFile) async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    try {
      final url = Uri.parse('http://127.0.0.1:5001/transcribe');
      //final url = Uri.parse('https://infanciadigital.duckdns.org/transcriber/transcribe');
      final headers = {'Content-Type': 'application/octet-stream'};
      Uint8List? fileBytes;
      String audioFilePath = "";
      if (audioFile.path != null) {
        audioFilePath = audioFile.path!;
      }
      if (audioFile.bytes != null) {
        fileBytes = audioFile.bytes;
      } else if (audioFile.path != null) {
        fileBytes = await File(audioFile.path!).readAsBytes();
      } else {
        throw Exception("No se pudo leer el archivo");
      }

      final response = await http.post(url, headers: headers, body: fileBytes);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        transcription = Transcription.fromListMap(jsonResponse['transcription']);
        //fullTextTranscription = _transcription!.fulltext!;
        //melSpectrogramBase64 = jsonResponse['mel_spectrogram'];
        //waveformImageBase64 = jsonResponse['waveform_image'];

        //realtextComoTranscription = Transcription(segments: transcription!.realsegments!);
        //compararActualTranscription();
        //calculateWordsWithSpans(transcription!); // Add this line

        emit(
          state.copyWith(
            status: TranscribeStatus.loaded,
            transcription: transcription,
            //realtextComoTranscription: realtextComoTranscription,
            //melSpectrogramBase64: melSpectrogramBase64,
            //samples: samples,
            //waveformImageBase64: waveformImageBase64,
          ),
        );
        //await audioPlayer.play(audioFilePath, isLocal: true);

        await audioPlayer.setSource(DeviceFileSource(audioFilePath));
        //await loadSamples(audioFilePath);
      } else {
        print('Error: ${response.statusCode}');
        emit(state.copyWith(status: TranscribeStatus.error, errorMessage: "Error en la respuesta: ${response.statusCode}"));
      }
    } catch (e) {
      String errorMessage = "Error desconocido";
      if (e is SocketException) {
        errorMessage = "Error de conexión a internet";
      } else if (e is HttpException) {
        errorMessage = "Error de comunicación con el servidor";
      } else if (e is Exception) {
        errorMessage = e.toString();
      }
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error, errorMessage: errorMessage));
    } finally {
      emit(state.copyWith(status: TranscribeStatus.loaded));
    }
  }

  Future<void> pickAudioFile() async {
    print("hola");
    //FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result != null) {
      //File file = File(result.files.single.path!);
      PlatformFile file = result.files.single;
      ///////////transcribeAudio(file);
      transcribeAudio(file);
      //alignAudio(file, "Nadie te puede salvar");
    } else {
      // User canceled the picker, do nothing
      print("User canceled the picker");
    }
  }

  Future<AlignmentMFAData?> loadAlignmentMFAData() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/texto_align_ITSAS_IZARRAK.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      alignmentData_texto = AlignmentMFAData.fromMap(jsonMap);
      print("Alignment data loaded successfully");
      print("alignmentData lista de words ---> ${alignmentData_texto?.tiers["words"]!.entries.length}");
      print("alignmentData lista de phones ---> ${alignmentData_texto?.tiers["phones"]!.entries.length}");
      emit(state.copyWith(textoEscritoAlineado: alignmentData_texto));
      return alignmentData_texto;
    } catch (e) {
      print('Error loading alignment data: $e');
    }
    return null;
  }

  /////////////////////
  // New method to calculate WordWithSpans

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

  //1
  /*List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();

    print("transWords --> $transWords");
    print("realWords --> $realWords");

    String transcribedText = transWords.join(" ");
    String realText = realWords.join(" ");

    // Remove punctuation, multiple spaces, newlines, trim, and lowercase
    transcribedText = transcribedText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();
    realText = realText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();

    final diffs = diff(transcribedText, realText);
    final List<List<TextSpan>> allSpans = [];
    List<TextSpan> currentWordSpans = [];
    String currentWord = "";
    String currentRealWord = "";
    int transWordIndex = 0;
    int realWordIndex = 0;
    final formattedWords = transcribedText.split(" ");
    bool isInsert = false;
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
        isInsert = true;
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.0);
      }

      for (int i = 0; i < diff.text.length; i++) {
        final char = diff.text[i];
        currentWordSpans.add(TextSpan(text: char, style: TextStyle(backgroundColor: color)));
        currentWord += char;
        if (realWordIndex < realWords.length) {
          currentRealWord += char;
        }
        if (isInsert) {
          if (transWordIndex < formattedWords.length && currentWord == formattedWords[transWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            transWordIndex++;
            isInsert = false;
          }
        } else {
          if (realWordIndex < realWords.length && currentRealWord == realWords[realWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            currentRealWord = "";
            realWordIndex++;
          }
        }
      }
    }
    if (currentWordSpans.isNotEmpty) {
      allSpans.add(List.from(currentWordSpans));
    }

    int index = 0;
    List<WordWithSpans> wordsWithSpans = [];
    transWordIndex = 0;
    realWordIndex = 0;
    List<TextSpan> accumulatedSpans = [];
    String accumulatedRealWord = "";
    String accumulatedWord = "";
    DiffType accumulatedDiffType = DiffType.equal;
    for (int i = 0; i < formattedWords.length; i++) {
      String formattedWord = formattedWords[i];
      String transWord = "";
      String realWord = "";
      if (transWordIndex < transWords.length) {
        transWord = transWords[transWordIndex];
      }
      if (realWordIndex < realWords.length) {
        realWord = realWords[realWordIndex];
      }
      List<TextSpan> wordSpans = [];
      if (formattedWord == realWord) {
        final result = _buildWordSpans(formattedWord, formattedWord);
        wordSpans = result.spans;
        if (accumulatedSpans.isNotEmpty) {
          wordsWithSpans.add(WordWithSpans(word: accumulatedWord, realWord: accumulatedRealWord, index: index, spans: accumulatedSpans, diffType: accumulatedDiffType, wordColor: _getWordColorFromSpans(accumulatedSpans)));
          accumulatedSpans = [];
          accumulatedRealWord = "";
          accumulatedWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
        }
        wordsWithSpans.add(WordWithSpans(word: formattedWord, realWord: realWord, index: index, spans: wordSpans, diffType: DiffType.equal, wordColor: Colors.green.withOpacity(0.5)));
        transWordIndex++;
        realWordIndex++;
        index++;
      } else {
        if (i < allSpans.length) {
          wordSpans = allSpans[i];
        } else {
          final result = _buildWordSpans(transWord, realWord);
          wordSpans = result.spans;
        }
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedRealWord.isEmpty) {
          accumulatedRealWord = realWord;
        } else {
          accumulatedRealWord += " " + realWord;
        }
        if (accumulatedWord.isEmpty) {
          accumulatedWord = formattedWord;
        }
        accumulatedDiffType = _getDiffTypeFromSpans(accumulatedSpans);
        transWordIndex++;
        if (transWordIndex < transWords.length && realWordIndex < realWords.length && formattedWord != realWords[realWordIndex]) {
          if (realWords.length > realWordIndex + 1 && transWords[transWordIndex] == realWords[realWordIndex + 1]) {
            realWordIndex++;
          }
        }
        if (transWordIndex < transWords.length && realWordIndex < realWords.length && formattedWord != realWords[realWordIndex]) {
          if (transWords[transWordIndex] == realWords[realWordIndex]) {
            wordsWithSpans.add(WordWithSpans(word: accumulatedWord, realWord: accumulatedRealWord, index: index, spans: accumulatedSpans, diffType: accumulatedDiffType, wordColor: _getWordColorFromSpans(accumulatedSpans)));
            accumulatedSpans = [];
            accumulatedRealWord = "";
            accumulatedWord = "";
            accumulatedDiffType = DiffType.equal;
            index++;
          }
        }
      }
    }
    if (accumulatedSpans.isNotEmpty) {
      wordsWithSpans.add(WordWithSpans(word: accumulatedWord, realWord: accumulatedRealWord, index: index, spans: accumulatedSpans, diffType: accumulatedDiffType, wordColor: _getWordColorFromSpans(accumulatedSpans)));
    }
    return wordsWithSpans;
  }

  ({List<TextSpan> spans, DiffType diffType, Color wordColor}) _buildWordSpans(String oldWord, String newWord) {
    final diffs = diff(oldWord, newWord);
    final spans = <TextSpan>[];
    DiffType diffType = DiffType.equal;
    Color wordColor = Colors.green.withOpacity(0.5);
    bool hasInsert = false;
    bool hasDelete = false;
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
        hasDelete = true;
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
        hasInsert = true;
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.5);
      }
      for (int i = 0; i < diff.text.length; i++) {
        final char = diff.text[i];
        spans.add(TextSpan(text: char, style: TextStyle(backgroundColor: color)));
      }
    }
    if (hasInsert && hasDelete) {
      diffType = DiffType.both;
      wordColor = Colors.purple.withOpacity(0.5);
    } else if (hasInsert) {
      diffType = DiffType.insert;
      wordColor = Colors.blue.withOpacity(0.5);
    } else if (hasDelete) {
      diffType = DiffType.delete;
      wordColor = Colors.red.withOpacity(0.5);
    } else {
      diffType = DiffType.equal;
      wordColor = Colors.green.withOpacity(0.5);
    }
    return (spans: spans, diffType: diffType, wordColor: wordColor);
  }*/

  //2
  /*
  List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();

    print("transWords --> $transWords");
    print("realWords --> $realWords");

    String transcribedText = transWords.join(" ");
    String realText = realWords.join(" ");

    // Remove punctuation, multiple spaces, newlines, trim, and lowercase
    transcribedText = transcribedText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();
    realText = realText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();

    final diffs = diff(transcribedText, realText);
    final List<List<TextSpan>> allSpans = [];
    List<TextSpan> currentWordSpans = [];
    String currentWord = "";
    String currentRealWord = "";
    int transWordIndex = 0;
    int realWordIndex = 0;
    final formattedWords = transcribedText.split(" ");
    bool isInsert = false;
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
        isInsert = true;
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.0);
      }

      for (int i = 0; i < diff.text.length; i++) {
        final char = diff.text[i];
        currentWordSpans.add(TextSpan(text: char, style: TextStyle(backgroundColor: color)));
        currentWord += char;
        if (realWordIndex < realWords.length) {
          currentRealWord += char;
        }
        if (isInsert) {
          if (transWordIndex < formattedWords.length && currentWord == formattedWords[transWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            transWordIndex++;
            isInsert = false;
          }
        } else {
          if (realWordIndex < realWords.length && currentRealWord == realWords[realWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            currentRealWord = "";
            realWordIndex++;
          }
        }
      }
    }
    if (currentWordSpans.isNotEmpty) {
      allSpans.add(List.from(currentWordSpans));
    }

    int index = 0;
    List<WordWithSpans> wordsWithSpans = [];
    transWordIndex = 0;
    realWordIndex = 0;
    List<TextSpan> accumulatedSpans = [];
    String accumulatedRealWord = "";
    String accumulatedWord = "";
    DiffType accumulatedDiffType = DiffType.equal;
    String previousRealWord = "";
    while (transWordIndex < transWords.length || realWordIndex < realWords.length) {
      String transWord = transWordIndex < transWords.length ? transWords[transWordIndex] : "";
      String realWord = realWordIndex < realWords.length ? realWords[realWordIndex] : "";
      List<TextSpan> wordSpans = [];
      if (transWord == realWord) {
        final result = _buildWordSpans(transWord, realWord);
        wordSpans = result.spans;
        if (accumulatedSpans.isNotEmpty) {
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: accumulatedRealWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedRealWord = "";
          accumulatedWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
        }
        wordsWithSpans.add(WordWithSpans(word: transWord, realWord: realWord, index: index, spans: wordSpans, diffType: DiffType.equal, wordColor: Colors.green.withOpacity(0.5)));
        transWordIndex++;
        realWordIndex++;
        index++;
        previousRealWord = realWord;
        continue;
      }
      if (transWord == previousRealWord && previousRealWord.isNotEmpty) {
        final result = _buildWordSpans(transWord, transWord);
        wordSpans = result.spans;
        if (accumulatedSpans.isNotEmpty) {
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: accumulatedRealWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedRealWord = "";
          accumulatedWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
        }
        wordsWithSpans.add(WordWithSpans(word: transWord, realWord: transWord, index: index, spans: wordSpans, diffType: DiffType.equal, wordColor: Colors.green.withOpacity(0.5)));
        transWordIndex++;
        realWordIndex++;
        index++;
        previousRealWord = realWord;
        continue;
      }
      if (realWord.isEmpty) {
        final result = _buildWordSpans(transWord, transWords[transWordIndex]);
        wordSpans = result.spans;
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedWord.isEmpty) {
          accumulatedWord = transWord;
        }
        accumulatedDiffType = _getDiffTypeFromSpans(accumulatedSpans);
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord.isEmpty ? transWords[transWordIndex] : accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedWord = "";
        accumulatedRealWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        transWordIndex++;
        previousRealWord = "";
        continue;
      }
      if (transWord.isEmpty) {
        final result = _buildWordSpans("", realWord);
        wordSpans = result.spans;
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedRealWord.isEmpty) {
          accumulatedRealWord = realWord;
        }
        accumulatedDiffType = _getDiffTypeFromSpans(accumulatedSpans);
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedRealWord = "";
        accumulatedWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        realWordIndex++;
        previousRealWord = "";
        continue;
      }
      if (realWord.isNotEmpty && !transWords.contains(transWord)) {
        final result = _buildWordSpans(transWord, transWords[transWordIndex]);
        wordSpans = result.spans;
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedWord.isEmpty) {
          accumulatedWord = transWord;
        }
        accumulatedDiffType = DiffType.insertWord;
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord.isEmpty ? transWords[transWordIndex] : accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedWord = "";
        accumulatedRealWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        transWordIndex++;
        previousRealWord = "";
        continue;
      }
      bool foundSimilarInRealWords = false;
      String similarWord = "";
      for (String w in realWords) {
        if (_isSimilar(transWord, w)) {
          foundSimilarInRealWords = true;
          similarWord = w;
          break;
        }
      }
      if (!foundSimilarInRealWords) {
        if (transWordIndex < allSpans.length) {
          wordSpans = allSpans[transWordIndex];
        } else {
          final result = _buildWordSpans(transWord, transWords[transWordIndex]);
          wordSpans = result.spans;
        }
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedWord.isEmpty) {
          accumulatedWord = transWord;
        }
        accumulatedDiffType = DiffType.insertWord;
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord.isEmpty ? transWords[transWordIndex] : accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedWord = "";
        accumulatedRealWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        transWordIndex++;
        previousRealWord = "";
        continue;
      } else {
        if (transWordIndex < allSpans.length) {
          wordSpans = allSpans[transWordIndex];
        } else {
          final result = _buildWordSpans(transWord, similarWord);
          wordSpans = result.spans;
        }
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedRealWord.isEmpty) {
          accumulatedRealWord = similarWord;
        }
        if (accumulatedWord.isEmpty) {
          accumulatedWord = transWord;
        }
        accumulatedDiffType = _getDiffTypeFromSpans(wordSpans);
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedRealWord = "";
        accumulatedWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        transWordIndex++;
        previousRealWord = "";
        continue;
      }
    }
    if (accumulatedSpans.isNotEmpty) {
      wordsWithSpans.add(
        WordWithSpans(
          word: accumulatedWord,
          realWord: accumulatedRealWord,
          index: index,
          spans: accumulatedSpans,
          diffType: accumulatedDiffType,
          wordColor: _getWordColorFromSpans(accumulatedSpans),
        ),
      );
    }
    return wordsWithSpans;
  }
  _BuildWordSpansResult _buildWordSpans(String word, String realWord) {
    List<TextSpan> spans = [];
    DiffType diffType = DiffType.equal;
    if (word == realWord) {
      diffType = DiffType.equal;
      for (int i = 0; i < word.length; i++) {
        spans.add(TextSpan(text: word[i], style: TextStyle(backgroundColor: Colors.green.withOpacity(0.0))));
      }
    } else if (word.isEmpty) {
      diffType = DiffType.delete;
      for (int i = 0; i < realWord.length; i++) {
        spans.add(TextSpan(text: realWord[i], style: TextStyle(backgroundColor: Colors.red.withOpacity(0.5))));
      }
    } else if (realWord.isEmpty) {
      diffType = DiffType.insertWord;
      for (int i = 0; i < word.length; i++) {
        spans.add(TextSpan(text: word[i], style: TextStyle(backgroundColor: Colors.blue.withOpacity(0.5))));
      }
    } else {
      final diffs = diff(word, realWord);
      int insertCount = 0;
      int deleteCount = 0;
      for (final diff in diffs) {
        if (diff.operation == DIFF_INSERT) {
          insertCount++;
        } else if (diff.operation == DIFF_DELETE) {
          deleteCount++;
        }
      }
      if (insertCount > 0 && deleteCount == 0) {
        diffType = DiffType.insert;
      } else if (deleteCount > 0 && insertCount == 0) {
        diffType = DiffType.delete;
      } else {
        diffType = DiffType.both;
      }
      for (final diff in diffs) {
        Color color = Colors.transparent;
        if (diff.operation == DIFF_DELETE) {
          color = Colors.red.withOpacity(0.5);
        } else if (diff.operation == DIFF_INSERT) {
          color = Colors.blue.withOpacity(0.5);
        } else if (diff.operation == DIFF_EQUAL) {
          color = Colors.green.withOpacity(0.0);
        }
        spans.addAll(diff.text.characters.map((char) => TextSpan(text: char, style: TextStyle(backgroundColor: color))));
      }
    }
    return _BuildWordSpansResult(spans: spans, diffType: diffType);
  }
  */

  //3
  /*
  List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    // 1.1. Extraer y formatear las palabras de la transcripción y el texto real.
    //List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    //List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> transWords = "itsas, izarrak, bazen, behin, hondartzatik, egunero, pasatzen, zuen, gizonak, goiz, hartan, itsatzetza, itsas, izarrez, eta, beteta, ikusi, zuen, milaka, zeuden,".split(" ");
    List<String> realWords = "itsas, izarrak, bazen, behin, hondartzatik, egunero, paseatzen, zuen, gizona, goiz, hartan, itsasertza, itsas, izarrez, beteta, ikusi, zuen, milaka, zeuden, eguraldi,".split(" ");
    print("transWords --> $transWords");
    print("realWords --> $realWords");

    // para testear
    //WordWithSpans wordsWithSpan= WordWithSpans(word: "word", realWord: "realWord", index: 0, spans: [], diffType: DiffType.insert, wordColor: Colors.red);
    List<WordWithSpans> wordsWithSpans =[];

    //final diff = PatienceDiffJs(transWords, realWords, true);
    final diff = PatienceDiffJs(realWords, transWords, true); // Usamos diffPlusFlag en true para detectar movimientos
    final result = diff.patienceDiffPlusJs();
    //print('Result: $result');
    //print('Result Plus: $result');

    // 2. Imprimir las diferencias como en JavaScript
    /*String diffLines = "";
    for (var o in result['lines']) {
      if (o['bIndex'] < 0 && o['moved'] == true) {
        diffLines += "-m  "; // Eliminada y movida
      } else if (o['moved'] == true) {
        diffLines += "+m  "; // Insertada y movida
      } else if (o['aIndex'] < 0) {
        diffLines += "+   "; // Insertada
      } else if (o['bIndex'] < 0) {
        diffLines += "-   "; // Eliminada
      } else {
        diffLines += "    "; // Igual
      }
      diffLines += o['line'] + "\n";
    }
    print("Diff Lines:\n$diffLines");*/
    // 3. Crear la lista de WordWithSpans
    for (var o in result['lines']) {
      DiffType diffType;
      Color wordColor;
      String word = o['line'];
      String realWord = "";
      int index = 0;
      if (o['aIndex'] < 0) {
        // Insertada
        diffType = DiffType.insert;
        wordColor = Colors.green;
        realWord = word;
        index = o['bIndex'];
      } else if (o['bIndex'] < 0) {
        // Eliminada
        diffType = DiffType.delete;
        wordColor = Colors.red;
        realWord = "";
        index = o['aIndex'];
      } else {
        // Presente en ambas listas
        if (o['moved'] == true) {
          // Movida
          diffType = DiffType.move;
          wordColor = Colors.blue;
        } else {
          // Igual
          diffType = DiffType.equal;
          wordColor = Colors.black;
        }
        realWord = word;
        index = o['aIndex'];
      }
      // Crear el objeto WordWithSpans
      wordsWithSpans.add(WordWithSpans(word: word, realWord: realWord, index: index, spans: [], diffType: diffType, wordColor: wordColor));
    }
    // 4. Crear los spans
    for (var i = 0; i < wordsWithSpans.length; i++) {
      WordWithSpans wordWithSpan = wordsWithSpans[i];
      List<TextSpan> spans = [];
      if (wordWithSpan.diffType == DiffType.insert) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.underline)));
      } else if (wordWithSpan.diffType == DiffType.delete) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.lineThrough)));
      } else if (wordWithSpan.diffType == DiffType.move) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor)));
      }
      wordWithSpan.spans = spans;
    }

    /*// 1.2. Preparar las listas.
    final result = _prepareLists(transWords, realWords);
    List<String> newTransWords = result.newTransWords;
    List<String> newRealWords = result.newRealWords;
    // 1.3. Formatear el texto completo para la comparación de diferencias.
    String transcribedText = newTransWords.join(" ");
    String realText = newRealWords.join(" ");
    transcribedText = transcribedText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();
    realText = realText.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\r\n]+'), ' ').trim().toLowerCase();
    // 1.4. Calcular las diferencias entre los textos.
    final diffs = diff(transcribedText, realText);
    // 1.5. Inicializar variables para el seguimiento de las diferencias.
    final List<List<TextSpan>> allSpans = [];
    List<TextSpan> currentWordSpans = [];
    String currentWord = "";
    String currentRealWord = "";
    int transWordIndex = 0;
    int realWordIndex = 0;
    final formattedWords = transcribedText.split(" ");
    bool isInsert = false;
    // 2.1. Iterar sobre las diferencias y crear los TextSpan.
    for (final diff in diffs) {
      Color color = Colors.transparent;
      if (diff.operation == DIFF_DELETE) {
        color = Colors.red.withOpacity(0.5);
      } else if (diff.operation == DIFF_INSERT) {
        color = Colors.blue.withOpacity(0.5);
        isInsert = true;
      } else if (diff.operation == DIFF_EQUAL) {
        color = Colors.green.withOpacity(0.0);
      }
      // 2.2. Iterar sobre los caracteres de cada diferencia.
      for (int i = 0; i < diff.text.length; i++) {
        final char = diff.text[i];
        currentWordSpans.add(TextSpan(text: char, style: TextStyle(backgroundColor: color)));
        currentWord += char;
        if (realWordIndex < newRealWords.length) {
          currentRealWord += char;
        }
        // 2.3. Comprobar si se ha completado una palabra.
        if (isInsert) {
          if (transWordIndex < formattedWords.length && currentWord == formattedWords[transWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            transWordIndex++;
            isInsert = false;
          }
        } else {
          if (realWordIndex < newRealWords.length && currentRealWord == newRealWords[realWordIndex]) {
            allSpans.add(List.from(currentWordSpans));
            currentWordSpans.clear();
            currentWord = "";
            currentRealWord = "";
            realWordIndex++;
          }
        }
      }
    }
    // 2.4. Añadir los TextSpan restantes.
    if (currentWordSpans.isNotEmpty) {
      allSpans.add(List.from(currentWordSpans));
    }
    // 3.1. Inicializar variables para el bucle principal.
    int index = 0;
    List<WordWithSpans> wordsWithSpans = [];
    transWordIndex = 0;
    realWordIndex = 0;
    List<TextSpan> accumulatedSpans = [];
    String accumulatedRealWord = "";
    String accumulatedWord = "";
    DiffType accumulatedDiffType = DiffType.equal;
    String previousRealWord = "";
    // 4.1. Bucle principal para comparar palabras.
    while (transWordIndex < transWords.length || realWordIndex < realWords.length) {
      String transWord = transWordIndex < transWords.length ? transWords[transWordIndex] : "";
      String realWord = realWordIndex < realWords.length ? realWords[realWordIndex] : "";
      List<TextSpan> wordSpans = [];
      // 4.2. Caso: Palabras iguales.
      if (transWord == realWord) {
        final result = _buildWordSpans(transWord, realWord);
        wordSpans = result.spans;
        if (accumulatedSpans.isNotEmpty) {
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: accumulatedRealWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedRealWord = "";
          accumulatedWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
        }
        wordsWithSpans.add(WordWithSpans(word: transWord, realWord: realWord, index: index, spans: wordSpans, diffType: DiffType.equal, wordColor: Colors.green.withOpacity(0.5)));
        transWordIndex++;
        realWordIndex++;
        index++;
        previousRealWord = realWord;
        continue;
      }
      // 4.3. Caso: Palabra desplazada.
      if (transWord == previousRealWord && previousRealWord.isNotEmpty) {
        final result = _buildWordSpans(transWord, transWord);
        wordSpans = result.spans;
        if (accumulatedSpans.isNotEmpty) {
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: accumulatedRealWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedRealWord = "";
          accumulatedWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
        }
        wordsWithSpans.add(WordWithSpans(word: transWord, realWord: transWord, index: index, spans: wordSpans, diffType: DiffType.equal, wordColor: Colors.green.withOpacity(0.5)));
        transWordIndex++;
        index++;
        previousRealWord = realWord;
        continue;
      }
      // 4.4. Caso: Inserción de palabra.
      if (realWord.isEmpty) {
        bool foundSimilarInTransWords = false;
        String similarWord = "";
        for (String w in transWords) {
          if (_isSimilar(transWord, w)) {
            foundSimilarInTransWords = true;
            similarWord = w;
            break;
          }
        }
        if (foundSimilarInTransWords) {
          final result = _buildWordSpans(transWord, similarWord);
          wordSpans = result.spans;
          accumulatedSpans.addAll(wordSpans);
          if (accumulatedWord.isEmpty) {
            accumulatedWord = transWord;
          }
          accumulatedDiffType = _getDiffTypeFromSpans(wordSpans);
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: similarWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedWord = "";
          accumulatedRealWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
          transWordIndex++;
          previousRealWord = "";
          continue;
        } else {
          final result = _buildWordSpans(transWord, transWords[transWordIndex]);
          wordSpans = result.spans;
          accumulatedSpans.addAll(wordSpans);
          if (accumulatedWord.isEmpty) {
            accumulatedWord = transWord;
          }
          accumulatedDiffType = DiffType.insertWord;
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: transWords[transWordIndex],
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedWord = "";
          accumulatedRealWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
          transWordIndex++;
          previousRealWord = "";
          continue;
        }
      }
      // 4.5. Caso: Eliminación de palabra.
      if (transWord.isEmpty) {
        final result = _buildWordSpans("", realWord);
        wordSpans = result.spans;
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedRealWord.isEmpty) {
          accumulatedRealWord = realWord;
        }
        accumulatedDiffType = DiffType.deleteWord;
        wordsWithSpans.add(
          WordWithSpans(
            word: "",
            realWord: accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedRealWord = "";
        accumulatedWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        realWordIndex++;
        previousRealWord = "";
        continue;
      }
      // 4.6. Caso: Modificación de palabra.
      bool foundSimilarInRealWords = false;
      String similarWord = "";
      for (int i = 0; i < realWords.length; i++) {
        String currentRealWord = "";
        for (int j = i; j < realWords.length; j++) {
          currentRealWord += realWords[j];
          if (_isSimilar(transWord, currentRealWord)) {
            foundSimilarInRealWords = true;
            similarWord = currentRealWord;
            realWordIndex = j;
            break;
          }
        }
        if (foundSimilarInRealWords) {
          break;
        }
      }
      if (!foundSimilarInRealWords) {
        bool foundSimilarInTransWords = false;
        String similarWordTrans = "";
        for (String w in transWords) {
          if (_isSimilar(realWord, w)) {
            foundSimilarInTransWords = true;
            similarWordTrans = w;
            break;
          }
        }
        if (foundSimilarInTransWords) {
          final result = _buildWordSpans(similarWordTrans, realWord);
          wordSpans = result.spans;
          accumulatedSpans.addAll(wordSpans);
          if (accumulatedWord.isEmpty) {
            accumulatedWord = similarWordTrans;
          }
          accumulatedDiffType = _getDiffTypeFromSpans(wordSpans);
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: realWord,
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedWord = "";
          accumulatedRealWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
          transWordIndex++;
          previousRealWord = "";
          continue;
        } else {
          if (transWordIndex < allSpans.length) {
            wordSpans = allSpans[transWordIndex];
          } else {
            final result = _buildWordSpans(transWord, transWords[transWordIndex]);
            wordSpans = result.spans;
          }
          accumulatedSpans.addAll(wordSpans);
          if (accumulatedWord.isEmpty) {
            accumulatedWord = transWord;
          }
          accumulatedDiffType = DiffType.deleteWord;
          wordsWithSpans.add(
            WordWithSpans(
              word: accumulatedWord,
              realWord: "",
              index: index,
              spans: accumulatedSpans,
              diffType: accumulatedDiffType,
              wordColor: _getWordColorFromSpans(accumulatedSpans),
            ),
          );
          accumulatedSpans = [];
          accumulatedWord = "";
          accumulatedRealWord = "";
          accumulatedDiffType = DiffType.equal;
          index++;
          transWordIndex++;
          previousRealWord = "";
          continue;
        }
      } else {
        final result = _buildWordSpans(transWord, similarWord);
        wordSpans = result.spans;
        accumulatedSpans.addAll(wordSpans);
        if (accumulatedRealWord.isEmpty) {
          accumulatedRealWord = similarWord;
        }
        if (accumulatedWord.isEmpty) {
          accumulatedWord = transWord;
        }
        accumulatedDiffType = _getDiffTypeFromSpans(wordSpans);
        wordsWithSpans.add(
          WordWithSpans(
            word: accumulatedWord,
            realWord: accumulatedRealWord,
            index: index,
            spans: accumulatedSpans,
            diffType: accumulatedDiffType,
            wordColor: _getWordColorFromSpans(accumulatedSpans),
          ),
        );
        accumulatedSpans = [];
        accumulatedRealWord = "";
        accumulatedWord = "";
        accumulatedDiffType = DiffType.equal;
        index++;
        transWordIndex++;
        realWordIndex++;
        previousRealWord = "";
        continue;
      }
    }
    // 4.7. Añadir los TextSpan restantes.
    if (accumulatedSpans.isNotEmpty) {
      wordsWithSpans.add(
        WordWithSpans(
          word: accumulatedWord,
          realWord: accumulatedRealWord,
          index: index,
          spans: accumulatedSpans,
          diffType: accumulatedDiffType,
          wordColor: _getWordColorFromSpans(accumulatedSpans),
        ),
      );
    }
    */
    // 4.8. Devolver la lista de WordWithSpans.
    return wordsWithSpans;
  }
  */

  // good normal
  /*
  List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    // 1.1. Extraer y formatear las palabras de la transcripción y el texto real.
    //List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    //List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> transWords = "itsas, izarrak, bazen, behin, hondartzatik, egunero, pasatzen, zuen, gizonak, goiz, hartan, itsatzetza, itsas, izarrez, eta, beteta, ikusi, zuen, milaka, zeuden,".split(", ");
    List<String> realWords = "itsas, izarrak, bazen, behin, hondartzatik, egunero, paseatzen, zuen, gizona, goiz, hartan, itsasertza, itsas, izarrez, beteta, ikusi, zuen, milaka, zeuden, eguraldi,".split(", ");
    print("transWords --> $transWords");
    print("realWords --> $realWords");

    // para testear
    //WordWithSpans wordsWithSpan= WordWithSpans(word: "word", realWord: "realWord", index: 0, spans: [], diffType: DiffType.insert, wordColor: Colors.red);
    List<WordWithSpans> wordsWithSpans =[];
    final diff = PatienceDiffJs(transWords, realWords, false); // Usamos diffPlusFlag en false
    final result = diff.patienceDiffJs(); // Usamos patienceDiffJs
    //print('Result: $result');
    print('Result Plus: $result');

    // 2. Imprimir las diferencias como en JavaScript
    String diffLines = "";
    for (var o in result['lines']) {
      if (o['bIndex'] < 0 && o['moved'] == true) {
        diffLines += "-m  "; // Eliminada y movida
      } else if (o['moved'] == true) {
        diffLines += "+m  "; // Insertada y movida
      } else if (o['aIndex'] < 0) {
        diffLines += "+   "; // Insertada
      } else if (o['bIndex'] < 0) {
        diffLines += "-   "; // Eliminada
      } else {
        diffLines += "    "; // Igual
      }
      diffLines += o['line'] + "\n";
    }
    print("Diff Lines:\n$diffLines");

    // 3. Crear la lista de WordWithSpans
    int transIndex = 0;
    int realIndex = 0;
    for (var o in result['lines']) {
      DiffType diffType;
      Color wordColor;
      String word = "";
      String realWord = "";
      int index = 0;
      if (o['aIndex'] < 0) {
        // Insertada
        diffType = DiffType.insert;
        wordColor = Colors.green;
        word = realWords[realIndex];
        realWord = word;
        index = realIndex;
        realIndex++;
      } else if (o['bIndex'] < 0) {
        // Eliminada
        diffType = DiffType.delete;
        wordColor = Colors.red;
        word = transWords[transIndex];
        realWord = "";
        index = transIndex;
        transIndex++;
      } else {
        // Presente en ambas listas
        // Igual
        diffType = DiffType.equal;
        wordColor = Colors.black;
        word = transWords[transIndex];
        realWord = realWords[realIndex];
        index = transIndex;
        transIndex++;
        realIndex++;
      }
      // Crear el objeto WordWithSpans
      wordsWithSpans.add(WordWithSpans(word: word, realWord: realWord, index: index, spans: [], diffType: diffType, wordColor: wordColor));
    }
    // 4. Crear los spans
    for (var i = 0; i < wordsWithSpans.length; i++) {
      WordWithSpans wordWithSpan = wordsWithSpans[i];
      List<TextSpan> spans = [];
      if (wordWithSpan.diffType == DiffType.insert) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.underline)));
      } else if (wordWithSpan.diffType == DiffType.delete) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.lineThrough)));
      } else if (wordWithSpan.diffType == DiffType.move) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor)));
      }
      wordWithSpan.spans = spans;
    }
    return wordsWithSpans;
  }
*/

  //good good
  /*List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    // 1.1. Extraer y formatear las palabras de la transcripción y el texto real.
    List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    print("transWords --> $transWords");
    print("realWords --> $realWords");

    List<WordWithSpans> wordsWithSpans = [];

    final diff = PatienceDiffJs(transWords, realWords, false); // Usamos diffPlusFlag en false
    final result = diff.patienceDiffJs(); // Usamos patienceDiffJs
    print('Result Plus: $result');

    // 2. Imprimir las diferencias como en JavaScript
    String diffLines = "";
    for (var o in result['lines']) {
      if (o['bIndex'] < 0) {
        diffLines += "-   "; // Eliminada
      } else if (o['aIndex'] < 0) {
        diffLines += "+   "; // Insertada
      } else {
        diffLines += "    "; // Igual
      }
      diffLines += o['line'] + "\n";
    }
    print("Diff Lines:\n$diffLines");

    // 3. Crear la lista de WordWithSpans
    int transIndex = 0;
    int realIndex = 0;
    for (int i = 0; i < transWords.length; i++) {
      DiffType diffType = DiffType.equal;
      Color wordColor = Colors.black;
      String word = transWords[i];
      String realWord = "";
      int index = i;

      // Buscar la correspondencia en el resultado de diff
      var diffLine = result['lines'].firstWhere((element) => element['aIndex'] == i, orElse: () => {'aIndex': -2, 'bIndex': -2});

      if (diffLine['aIndex'] == -2) {
        // No se encontró la palabra en el resultado de diff
        // Esto no debería ocurrir, pero por si acaso
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = word;
      } else if (diffLine['bIndex'] == -1) {
        // Eliminada
        diffType = DiffType.delete;
        wordColor = Colors.red;
        realWord = "";
      } else if (diffLine['aIndex'] == -1) {
        // Insertada
        diffType = DiffType.insert;
        wordColor = Colors.green;
        realWord = realWords[diffLine['bIndex']];
        word = realWord;
      } else {
        // Presente en ambas listas
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = realWords[diffLine['bIndex']];
      }

      // Crear el objeto WordWithSpans
      wordsWithSpans.add(WordWithSpans(word: word, realWord: realWord, index: index, spans: [], diffType: diffType, wordColor: wordColor));
    }
    // 4. Crear los spans
    for (var i = 0; i < wordsWithSpans.length; i++) {
      WordWithSpans wordWithSpan = wordsWithSpans[i];
      List<TextSpan> spans = [];
      if (wordWithSpan.diffType == DiffType.insert) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.underline)));
      } else if (wordWithSpan.diffType == DiffType.delete) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.lineThrough)));
      } else if (wordWithSpan.diffType == DiffType.move) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor)));
      }
      wordWithSpan.spans = spans;
    }
    return wordsWithSpans;
  }*/

  /*List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    // 1.1. Extraer y formatear las palabras de la transcripción y el texto real.
    List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    print("transWords --> $transWords");
    print("realWords --> $realWords");

    List<WordWithSpans> wordsWithSpans = [];

    final diff = PatienceDiffJs(transWords, realWords, false); // Usamos diffPlusFlag en false
    final result = diff.patienceDiffJs(); // Usamos patienceDiffJs
    //print('Result Plus: $result');

    // 2. Imprimir las diferencias como en JavaScript
    String diffLines = "";
    for (var o in result['lines']) {
      if (o['bIndex'] < 0) {
        diffLines += "-   "; // Eliminada
      } else if (o['aIndex'] < 0) {
        diffLines += "+   "; // Insertada
      } else {
        diffLines += "    "; // Igual
      }
      diffLines += o['line'] + "\n";
    }
    print("Diff Lines:\n$diffLines");

    // 3. Crear la lista de WordWithSpans

    for (int i = 0; i < transWords.length; i++) {
      DiffType diffType = DiffType.equal;
      Color wordColor = Colors.black;
      String word = transWords[i];
      String realWord = "";
      int index = i;

      // Buscar la correspondencia en el resultado de diff
      var diffLine = result['lines'].firstWhere((element) => element['aIndex'] == i, orElse: () => {'aIndex': -2, 'bIndex': -2});

      if (diffLine['aIndex'] == -2) {
        // No se encontró la palabra en el resultado de diff
        // Esto no debería ocurrir, pero por si acaso
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = word;
      } else if (diffLine['bIndex'] == -1) {
        // Eliminada
        diffType = DiffType.delete;
        wordColor = Colors.red;
        realWord = "";
      } else if (diffLine['aIndex'] == -1) {
        // Insertada
        diffType = DiffType.insert;
        wordColor = Colors.green;
        realWord = realWords[diffLine['bIndex']];
        word = realWord;
      } else {
        // Presente en ambas listas
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = realWords[diffLine['bIndex']];
      }

      // Crear el objeto WordWithSpans
      wordsWithSpans.add(WordWithSpans(word: word, realWord: realWord, index: index, spans: [], diffType: diffType, wordColor: wordColor));
    }
    // 4. Crear los spans
    for (var i = 0; i < wordsWithSpans.length; i++) {
      WordWithSpans wordWithSpan = wordsWithSpans[i];
      List<TextSpan> spans = [];
      if (wordWithSpan.diffType == DiffType.insert) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.underline)));
      } else if (wordWithSpan.diffType == DiffType.delete) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.lineThrough)));
      } else if (wordWithSpan.diffType == DiffType.move) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor)));
      }
      wordWithSpan.spans = spans;
    }
    return wordsWithSpans;
  }*/

  /// ultimo usado
  /*List<WordWithSpans> calculateWordsWithSpans(Transcription transcription) {
    // 1.1. Extraer y formatear las palabras de la transcripción y el texto real.
    List<String> transWords = transcription.transsegments.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    List<String> realWords = transcription.realsegments!.map((s) => s.word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')).toList();
    print("transWords --> $transWords");
    print("realWords --> $realWords");

    List<WordWithSpans> wordsWithSpans = [];

    final diff = PatienceDiffJs(transWords, realWords, false); // Usamos diffPlusFlag en false
    final result = diff.patienceDiffJs(); // Usamos patienceDiffJs
    print('Result Plus: $result');

    /*
    * bIndex < 0: Significa que la palabra está en el texto real (realWords) pero no en el texto transcrito (transWords). Es una eliminación.
      aIndex < 0: Significa que la palabra está en el texto transcrito (transWords) pero no en el texto real (realWords). Es una inserción.
      aIndex >= 0 y bIndex >= 0: Significa que la palabra está en ambos textos. Si aIndex y bIndex son diferentes, hay un desplazamiento. Si son iguales, es una coincidencia.
    * */
    // 2. Imprimir las diferencias como en JavaScript
    String diffLines = "";
    for (var o in result['lines']) {
      if (o['bIndex'] < 0) {
        diffLines += "-   "; // Eliminada
      } else if (o['aIndex'] < 0) {
        diffLines += "+   "; // Insertada
      } else {
        diffLines += "    "; // Igual
      }
      diffLines += o['line'] + "\n";
    }
    print("Diff Lines:\n$diffLines");

    // 3. Crear la lista de WordWithSpans
    int realIndex = 0;
    for (int i = 0; i < transWords.length; i++) {
      DiffType diffType = DiffType.equal;
      Color wordColor = Colors.black;
      String word = transWords[i];
      String realWord = "";
      int index = i;

      // Buscar la correspondencia en el resultado de diff
      var diffLine = result['lines'].firstWhere((element) => element['aIndex'] == i, orElse: () => {'aIndex': -2, 'bIndex': -2});

      if (diffLine['aIndex'] == -2) {
        // No se encontró la palabra en el resultado de diff
        // Esto no debería ocurrir, pero por si acaso
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = word;
      } else if (diffLine['bIndex'] == -1) {
        // Eliminada
        diffType = DiffType.delete;
        wordColor = Colors.red;
        // Verificar la siguiente línea
        int nextLineIndex = result['lines'].indexOf(diffLine) + 1;
        if (nextLineIndex < result['lines'].length) {
          var nextDiffLine = result['lines'][nextLineIndex];
          if (nextDiffLine['aIndex'] != -1 && nextDiffLine['bIndex'] != -1) {
            // La siguiente línea es una coincidencia
            // Verificar si la palabra eliminada es parte de la palabra que coincide
            if (realWords[nextDiffLine['bIndex']].contains(word)) {
              realWord = realWords[nextDiffLine['bIndex']];
            }
          } else if (nextDiffLine['aIndex'] == -1) {
            // La siguiente línea es una inserción
            realWord = realWords[nextDiffLine['bIndex']];
          }
        }
      } else if (diffLine['aIndex'] == -1) {
        // Insertada
        diffType = DiffType.insert;
        wordColor = Colors.green;
        realWord = realWords[diffLine['bIndex']];
        word = realWord;
      } else {
        // Presente en ambas listas
        diffType = DiffType.equal;
        wordColor = Colors.black;
        realWord = realWords[diffLine['bIndex']];
      }
      if (diffLine['bIndex'] != -1) {
        realIndex++;
      }
      // Crear el objeto WordWithSpans
      wordsWithSpans.add(WordWithSpans(word: word, realWord: realWord, index: index, spans: [], diffType: diffType, wordColor: wordColor));
    }
    // 4. Crear los spans
    for (var i = 0; i < wordsWithSpans.length; i++) {
      WordWithSpans wordWithSpan = wordsWithSpans[i];
      List<TextSpan> spans = [];
      if (wordWithSpan.diffType == DiffType.insert) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.underline)));
      } else if (wordWithSpan.diffType == DiffType.delete) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, decoration: TextDecoration.lineThrough)));
      } else if (wordWithSpan.diffType == DiffType.move) {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor, fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: wordWithSpan.word, style: TextStyle(color: wordWithSpan.wordColor)));
      }
      wordWithSpan.spans = spans;
    }
    return wordsWithSpans;
  }*/

  _BuildWordSpansResult _buildWordSpans(String word, String realWord) {
    List<TextSpan> spans = [];
    DiffType diffType = DiffType.equal;
    if (word == realWord) {
      diffType = DiffType.equal;
      for (int i = 0; i < word.length; i++) {
        spans.add(TextSpan(text: word[i], style: TextStyle(backgroundColor: Colors.green.withOpacity(0.0))));
      }
    } else if (word.isEmpty) {
      diffType = DiffType.deleteWord;
      for (int i = 0; i < realWord.length; i++) {
        spans.add(TextSpan(text: realWord[i], style: TextStyle(backgroundColor: Colors.red.withOpacity(0.5))));
      }
    } else if (realWord.isEmpty) {
      diffType = DiffType.insertWord;
      for (int i = 0; i < word.length; i++) {
        spans.add(TextSpan(text: word[i], style: TextStyle(backgroundColor: Colors.blue.withOpacity(0.5))));
      }
    } else {
      final diffs = diff(word, realWord);
      int insertCount = 0;
      int deleteCount = 0;
      for (final diff in diffs) {
        if (diff.operation == DIFF_INSERT) {
          insertCount++;
        } else if (diff.operation == DIFF_DELETE) {
          deleteCount++;
        }
      }
      if (insertCount > 0 && deleteCount == 0) {
        diffType = DiffType.insert;
      } else if (deleteCount > 0 && insertCount == 0) {
        diffType = DiffType.delete;
      } else {
        diffType = DiffType.both;
      }
      for (final diff in diffs) {
        Color color = Colors.transparent;
        if (diff.operation == DIFF_DELETE) {
          color = Colors.red.withOpacity(0.5);
        } else if (diff.operation == DIFF_INSERT) {
          color = Colors.blue.withOpacity(0.5);
        } else if (diff.operation == DIFF_EQUAL) {
          color = Colors.green.withOpacity(0.0);
        }
        spans.addAll(diff.text.characters.map((char) => TextSpan(text: char, style: TextStyle(backgroundColor: color))));
      }
    }
    return _BuildWordSpansResult(spans: spans, diffType: diffType);
  }

  Color _getWordColorFromSpans(List<TextSpan> spans) {
    if (spans.isEmpty) {
      return Colors.transparent;
    }
    bool hasRed = false;
    bool hasBlue = false;
    bool hasGreen = false;
    for (final span in spans) {
      Color color = span.style?.backgroundColor ?? Colors.transparent;
      if (color == Colors.red.withOpacity(0.5)) {
        hasRed = true;
      } else if (color == Colors.blue.withOpacity(0.5)) {
        hasBlue = true;
      } else if (color == Colors.green.withOpacity(0.0)) {
        hasGreen = true;
      }
    }
    if (hasRed && hasBlue) {
      return Colors.purple.withOpacity(0.5);
    } else if (hasRed) {
      return Colors.red.withOpacity(0.5);
    } else if (hasBlue) {
      return Colors.blue.withOpacity(0.5);
    } else if (hasGreen) {
      return Colors.green.withOpacity(0.5);
    } else {
      return Colors.transparent;
    }
  }

  DiffType _getDiffTypeFromSpans(List<TextSpan> spans) {
    if (spans.isEmpty) {
      return DiffType.equal;
    }
    bool hasRed = false;
    bool hasBlue = false;
    bool hasGreen = false;
    for (final span in spans) {
      Color color = span.style?.backgroundColor ?? Colors.transparent;
      if (color == Colors.red.withOpacity(0.5)) {
        hasRed = true;
      } else if (color == Colors.blue.withOpacity(0.5)) {
        hasBlue = true;
      } else if (color == Colors.green.withOpacity(0.0)) {
        hasGreen = true;
      }
    }
    if (hasRed && hasBlue) {
      return DiffType.both;
    } else if (hasRed) {
      return DiffType.delete;
    } else if (hasBlue) {
      return DiffType.insert;
    } else if (hasGreen) {
      return DiffType.equal;
    } else {
      return DiffType.equal;
    }
  }

  bool _isSimilar(String word1, String word2) {
    if (word1 == word2) return true;
    if ((word1.length - word2.length).abs() > 1) return false;
    int diffCount = 0;
    int i = 0, j = 0;
    while (i < word1.length && j < word2.length) {
      if (word1[i] != word2[j]) {
        diffCount++;
        if (word1.length > word2.length) {
          i++;
        } else if (word2.length > word1.length) {
          j++;
        } else {
          i++;
          j++;
        }
      } else {
        i++;
        j++;
      }
    }
    diffCount += (word1.length - i) + (word2.length - j);
    return diffCount <= 1;
  }

  /// Prepara las listas de palabras transcritas y reales para la comparación.
  ///
  /// [transWords]: La lista de palabras transcritas.
  /// [realWords]: La lista de palabras reales.
  ///
  /// Devuelve un objeto [_PrepareListsResult] con las nuevas listas preparadas.
  _PrepareListsResult _prepareLists(List<String> transWords, List<String> realWords) {
    print("Preparando listas...");
    // Calcula las diferencias entre las listas usando PatienceDiff.
    List<DiffLine> diffLines = PatienceDiff.diff(transWords, realWords);

    //print("diffLines -> ${diffLines.length}");
    /*for (DiffLine l in diffLines) {
      String prefix = " "; // Por defecto, es una coincidencia
      if (l.aIndex == -1) {
        prefix = "+"; // Inserción
      } else if (l.bIndex == -1) {
        prefix = "-"; // Eliminación
      }
      print("$prefix   ${l.line}");
    }*/
    List<String> newTransWords = [];
    List<String> newRealWords = [];

    // Itera sobre las líneas de diferencia para construir las nuevas listas.
    for (DiffLine diffLine in diffLines) {
      // Si la línea solo está en la lista 'b' (realWords), se considera una inserción.
      if (diffLine.aIndex == -1) {
        newTransWords.add(""); // Se añade un espacio vacío en newTransWords.
        newRealWords.add(diffLine.line); // Se añade la línea en newRealWords.
      }
      // Si la línea solo está en la lista 'a' (transWords), se considera una eliminación.
      else if (diffLine.bIndex == -1) {
        newTransWords.add(diffLine.line); // Se añade la línea en newTransWords.
        newRealWords.add(""); // Se añade un espacio vacío en newRealWords.
      }
      // Si la línea está en ambas listas, se considera una coincidencia.
      else {
        newTransWords.add(diffLine.line); // Se añade la línea en newTransWords.
        newRealWords.add(diffLine.line); // Se añade la línea en newRealWords.
      }
    }

    // Asegurar que ambas listas tengan la misma longitud.
    if (newTransWords.length > newRealWords.length) {
      while (newRealWords.length < newTransWords.length) {
        newRealWords.add("");
      }
    } else if (newRealWords.length > newTransWords.length) {
      while (newTransWords.length < newRealWords.length) {
        newTransWords.add("");
      }
    }

    //print("newTransWords -> $newTransWords");
    //print("newRealWords -> $newRealWords");
    return _PrepareListsResult(newTransWords, newRealWords);
  }

  //////////////////////

  String formatTextIntoParagraphs(String text) {
    final lines = text.split('\n');
    final paragraphs = <String>[];
    final currentParagraph = StringBuffer();

    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph.toString().trim());
          currentParagraph.clear();
        }
      } else {
        currentParagraph.write('${line.trim()} ');
      }
    }

    // Add the last paragraph if it's not empty
    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph.toString().trim());
    }
    //print(paragraphs.join('\n\n'));
    return paragraphs.join('\n\n');
  }

  Future<void> useMockTranscriptionEU() async {
    emit(state.copyWith(status: TranscribeStatus.loading));
    String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_normalized.json');
    List<dynamic> jsonList = json.decode(jsonString);
    List<Map<String, dynamic>> listMap = jsonList.map((item) => item as Map<String, dynamic>).toList();

    final transcription = Transcription.fromListMap(listMap);

    String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');

    // Formatear el texto real usando la nueva función
    final formattedText = formatTextIntoParagraphs(text);
    final alignedSegments = _createAlignedSegments(formattedText, transcription.transsegments);

    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));

    // Actualizar el estado
    emit(state.copyWith(
      status: TranscribeStatus.success,
      transcription: transcription.copyWith(alignedSegments: alignedSegments),
      textoRealformadoparrafos: formattedText,
    ));


    // 1. Crear una instancia de Transcription
    //Transcription transcription = Transcription.fromListMap(listMap, text: text);
   /* Transcription transcription = Transcription.fromListMap(listMap, text: textoRealformadoparrafos);

    // 2. Llamar a associateWords()
    transcription!.associateWords();

    // Llamar a printAssociatedSegments para mostrar la información de las asociaciones
    transcription?.printAssociatedSegments();

    transcription.alignSegmentsToRealText();

    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));
    emit(state.copyWith(status: TranscribeStatus.loaded, transcription: transcription, textoRealformadoparrafos: textoRealformadoparrafos));
  */
  }
/*
    // Ejemplo de datos (reemplaza esto con tus datos reales)
    List<Map<String, dynamic>> listmap = [
      {"word": "Itsas", "start": 0.0, "end": 0.5, "probability": 0.72},
      {"word": "izarrak", "start": 0.5, "end": 1.0, "probability": 0.98},
      {"word": "bazen", "start": 1.0, "end": 1.5, "probability": 0.87},
      {"word": "behin", "start": 1.5, "end": 2.0, "probability": 0.56},
      {"word": "hondartzatik", "start": 2.0, "end": 2.5, "probability": 0.92},
      {"word": "egunero", "start": 2.5, "end": 3.0, "probability": 1.0},
      {"word": "pasatzen", "start": 3.0, "end": 3.5, "probability": 1.0},
      {"word": "zuen", "start": 3.5, "end": 4.0, "probability": 1.0},
      {"word": "gizonak", "start": 4.0, "end": 4.5, "probability": 0.98},
      {"word": "goiz", "start": 4.5, "end": 5.0, "probability": 0.78},
      {"word": "hartan", "start": 5.0, "end": 5.5, "probability": 1.0},
      {"word": "Itsatzetza", "start": 5.5, "end": 6.0, "probability": 0.65},
      {"word": "itsas", "start": 6.0, "end": 6.5, "probability": 0.76},
      {"word": "izarrez", "start": 6.5, "end": 7.0, "probability": 0.73},
      {"word": "eta", "start": 7.0, "end": 7.5, "probability": 0.93},
      {"word": "beteta", "start": 7.5, "end": 8.0, "probability": 0.89},
      {"word": "ikusi", "start": 8.0, "end": 8.5, "probability": 0.99},
      {"word": "zuen", "start": 8.5, "end": 9.0, "probability": 0.99},
      {"word": "milaka", "start": 9.0, "end": 9.5, "probability": 0.99},
      {"word": "zeuden", "start": 9.5, "end": 10.0, "probability": 0.99},
      {"word": "Ebulaldi", "start": 10.0, "end": 10.5, "probability": 0.99},
      {"word": "txarragatik", "start": 10.5, "end": 11.0, "probability": 0.99},
      {"word": "edo", "start": 11.0, "end": 11.5, "probability": 0.99},
      {"word": "onartu", "start": 11.5, "end": 12.0, "probability": 0.99},
      {"word": "asko", "start": 12.0, "end": 12.5, "probability": 0.99},
      {"word": "zeuden", "start": 12.5, "end": 13.0, "probability": 0.99},
      {"word": "laku", "start": 13.0, "end": 13.5, "probability": 0.99},
      {"word": "izango", "start": 13.5, "end": 14.0, "probability": 0.99},
    ];
    String text = "itsas izarrak bazen behin hondartzatik egunero paseatzen zuen gizona goiz hartan itsasertza itsas izarrez beteta ikusi zuen milaka zeuden eguraldi txarragatik edo olatu asko zeudelako izango";
*/


  List<Segment> _createAlignedSegments(String formattedText, List<Segment> whisperSegments) {
    List<Segment> alignedSegments = [];
    final paragraphs = formattedText.split('\n\n');
    int whisperSegmentIndex = 0;
    for (String paragraph in paragraphs) {
      final words = paragraph.split(RegExp(r"\b"));
      for (String word in words) {
        if (word.trim().isEmpty) continue;
        // Buscar el segmento de Whisper correspondiente
        Segment? whisperSegment;
        while (whisperSegmentIndex < whisperSegments.length) {
          if (whisperSegments[whisperSegmentIndex].word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '') == word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '')) {
            whisperSegment = whisperSegments[whisperSegmentIndex];
            whisperSegmentIndex++;
            break;
          }
          whisperSegmentIndex++;
        }
        // Si no se encuentra el segmento, se crea uno nuevo
        if (whisperSegment == null) {
          whisperSegment = Segment(word: word, realWord: word, transcribedWords: [], transcribedWordsProbabilities: [], associationType: "coincidencia", levenshteinDistance: 0, tags: [], start: 0, end: 0, probability: 0);
        }
        // Crear el segmento alineado
        final segment = Segment(
          word: word,
          realWord: word,
          transcribedWords: whisperSegment.transcribedWords,
          transcribedWordsProbabilities: whisperSegment.transcribedWordsProbabilities,
          associationType: whisperSegment.associationType,
          levenshteinDistance: whisperSegment.levenshteinDistance,
          tags: [],
          start: whisperSegment.start,
          end: whisperSegment.end,
          probability: whisperSegment.probability,
        );
        alignedSegments.add(segment);
      }
    }
    //Añadir los segmentos de puntuacion
    List<Segment> alignedSegmentsWithPunctuation = [];
    for (Segment segment in alignedSegments) {
      final words = segment.word.split(RegExp(r"([.,!?;:])"));
      for (String word in words) {
        if (word.trim().isEmpty) continue;
        final punctuationSegment = Segment(word: word, realWord: word, transcribedWords: [], transcribedWordsProbabilities: [], associationType: "coincidencia", levenshteinDistance: 0, tags: [], start: segment.start, end: segment.end, probability: segment.probability);
        alignedSegmentsWithPunctuation.add(punctuationSegment);
      }
      final punctuation = segment.word.replaceAll(RegExp(r"[a-zA-Z0-9]"), "").trim();
      if(punctuation.isNotEmpty){
        final punctuationSegment = Segment(word: punctuation, realWord: null, transcribedWords: [], transcribedWordsProbabilities: [], associationType: "coincidencia", levenshteinDistance: 0, tags: [], start: segment.start, end: segment.end, probability: segment.probability);
        alignedSegmentsWithPunctuation.add(punctuationSegment);
      }
    }
    return alignedSegmentsWithPunctuation;
  }

  Future<void> useMockTranscriptionES() async {
    emit(state.copyWith(status: TranscribeStatus.loading));

    String text = await rootBundle.loadString('assets/texto_LA_TORTUGA_KALI.txt');

    String formattedText = formatTextIntoParagraphs(text);
    textoRealformadoparrafos = formattedText;
    transcription = Transcription.fromListMap(textoTransMock, text: textoRealformadoparrafos);

    // Llamar a associateWords en lugar de calculateWordsWithSpans
    transcription!.associateWords();

    // Imprimir información de las asociaciones
    for (int i = 0; i < transcription!.transsegments.length; i++) {
      final segment = transcription!.transsegments[i];
      print("Segmento ${i + 1}:");
      print("  Palabra transcrita: ${segment.word}");
      print("  Palabra real: ${segment.realWord}");
      print("  Palabras transcritas asociadas: ${segment.transcribedWords}");
      print("  Probabilidades de las palabras transcritas: ${segment.transcribedWordsProbabilities}");
      print("  Asociación: ${segment.wordAssociation != null ? 'Sí' : 'No'}");
      if (segment.wordAssociation != null) {
        print("    Palabras transcritas asociadas: ${segment.wordAssociation!.transcribedWords}");
        print("    Palabra real asociada: ${segment.wordAssociation!.realWord}");
        print("    Probabilidades de las palabras transcritas asociadas: ${segment.wordAssociation!.transcribedWordsProbabilities}");
      }
    }
    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_es.wav'));
    emit(state.copyWith(status: TranscribeStatus.loaded, transcription: transcription, textoRealformadoparrafos: textoRealformadoparrafos));
  }

  List<ComparacionSegmento> compararActualTranscription() {
    List<Object> resultados = compararSegmentos(transcription!.transsegments, transcription!.realsegments!);
    //List<Object> resultados = compararSegmentos(transcription!.realsegments!, transcription!.segments);
    // Filtrar solo los ComparacionSegmento
    List<ComparacionSegmento> segmentos = resultados.whereType<ComparacionSegmento>().toList();

    emit(state.copyWith(comparacion: segmentos));
    return segmentos;
  }

  void toggleEditMode() {
    emit(state.copyWith(editMode: !state.editMode));
  }

  void addTagToSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.transsegments.length) {
      return;
    }
    final segment = state.transcription!.transsegments[index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.transsegments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transsegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void removeTagFromSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.transsegments.length) {
      return;
    }
    final segment = state.transcription!.transsegments[index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.transsegments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transsegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegment(Segment newSegment) {
    if (state.transcription == null) return;
    final index = state.transcription!.transsegments.indexOf(newSegment);
    if (index == -1) return;
    final newSegments = List<Segment>.from(state.transcription!.transsegments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transsegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegments(List<int> indexes, String newText) {
    if (state.transcription == null || indexes.isEmpty) return;
    final newSegments = List<Segment>.from(state.transcription!.transsegments);
    for (int index in indexes) {
      if (index >= 0 && index < newSegments.length) {
        final segment = newSegments[index];
        final newSegment = segment.copyWith(word: newText);
        newSegments[index] = newSegment;
      }
    }
    final newTranscription = state.transcription!.copyWith(transsegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void deleteSegment(int index) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.transsegments.length) {
      return;
    }
    final newSegments = List<Segment>.from(state.transcription!.transsegments)..removeAt(index);
    final newTranscription = state.transcription!.copyWith(transsegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  void updateCurrentWord() {
    if (state.transcription == null || state.transcription!.transsegments.isEmpty) return;
    if (_userSelectedWord) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    final index = _binarySearch(state.transcription!.transsegments, currentMillis);
    if (index != -1) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));
    }
  }

  void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.transsegments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = state.transcription!.transsegments[index];
    final startMillis = (segment.start * 1000).toInt();
    final endMillis = (segment.end * 1000).toInt();
    audioPlayer.seek(Duration(milliseconds: startMillis));
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));

    if (_wordPlayTimer != null && _wordPlayTimer!.isActive) {
      _wordPlayTimer!.cancel();
    }

    if (state.extradata!.playAndStopWordOnSelect) {
      if (_isPlayingWord) {
        audioPlayer.pause();
      }
      _isPlayingWord = true;
      audioPlayer.resume();
      _wordPlayTimer = Timer(Duration(milliseconds: endMillis - startMillis), () {
        audioPlayer.pause();
        _isPlayingWord = false;
      });
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      _userSelectedWord = false;
    });
  }

  void togglePlayAndStopWordOnSelect() {
    emit(state.copyWith(extradata: state.extradata?.copyWith(playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect)));
  }

  void showContextMenu(BuildContext context, Offset position, List<int> selectedIndexes) {
    List<String> selectedTags = [];
    if (selectedIndexes.isNotEmpty) {
      selectedTags = state.transcription!.transsegments[selectedIndexes.first].tags;
    } else {
      final index = _getSegmentIndexFromOffset(position);
      if (index != -1) {
        selectedTags = state.transcription!.transsegments[index].tags;
      }
    }
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SegmentContextMenu(
            availableTags: availableTags.keys.toList(),
            selectedTags: selectedTags,
            editMode: state.editMode,
            onTagAdded: (tag) {
              if (selectedIndexes.isNotEmpty) {
                for (int index in selectedIndexes) {
                  addTagToSegment(index, tag);
                }
              } else {
                final index = _getSegmentIndexFromOffset(position);
                if (index != -1) {
                  addTagToSegment(index, tag);
                }
              }
            },
            onTagRemoved: (tag) {
              if (selectedIndexes.isNotEmpty) {
                for (int index in selectedIndexes) {
                  removeTagFromSegment(index, tag);
                }
              } else {
                final index = _getSegmentIndexFromOffset(position);
                if (index != -1) {
                  removeTagFromSegment(index, tag);
                }
              }
            },
            onEdit: () {
              Navigator.of(context).pop();
              if (selectedIndexes.isNotEmpty) {
                _editSegments(context, selectedIndexes);
              } else {
                final index = _getSegmentIndexFromOffset(position);
                if (index != -1) {
                  _editSegment(context, index);
                }
              }
            },
            onDelete: () {
              Navigator.of(context).pop();
              if (selectedIndexes.isNotEmpty) {
                for (int index in selectedIndexes) {
                  deleteSegment(index);
                }
              } else {
                final index = _getSegmentIndexFromOffset(position);
                if (index != -1) {
                  deleteSegment(index);
                }
              }
            },
            selectedIndexes: selectedIndexes,
          ),
        );
      },
    );
  }

  int _getSegmentIndexFromOffset(Offset position) {
    if (state.transcription == null) return -1;
    final RenderBox box = scrollController.position.context.storageContext.findRenderObject() as RenderBox;
    final result = BoxHitTestResult();
    final local = box.globalToLocal(position);
    if (box.hitTest(result, position: local)) {
      for (final hit in result.path) {
        final target = hit.target;
        if (target is RenderParagraph) {
          final offset = target.getPositionForOffset(local);
          final wordIndex = offset.offset;
          return wordIndex;
        }
      }
    }
    return -1;
  }

  int _binarySearch(List<Segment> segments, int target) {
    int left = 0;
    int right = segments.length - 1;
    while (left <= right) {
      int mid = left + ((right - left) ~/ 2);
      final segment = segments[mid];
      final startMillis = (segment.start * 1000).toInt();
      final endMillis = (segment.end * 1000).toInt();
      if (target >= startMillis && target <= endMillis) {
        return mid;
      } else if (target < startMillis) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return -1;
  }

  void _editSegment(BuildContext context, int index) {
    final segment = state.transcription!.transsegments[index];
    String newText = segment.word;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Segmento'),
          content: TextField(
            controller: TextEditingController(text: newText),
            onChanged: (value) {
              newText = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final newSegment = segment.copyWith(word: newText);
                editSegment(newSegment);
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _editSegments(BuildContext context, List<int> indexes) {
    if (indexes.isEmpty) return;
    String newText = state.transcription!.transsegments[indexes.first].word;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Segmentos'),
          content: TextField(
            controller: TextEditingController(text: newText),
            onChanged: (value) {
              newText = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                editSegments(indexes, newText);
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
