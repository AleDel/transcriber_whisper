import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
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

import 'mockData/textotest.dart';
import 'models/alignment_mfa_data.dart';
import 'models/segment.dart';

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit() : super(const TranscriptionState(status: TranscriptionStatus.initial)) {
    //initSocket();
    //initAudioPlayer();
    //_initializeAudioPlayer();
  }

  final ScrollController scrollController = ScrollController();
  //final AudioPlayer audioPlayer = AudioPlayer();
  final AudioPlayer audioPlayer = AudioPlayer(playerId: "Audioplayer 0"); // Ahora es final y se inicializa en el constructor
  //AudioPlayer audioPlayer = AudioPlayer(playerId: "el audio player 0");
  late IO.Socket socket;
  Transcription? transcription;
  String textoRealformadoparrafos = "";
  //Transcription? realtextComoTranscription;
  AlignmentMFAData? alignmentData_texto; // alineamiento del audio con el texto escrito
  bool _autoScrollEnabled = true;
  bool _userSelectedWord = false;
  bool _isPlayingWord = false;
  bool _isSeeking = false;
  bool _isForceCurrentWord = false;
  int currentAudioWordIndex = -1;
  int currentAssociatedWordIndex = -1;
  Map<String, int> _segmentIndexMap = {};
  int? _oldCurrentWordIndex;
  Timer? _wordPlayTimer;
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;
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

        transcription = Transcription.fromListMap(referenceText: "", listMap: jsonResponse['transcription']);
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

  void resetState() {
    emit(const TranscriptionState(status: TranscriptionStatus.loading));
  }

  Future<void> useMockTranscriptionEU() async {
    emit(state.copyWith(status: TranscriptionStatus.loading));
    //String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_test_normalized.json');
    //String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_test0_normalized.json');
    //String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_test1_normalized.json');
    //String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_test2_normalized.json');
    String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_normalized.json');
    //print("transcriptionWhisper jsonString --> $jsonString");
    List<dynamic> jsonList = json.decode(jsonString);
    List<Map<String, dynamic>> listMap = jsonList.map((item) => item as Map<String, dynamic>).toList();

    //String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK_test0.txt');
    //String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK_test1.txt');
    //String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK_test2.txt');
    //String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK_test.txt');
    String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');

    // Formatear el texto real usando la nueva función
    final formattedRawRealText = formatTextIntoParagraphs(text);
    //print("formattedRawRealText --> $formattedRawRealText");

    transcription = Transcription.fromListMap(listMap: listMap, shouldInsertPunctuation: true, referenceText: formattedRawRealText);

    // Asignar el texto real a la transcripción
    transcription?.referenceText = formattedRawRealText;

    // Llamar a la función para imprimir la información
    //transcription.printWordAlignmentSegmentsInfo();

    //initAudioPlayer();
    await initAudioPlayer();
    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));

    // Actualizar el estado
    emit(state.copyWith(status: TranscriptionStatus.success, transcription: transcription, textoRealformadoparrafos: formattedRawRealText));

    _createSegmentIndexMap();
  }

  void _createSegmentIndexMap() {
    _segmentIndexMap = {};
    if (state.transcription!.audioTranscriptionSegments != null) {
      for (int i = 0; i < state.transcription!.audioTranscriptionSegments.length; i++) {
        final segment = state.transcription!.audioTranscriptionSegments[i];
        final segmentKey = "${segment.start}-${segment.end}";
        _segmentIndexMap[segmentKey] = i;
      }
    }
  }

  Future<void> useMockTranscriptionES() async {
    emit(state.copyWith(status: TranscriptionStatus.loading));

    String text = await rootBundle.loadString('assets/texto_LA_TORTUGA_KALI.txt');

    // Formatear el texto real usando la nueva función
    final formattedRawRealText = formatTextIntoParagraphs(text);
    //print("formattedRawRealText --> $formattedRawRealText");

    transcription = Transcription.fromListMap(listMap: textoTransMock, shouldInsertPunctuation: true, referenceText: formattedRawRealText);

    // Asignar el texto real a la transcripción
    transcription?.referenceText = formattedRawRealText;

    /*String formattedText = formatTextIntoParagraphs(text);
    textoRealformadoparrafos = formattedText;
    transcription = Transcription.fromListMap(listMap: textoTransMock, referenceText: textoRealformadoparrafos);*/

    // Imprimir información de las asociaciones
    /*for (int i = 0; i < transcription!.audioTranscriptionSegments.length; i++) {
      final segment = transcription!.audioTranscriptionSegments[i];
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
    }*/

    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_es.wav'));
    emit(state.copyWith(status: TranscriptionStatus.loaded, transcription: transcription, textoRealformadoparrafos: formattedRawRealText));
    _createSegmentIndexMap();

  }

  ///////////////////

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
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawReferenceTextSegments!.length) {
      return;
    }
    final segment = state.transcription!.rawReferenceTextSegments![index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.rawReferenceTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(rawReferenceTextSegments: newSegments);
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
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawReferenceTextSegments!.length) {
      return;
    }
    final segment = state.transcription!.rawReferenceTextSegments![index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.rawReferenceTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(rawReferenceTextSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegment(Segment newSegment) {
    if (state.transcription == null) return;
    final index = state.transcription!.rawReferenceTextSegments!.indexOf(newSegment);
    if (index == -1) return;
    final newSegments = List<Segment>.from(state.transcription!.rawReferenceTextSegments!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(audioTranscriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegments(List<int> indexes, String newText) {
    if (state.transcription == null || indexes.isEmpty) return;
    final newSegments = List<Segment>.from(state.transcription!.rawReferenceTextSegments!);
    for (int index in indexes) {
      if (index >= 0 && index < newSegments.length) {
        final segment = newSegments[index];
        final newSegment = segment.copyWith(word: newText);
        newSegments[index] = newSegment;
      }
    }
    final newTranscription = state.transcription!.copyWith(audioTranscriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void deleteSegment(int index) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.rawReferenceTextSegments!.length) {
      return;
    }
    final newSegments = List<Segment>.from(state.transcription!.rawReferenceTextSegments!)..removeAt(index);
    final newTranscription = state.transcription!.copyWith(audioTranscriptionSegments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  ////////////// audio sync

  void stopAudioPlayer() async {
    await audioPlayer.stop();
  }
  Future<void> restartAudioPlayer() async {
    //await audioPlayer.stop();
    //await audioPlayer.setSource(BytesSource(Uint8List(0)));
    await audioPlayer.setSource(AssetSource('/audio/audio_prueba_es.wav'));
  }

  Future<void> initAudioPlayer() async {
    print("-- initAudioPlayer --");
    /*if (audioPlayer != null) {
      print("-- initAudioPlayer -- Dispose el AudioPlayer antiguo: ${audioPlayer.playerId}");
      print("audioPlayer.mode.name: ${audioPlayer.mode.name}");
      print("audioPlayer.releaseMode.name: ${audioPlayer.releaseMode.name}");

      //audioPlayer.setReleaseMode(releaseMode)
      audioPlayer.release();
      audioPlayer.dispose();
    }*/
    //await restartAudioPlayer();
    print("-- initAudioPlayer -- Creando nueva instancia de AudioPlayer y listeners");
    //audioPlayer = AudioPlayer(); // Ya no es necesario
    //await audioPlayer.setReleaseMode(ReleaseMode.stop);
    //await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));
    print("-- initAudioPlayer Nuevo -- ${audioPlayer.playerId}");
    audioPlayer.onDurationChanged.listen((Duration d) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioDuration: d)));
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioPosition: p)));
      updateCurrentWord(); // Actualizar la palabra actual en cada cambio de posición
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
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentAudioWordIndex: 0, currentAssociatedWordIndex: 0)));
  }


  // Actualiza la palabra actual basándose en la posición del audio
  void updateCurrentWord() {
    //print("sssssssssssssss");
    if (audioPlayer.state != PlayerState.playing) return; // Comprobar si el audio se esta reproduciendo
    if (state.transcription == null) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;

    // Buscar en audioTranscriptionSegments
    if (state.transcription!.audioTranscriptionSegments.isNotEmpty) {
      currentAudioWordIndex = _binarySearch(state.transcription!.audioTranscriptionSegments, currentMillis);
    }
    //print("sssssssssssssss buscando indice de la palabra en la transcripcion desde la posicion del audio en milisegundo con _binarySearch --> currentWordIndex: $currentAudioWordIndex");
    if (currentAudioWordIndex == -1) {
      return;
    }
    //print("sssssssssssssss palabra de la transcripcion: $currentAudioWordIndex. ${state.transcription!.audioTranscriptionSegments[currentAudioWordIndex].word}");

    // Buscar en wordAlignmentSegments
    if (state.transcription!.wordAlignmentSegments != null && state.transcription!.wordAlignmentSegments!.isNotEmpty) {
      // Si de la posicion del audo encontro la palabra en audioTranscriptionSegments
      if (state.extradata!.currentWordIndex != null || currentAudioWordIndex != -1) {
        final forcedSegment = state.transcription!.audioTranscriptionSegments[state.extradata!.currentWordIndex!];
        if (currentMillis < (forcedSegment.start * 1000).toInt() || currentMillis > (forcedSegment.end * 1000).toInt()) {
          _isForceCurrentWord = false; // Reset the flag
          // Buscar la asociación correcta para la nueva palabra
          final segmentKey =
              "${state.transcription!.audioTranscriptionSegments[currentAudioWordIndex].start}-${state.transcription!.audioTranscriptionSegments[currentAudioWordIndex].end}";
          for (int i = 0; i < state.transcription!.wordAlignmentSegments!.length; i++) {
            final associatedSegment = state.transcription!.wordAlignmentSegments![i];
            if (associatedSegment.transcribedIndex == _segmentIndexMap[segmentKey]) {
              currentAssociatedWordIndex = i;
              break;
            }
          }
          // Si no se encontró una asociación directa, buscar la coincidencia más cercana
          if (currentAssociatedWordIndex != -1) {
            //print("sssssssssssssss palabra de wordAlignmentSegments: $currentAssociatedWordIndex. ${state.transcription!.wordAlignmentSegments[currentAssociatedWordIndex].word}");
          }
          if (currentAssociatedWordIndex == -1) {
            return; // Do nothing
          }
        } else {
          return; // Do nothing if a word is being forced
        }
      }
    }
    //print("ssssssssssss emitiendo -----> currentWordIndex: $currentAudioWordIndex, currentAssociatedWordIndex: $currentAssociatedWordIndex");
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentAudioWordIndex: currentAudioWordIndex, currentAssociatedWordIndex: currentAssociatedWordIndex)));
    //print("Fin -- updateCurrentWord");
  }
  /*void updateCurrentWord() {
    print("sssssssssssssss");
    if (audioPlayer.state != PlayerState.playing) return; // Comprobar si el audio se esta reproduciendo
    if (state.transcription == null) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    int currentWordIndex = -1;
    int currentAssociatedWordIndex = -1;
    // Buscar en audioTranscriptionSegments
    if (state.transcription!.audioTranscriptionSegments.isNotEmpty) {
      currentWordIndex = _binarySearch(state.transcription!.audioTranscriptionSegments, currentMillis);
    }
    // Buscar en wordAlignmentSegments
    if (state.transcription!.wordAlignmentSegments != null && state.transcription!.wordAlignmentSegments!.isNotEmpty) {
      currentAssociatedWordIndex = _binarySearchAssociated(state.transcription!.wordAlignmentSegments!, currentMillis);
      if(currentAssociatedWordIndex == -1 && currentWordIndex != -1){
        currentAssociatedWordIndex = _binarySearchAssociated(state.transcription!.wordAlignmentSegments!, currentMillis);
      }
      if (_isForceCurrentWord) {
        // Check if the current position is outside the bounds of the forced word
        if (state.extradata!.currentWordIndex != null) {
          final forcedSegment = state.transcription!.audioTranscriptionSegments[state.extradata!.currentWordIndex!];
          if (currentMillis < (forcedSegment.start * 1000).toInt() || currentMillis > (forcedSegment.end * 1000).toInt()) {
            _isForceCurrentWord = false; // Reset the flag
            currentAssociatedWordIndex = -1;
          } else {
            return; // Do nothing if a word is being forced
          }
        }
      }
    }
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: currentWordIndex, currentAssociatedWordIndex: currentAssociatedWordIndex)));
  }*/

  /////////////probarlu ego
  // Fuerza la palabra actual a un índice específico (cuando el usuario hace clic)
  /*void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.audioTranscriptionSegments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return; // Evita llamadas muy seguidas
    }
    _lastForceCurrentWordCall = now;
    _isForceCurrentWord = true; // Indicar que se ha forzado la palabra
    final segment = state.transcription!.audioTranscriptionSegments[index];
    final startMillis = (segment.start * 1000).toInt();

    // Check if the audio is playing
    if (audioPlayer.state == PlayerState.playing) {
      audioPlayer.pause(); // Pause if playing
    } else {
      audioPlayer.seek(Duration(milliseconds: startMillis)); // Seek to the new position
      audioPlayer.resume(); // Resume if not playing
    }

    // Buscar el indice de la palabra asociada
    int associatedWordIndex = -1;
    if(state.transcription!.wordAlignmentSegments != null){
      // Buscar la palabra asociada correcta
      for (int i = 0; i < state.transcription!.wordAlignmentSegments!.length; i++) {
        final associatedSegment = state.transcription!.wordAlignmentSegments![i];
        // Comprobar si la palabra asociada coincide con la palabra en la que se hizo clic
        if (associatedSegment.audioSegmentIndex == index) {
          associatedWordIndex = i;
          break;
        }
      }
      // Si no se encontró una asociación directa, buscar la coincidencia más cercana
      if (associatedWordIndex == -1) {
        for (int i = 0; i < state.transcription!.wordAlignmentSegments!.length; i++) {
          final associatedSegment = state.transcription!.wordAlignmentSegments![i];
          if (associatedSegment.start == segment.start && associatedSegment.end == segment.end) {
            associatedWordIndex = i;
            break;
          }
        }
      }
    }
    print("llamado forceCurrentWord con index $index : resultado: currentWordIndex $index associatedWordIndex $associatedWordIndex");
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index, currentAssociatedWordIndex: associatedWordIndex)));
  }*/

  // Fuerza la palabra actual a un índice específico (cuando el usuario hace clic)
  void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.audioTranscriptionSegments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return; // Evita llamadas muy seguidas
    }
    _lastForceCurrentWordCall = now;
    _isForceCurrentWord = true; // Indicar que se ha forzado la palabra
    final segment = state.transcription!.audioTranscriptionSegments[index];
    final startMillis = (segment.start * 1000).toInt();

    // Check if the audio is playing
    if (audioPlayer.state == PlayerState.playing) {
      audioPlayer.pause(); // Pause if playing
    } else {
      audioPlayer.seek(Duration(milliseconds: startMillis)); // Seek to the new position
      audioPlayer.resume(); // Resume if not playing
    }

    // Buscar el indice de la palabra asociada
    int associatedWordIndex = -1;
    if (state.transcription!.wordAlignmentSegments != null) {
      for (int i = 0; i < state.transcription!.wordAlignmentSegments!.length; i++) {
        final associatedSegment = state.transcription!.wordAlignmentSegments![i];
        if (associatedSegment.start == segment.start && associatedSegment.end == segment.end) {
          associatedWordIndex = i;
          break;
        }
      }
    }
    print("llamado forceCurrentWord con index $index : resultado: currentWordIndex $index associatedWordIndex $associatedWordIndex");
    emit(state.copyWith(extradata: state.extradata?.copyWith(currentAudioWordIndex: index, currentAssociatedWordIndex: associatedWordIndex)));
  }

  // Búsqueda binaria en la lista de segmentos de audio
  int _binarySearch(List<Segment> segments, int target) {
    //print("_binarySearch");
    int left = 0;
    int right = segments.length - 1;
    while (left <= right) {
      int mid = left + ((right - left) ~/ 2);
      final segment = segments[mid];
      final startMillis = (segment.start * 1000).toInt();
      final endMillis = (segment.end * 1000).toInt();
      if (target >= startMillis && target < endMillis) {
        return mid; // Encontrado
      } else if (target < startMillis) {
        right = mid - 1; // Buscar en la mitad izquierda
      } else {
        left = mid + 1; // Buscar en la mitad derecha
      }
    }
    return -1; // No encontrado
  }

  // Búsqueda binaria en la lista de segmentos alineados con el texto real
  int _binarySearchAssociated(List<Segment> segments, int target) {
    //print("_binarySearchAssociated");
    int left = 0;
    int right = segments.length - 1;
    while (left <= right) {
      int mid = left + ((right - left) ~/ 2);
      final segment = segments[mid];
      final startMillis = (segment.start * 1000).toInt();
      final endMillis = (segment.end * 1000).toInt();
      if (target >= startMillis && target < endMillis) {
        // Cambio aquí: target < endMillis
        return mid; // Encontrado
      } else if (target < startMillis) {
        right = mid - 1; // Buscar en la mitad izquierda
      } else {
        left = mid + 1; // Buscar en la mitad derecha
      }
    }
    return -1; // No encontrado
  }

  void togglePlayAndStopWordOnSelect() {
    emit(state.copyWith(extradata: state.extradata?.copyWith(playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect)));
  }
  /////////////////

  void showContextMenu(BuildContext context, Offset position, List<int> selectedIndexes) {
    List<String> selectedTags = [];
    if (selectedIndexes.isNotEmpty) {
      selectedTags = state.transcription!.rawReferenceTextSegments![selectedIndexes.first].tags;
    } else {
      final index = _getSegmentIndexFromOffset(position);
      if (index != -1) {
        selectedTags = state.transcription!.rawReferenceTextSegments![index].tags;
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

  void _editSegment(BuildContext context, int index) {
    final segment = state.transcription!.rawReferenceTextSegments![index];
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
    String newText = state.transcription!.rawReferenceTextSegments![indexes.first].word;
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
