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
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/utils/compare_segments_utils.dart';

import 'mockData/textotest.dart';
import 'models/alignment_mfa_data.dart';
import 'models/comparation_model.dart';
import 'models/patience_diff.dart';
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

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit() : super(const TranscriptionState(status: TranscriptionStatus.initial)) {
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
    'Omisioa': Colors.grey[300]!,
    'Ordezkapena': Colors.grey[300]!,
    'Asmaketa': Colors.grey[300]!,
    'Berrirakurtzea': Colors.grey[300]!,
    'Zuzenketa': Colors.grey[300]!,
    'Gehikuntza': Colors.grey[300]!,
    'Inbertsioa': Colors.grey[300]!,
    'Jauzia': Colors.grey[300]!,
    'Errepikapena': Colors.grey[300]!,
  };
/*static Map<String, Color> availableTags = {
    'Omisioa': Colors.grey[100]!,
    'Ordezkapena': Colors.grey[200]!,
    'Asmaketa': Colors.grey[300]!,
    'Berrirakurtzea': Colors.grey[400]!,
    'Zuzenketa': Colors.grey[500]!,
    'Gehikuntza': Colors.grey[600]!,
    'Inbertsioa': Colors.grey[100]!,
    'Jauzia': Colors.grey[200]!,
    'Errepikapena': Colors.grey[300]!,
  };
static Map<String, Color> availableTags = {
    'Omisioa': Colors.limeAccent[400]!,
    'Ordezkapena': Colors.yellowAccent[400]!,
    'Asmaketa': Colors.orangeAccent[400]!,
    'Berrirakurtzea': Colors.redAccent[400]!,
    'Zuzenketa': Colors.pinkAccent[400]!,
    'Gehikuntza': Colors.purpleAccent[400]!,
    'Inbertsioa': Colors.blueAccent[400]!,
    'Jauzia': Colors.cyanAccent[400]!,
    'Errepikapena': Colors.greenAccent[400]!,
  };
static Map<String, Color> availableTags = {
    'Omisioa': Colors.brown[200]!,
    'Ordezkapena': Colors.brown[300]!,
    'Asmaketa': Colors.brown[400]!,
    'Berrirakurtzea': Colors.green[600]!,
    'Zuzenketa': Colors.green[700]!,
    'Gehikuntza': Colors.green[800]!,
    'Inbertsioa': Colors.lime[600]!,
    'Jauzia': Colors.lime[700]!,
    'Errepikapena': Colors.lime[800]!,
  };
static Map<String, Color> availableTags = {
    'Omisioa': Colors.pink[200]!,
    'Ordezkapena': Colors.pink[300]!,
    'Asmaketa': Colors.pink[400]!,
    'Berrirakurtzea': Colors.pink[500]!,
    'Zuzenketa': Colors.purple[300]!,
    'Gehikuntza': Colors.purple[400]!,
    'Inbertsioa': Colors.deepPurple[300]!,
    'Jauzia': Colors.deepPurple[400]!,
    'Errepikapena': Colors.deepPurple[500]!,
  };
static Map<String, Color> availableTags = {
    'Omisioa': Colors.lightBlue[200]!,
    'Ordezkapena': Colors.lightBlue[300]!,
    'Asmaketa': Colors.lightBlue[400]!,
    'Berrirakurtzea': Colors.lightBlue[500]!,
    'Zuzenketa': Colors.cyan[300]!,
    'Gehikuntza': Colors.cyan[400]!,
    'Inbertsioa': Colors.teal[300]!,
    'Jauzia': Colors.teal[400]!,
    'Errepikapena': Colors.teal[500]!,
  };

  static Map<String, Color> availableTags = {
    'Omisioa': Colors.red[200]!,
    'Ordezkapena': Colors.red[300]!,
    'Asmaketa': Colors.red[400]!,
    'Berrirakurtzea': Colors.red[500]!,
    'Zuzenketa': Colors.orange[300]!,
    'Gehikuntza': Colors.orange[400]!,
    'Inbertsioa': Colors.deepOrange[300]!,
    'Jauzia': Colors.deepOrange[400]!,
    'Errepikapena': Colors.deepOrange[500]!,
  };

  static Map<String, Color> availableTags = {
    'Omisioa': Colors.blue[200]!,
    'Ordezkapena': Colors.blue[300]!,
    'Asmaketa': Colors.blue[400]!,
    'Berrirakurtzea': Colors.blue[500]!,
    'Zuzenketa': Colors.indigo[300]!,
    'Gehikuntza': Colors.indigo[400]!,
    'Inbertsioa': Colors.deepPurple[300]!,
    'Jauzia': Colors.deepPurple[400]!,
    'Errepikapena': Colors.deepPurple[500]!,
  };
  static Map<String, Color> availableTags = {
    'Omisioa': Colors.blue[200]!,
    'Ordezkapena': Colors.blue[300]!,
    'Asmaketa': Colors.blue[400]!,
    'Berrirakurtzea': Colors.blue[500]!,
    'Zuzenketa': Colors.indigo[300]!,
    'Gehikuntza': Colors.indigo[400]!,
    'Inbertsioa': Colors.deepPurple[300]!,
    'Jauzia': Colors.deepPurple[400]!,
    'Errepikapena': Colors.deepPurple[500]!,
  };*/
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
      emit(state.copyWith(status: TranscriptionStatus.loaded));
    });
    socket.onDisconnect((_) => print('disconnect'));
    socket.on('connect_error', (data) {
      print('connect_error: $data');
      emit(state.copyWith(status: TranscriptionStatus.noserver));
    });
    socket.on('connect_timeout', (data) {
      print('connect_timeout: $data');
      emit(state.copyWith(status: TranscriptionStatus.noserver));
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
        emit(state.copyWith(status: TranscriptionStatus.isPlayerplaying));
      } else if (s == PlayerState.paused) {
        emit(state.copyWith(status: TranscriptionStatus.isPlayerpause));
      } else if (s == PlayerState.stopped) {
        emit(state.copyWith(status: TranscriptionStatus.isPlayerstopped));
      } else if (s == PlayerState.completed) {
        emit(state.copyWith(status: TranscriptionStatus.isPlayercompleted));
      }
    });
    audioPlayer.onPlayerComplete.listen((event) {
      emit(state.copyWith(status: TranscriptionStatus.isPlayercompleted));
    });
  }

  Future<void> alignAudio(PlatformFile audioFile, String text) async {
    emit(state.copyWith(status: TranscriptionStatus.loading));
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
        emit(state.copyWith(status: TranscriptionStatus.loaded));
      } else {
        print("Error en la respuesta: ${response.statusCode}");
        print("Cuerpo de la respuesta: ${response.body}");
        throw Exception('Failed to align audio');
      }
    } catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscriptionStatus.error));
    }
  }

  Future<void> transcribeAudio(PlatformFile audioFile) async {
    emit(state.copyWith(status: TranscriptionStatus.loading));
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

        transcription = Transcription.fromListMap(jsonResponse['transcription'], realText: "");
        //fullTextTranscription = _transcription!.fulltext!;
        //melSpectrogramBase64 = jsonResponse['mel_spectrogram'];
        //waveformImageBase64 = jsonResponse['waveform_image'];

        //realtextComoTranscription = Transcription(segments: transcription!.realsegments!);
        //compararActualTranscription();
        //calculateWordsWithSpans(transcription!); // Add this line

        emit(
          state.copyWith(
            status: TranscriptionStatus.loaded,
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
        emit(state.copyWith(status: TranscriptionStatus.error, errorMessage: "Error en la respuesta: ${response.statusCode}"));
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
      emit(state.copyWith(status: TranscriptionStatus.error, errorMessage: errorMessage));
    } finally {
      emit(state.copyWith(status: TranscriptionStatus.loaded));
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
    emit(state.copyWith(status: TranscriptionStatus.loading));
    String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_test_normalized.json');
    //String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_normalized.json');
    print("transcriptionWhisper jsonString --> $jsonString");
    List<dynamic> jsonList = json.decode(jsonString);
    List<Map<String, dynamic>> listMap = jsonList.map((item) => item as Map<String, dynamic>).toList();

    String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK_test.txt');
    //String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');

    // Formatear el texto real usando la nueva función
    final formattedRawRealText = formatTextIntoParagraphs(text);
    print("formattedRawRealText --> $formattedRawRealText");

    final transcription = Transcription.fromListMap(listMap, realText: formattedRawRealText);
    //final alignedSegments = _createAlignedSegments(formattedRawRealText, transcription.transcriptionSegments);

    // Asignar el texto real a la transcripción
    transcription.realText = formattedRawRealText;

    // Asociar las palabras
    transcription.associateWords();

    // Realizar el alineamiento complejo
    final alignedSegments = transcription.alignSegmentsToRealText();

    print(transcription.getAssociatedSegmentsInfo());
    //print(transcription.getAlignedSegmentsInfo());

    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));

    // Actualizar el estado
    emit(state.copyWith(status: TranscriptionStatus.success, transcription: transcription.copyWith(alignedSegments: alignedSegments), textoRealformadoparrafos: formattedRawRealText));
  }

  Future<void> useMockTranscriptionES() async {
    emit(state.copyWith(status: TranscriptionStatus.loading));

    String text = await rootBundle.loadString('assets/texto_LA_TORTUGA_KALI.txt');

    String formattedText = formatTextIntoParagraphs(text);
    textoRealformadoparrafos = formattedText;
    transcription = Transcription.fromListMap(textoTransMock, realText: textoRealformadoparrafos);

    // Llamar a associateWords en lugar de calculateWordsWithSpans
    transcription!.associateWords();

    // Imprimir información de las asociaciones
    for (int i = 0; i < transcription!.transcribedSegments.length; i++) {
      final segment = transcription!.transcribedSegments[i];
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
    emit(state.copyWith(status: TranscriptionStatus.loaded, transcription: transcription, textoRealformadoparrafos: textoRealformadoparrafos));
  }

  void toggleEditMode() {
    emit(state.copyWith(editMode: !state.editMode));
  }

  void addTagToSegment(int index, String tag) {
    /*if (state.transcription == null || index < 0 || index >= state.transcription!.transcribedSegments.length) {
      return;
    }
    final segment = state.transcription!.transcribedSegments[index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.transcribedSegments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transcriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));*/
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawRealTextSegments!.length) {
      return;
    }
    final segment = state.transcription!.rawRealTextSegments![index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.rawRealTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(rawRealTextSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void removeTagFromSegment(int index, String tag) {
    /*if (state.transcription == null || index < 0 || index >= state.transcription!.transcribedSegments.length) {
      return;
    }
    final segment = state.transcription!.transcribedSegments[index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.transcribedSegments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transcriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));*/
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawRealTextSegments!.length) {
      return;
    }
    final segment = state.transcription!.rawRealTextSegments![index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.rawRealTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(rawRealTextSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegment(Segment newSegment) {
    if (state.transcription == null) return;
    final index = state.transcription!.rawRealTextSegments!.indexOf(newSegment);
    if (index == -1) return;
    final newSegments = List<Segment>.from(state.transcription!.rawRealTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(transcriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegments(List<int> indexes, String newText) {
    if (state.transcription == null || indexes.isEmpty) return;
    final newSegments = List<Segment>.from(state.transcription!.rawRealTextSegments!);
    for (int index in indexes) {
      if (index >= 0 && index < newSegments.length) {
        final segment = newSegments[index];
        final newSegment = segment.copyWith(word: newText);
        newSegments[index] = newSegment;
      }
    }
    final newTranscription = state.transcription!.copyWith(transcriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void deleteSegment(int index) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawRealTextSegments!.length) {
      return;
    }
    final newSegments = List<Segment>.from(state.transcription!.rawRealTextSegments!)..removeAt(index);
    final newTranscription = state.transcription!.copyWith(transcriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  void updateCurrentWord() {
    if (state.transcription == null || state.transcription!.transcribedSegments.isEmpty) return;
    if (_userSelectedWord) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    final index = _binarySearch(state.transcription!.transcribedSegments, currentMillis);
    if (index != -1) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));
    }
  }

  void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.transcribedSegments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = state.transcription!.transcribedSegments[index];
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

  void forceCurrentAssociatedWord(int index) {
    if (state.transcription == null || state.transcription!.transcribedSegments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = state.transcription!.associatedSegments![index];
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
      selectedTags = state.transcription!.rawRealTextSegments![selectedIndexes.first].tags;
    } else {
      final index = _getSegmentIndexFromOffset(position);
      if (index != -1) {
        selectedTags = state.transcription!.rawRealTextSegments![index].tags;
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
    final segment = state.transcription!.rawRealTextSegments![index];
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
    String newText = state.transcription!.rawRealTextSegments![indexes.first].word;
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
