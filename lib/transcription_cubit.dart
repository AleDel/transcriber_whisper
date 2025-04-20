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
import 'package:path_provider/path_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/transcription_state.dart';

import 'mockData/textotest.dart';
import 'models/alignment_mfa_data.dart';
import 'models/segment.dart';

import 'dart:html' as html; // Import for web-specific functionality
import 'package:flutter/foundation.dart' show kIsWeb; // Import for web detection

class TranscriptionCubit extends Cubit<TranscriptionState> {
  TranscriptionCubit() : super(const TranscriptionState(status: TranscriptionStatus.initial)) {
    //initSocket();
    //initAudioPlayer();
    _initAudioPlayer();
  }

  final ScrollController scrollController = ScrollController();
  //final AudioPlayer audioPlayer = AudioPlayer();
  AudioPlayer audioPlayer = AudioPlayer(playerId: "Audioplayer 0");
  late IO.Socket socket;
  Transcription? transcription;
  String textoRealformadoparrafos = "";
  //Transcription? realtextComoTranscription;
  AlignmentMFAData? alignmentData_texto; // alineamiento del audio con el texto escrito
  bool _autoScrollEnabled = true;
  bool _isForceCurrentWord = false;
  int currentAudioWordIndex = -1;
  int currentAssociatedWordIndex = -1;
  Map<String, int> _segmentIndexMap = {};
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;
  bool _audioLoaded = false;
  /*static Map<String, Color> availableTags = {
    'Omisioa': const Color(0xFFE57373), // Red 300 (Rojo Suave)
    'Ordezkapena': const Color(0xFFFFA726), // Orange 400 (Naranja Medio)
    'Asmaketa': const Color(0xFFFFEB3B), // Yellow 500 (Amarillo Intenso)
    'Berrirakurtzea': const Color(0xFF66BB6A), // Green 400 (Verde Medio)
    'Zuzenketa': const Color(0xFF29B6F6), // Light Blue 400 (Azul Claro Medio)
    'Gehikuntza': const Color(0xFF26C6DA), // Cyan 400 (Cian Medio)
    'Inbertsioa': const Color(0xFFAB47BC), // Purple 400 (Morado Medio)
    'Jauzia': const Color(0xFF7E57C2), // Deep Purple 400 (Morado Oscuro Medio)
    'Errepikapena': const Color(0xFFEC407A), // Pink 500 (Rosa Intenso)
    'Puntuazioa': const Color(0xFF78909C), // Blue Grey 400 (Gris Azulado Medio)
  };*/
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
    'Puntuazioa': const Color(0xFF78909C), // Blue Grey 400 (Gris Azulado Medio)
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
    'Puntuazioa': '.',
  };
  String currentAudioUrl = '';

  String transcription_path = "";
  String original_audio_path = "";
  String normalized_audio_path = "";
  int audio_duration_seconds = 0;

  final String _baseUrl = 'http://localhost:5001';

  Future<void> saveAnalysisDataToJson() async {
    if (transcription == null) {
      print("Error: No hay transcripción para guardar.");
      return;
    }

    // 1. Data Extraction
    final String transcriptionPath = transcription_path;
    final String originalAudioPath = original_audio_path;
    final String normalizedAudioPath = normalized_audio_path;
    final int audioDurationSeconds = audio_duration_seconds;

    final int countDiffDeletions = transcription!.countDiffDeletions;
    final int countDiffInsertions = transcription!.countDiffInsertions;
    final int countDiffMatches = transcription!.countDiffMatches;

    final int countTranscriptionWords = transcription!.countTranscriptionWords;
    final int countReferenceWords = transcription!.countReferenceWords;

    final List<Segment> segments = transcription!.wordAlignmentSegmentsWithPunctuation!;

    // 2. Error Summary
    Map<String, int> errorSummary = {};
    for (String tag in availableTags.keys) {
      errorSummary[tag] = 0;
    }
    for (Segment segment in segments) {
      print("segment.tags: ${segment.tags}");
      for (String tag in segment.tags) {
        if (errorSummary.containsKey(tag)) {
          errorSummary[tag] = errorSummary[tag]! + 1;
        }
      }
    }

    /*// 3. Transcription Analysis
    List<Map<String, dynamic>> transcriptionAnalysis = [];
    for (Segment segment in segments) {
      if (segment.tags.isNotEmpty) {
        List<Map<String, dynamic>> errors = [];
        for (String tag in segment.tags) {
          errors.add({"error_tag": tagToSymbol[tag], "error_type": tag});
        }
        transcriptionAnalysis.add({"index": segment.,"word": segment.word, "errors": errors});
      }
    }*/
    // 3. Transcription Analysis
    List<Map<String, dynamic>> transcriptionAnalysis = [];
    for (int i = 0; i < segments.length; i++) {
      Segment segment = segments[i];
      if (segment.tags.isNotEmpty) {
        List<Map<String, dynamic>> errors = [];
        for (String tag in segment.tags) {
          errors.add({"error_tag": tagToSymbol[tag], "error_type": tag});
        }
        transcriptionAnalysis.add({"index": i, "word": segment.word, "errors": errors});
      }
    }

    // 4. JSON Structure
    Map<String, dynamic> jsonData = {
      "transcription_path": transcriptionPath,
      "original_audio_path": originalAudioPath,
      "normalized_audio_path": normalizedAudioPath,
      "audio_duration_seconds": audioDurationSeconds,
      "diff_analysis": {"insertions": countDiffInsertions, "deletions": countDiffDeletions, "matches": countDiffMatches},
      "word_count": {"reference_text": countReferenceWords, "transcription": countTranscriptionWords},
      "error_summary": errorSummary,
      "transcription_analysis": transcriptionAnalysis,
    };

    // 5. JSON Encoding
    String jsonString = jsonEncode(jsonData);

    // 6. File Saving
    // 6. File Download (Web-Specific)
    if (kIsWeb) {
      // Create a Blob object
      final blob = html.Blob([jsonString], 'application/json');

      // Create a URL for the Blob
      final url = html.Url.createObjectUrlFromBlob(blob);

      // Create an anchor element
      final anchor =
          html.document.createElement('a') as html.AnchorElement
            ..href = url
            ..style.display = 'none'
            ..download = 'analysis_data.json';

      // Add the anchor to the document
      html.document.body!.children.add(anchor);

      // Trigger a click event to start the download
      anchor.click();

      // Remove the anchor from the document
      html.document.body!.children.remove(anchor);

      // Release the URL
      html.Url.revokeObjectUrl(url);
    } else {
      // 6. File Saving (Mobile/Desktop)
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/analysis_data.json');
        await file.writeAsString(jsonString);
        print("JSON data saved to: ${file.path}");
      } catch (e) {
        print("Error saving JSON data: $e");
      }
    }
  }

  Future<void> loadAnalysisDataFromJson() async {
    if (kIsWeb) {
      // Web-specific file loading
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = 'application/json';
      input.click();

      await input.onChange.first;
      if (input.files!.isEmpty) return;
      final html.File file = input.files!.first;
      final html.FileReader reader = html.FileReader();
      reader.readAsText(file);
      await reader.onLoad.first;
      final jsonString = reader.result as String;
      _processLoadedJson(jsonString);
    } else {
      // Mobile/Desktop file loading
      try {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/analysis_data.json');
        final jsonString = await file.readAsString();
        _processLoadedJson(jsonString);
      } catch (e) {
        print("Error loading JSON data: $e");
      }
    }
  }

  void _processLoadedJson(String jsonString) {
    try {
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);

      // 1. Data Extraction
      transcription_path = jsonData["transcription_path"];
      original_audio_path = jsonData["original_audio_path"];
      normalized_audio_path = jsonData["normalized_audio_path"];
      audio_duration_seconds = jsonData["audio_duration_seconds"];

      final int countDiffDeletions = jsonData["diff_analysis"]["deletions"];
      final int countDiffInsertions = jsonData["diff_analysis"]["insertions"];
      final int countDiffMatches = jsonData["diff_analysis"]["matches"];

      final int countTranscriptionWords = jsonData["word_count"]["transcription"];
      final int countReferenceWords = jsonData["word_count"]["reference_text"];

      // 2. Error Summary (Not used for loading, but could be used for display)
      // final Map<String, int> errorSummary = Map<String, int>.from(jsonData["error_summary"]);

      // 3. Transcription Analysis
      final List<dynamic> transcriptionAnalysis = jsonData["transcription_analysis"];
      List<Segment> newSegments = [];
      if (transcription != null) {
        // reset tags
        transcription!.wordAlignmentSegmentsWithPunctuation.forEach((element) => element.tags.clear(),);

        newSegments = List<Segment>.from(transcription!.wordAlignmentSegmentsWithPunctuation);
        for (Map<String, dynamic> segmentData in transcriptionAnalysis) {
          final int index = segmentData["index"];
          if (index >= 0 && index < newSegments.length) {
            // Create a copy of the segment to avoid modifying the original segment directly
            Segment segment = newSegments[index].copyWith();
            segment.tags.clear(); // Clear existing tags
            final List<dynamic> errors = segmentData["errors"];
            for (Map<String, dynamic> errorData in errors) {
              segment.tags.add(errorData["error_type"]);
            }
            // Update the new list with the modified segment
            newSegments[index] = segment;
          }
        }
        // Update the transcription with the new list of segments
        final newTranscription = transcription!.copyWith(
          countDiffDeletions: countDiffDeletions,
          countDiffInsertions: countDiffInsertions,
          countDiffMatches: countDiffMatches,
          countTranscriptionWords: countTranscriptionWords,
          countReferenceWords: countReferenceWords,
          wordAlignmentSegmentsWithPunctuation: newSegments, // Update with the new list
        );
        transcription = newTranscription;
        emit(state.copyWith(transcription: newTranscription));
      }
    } catch (e) {
      print("Error processing JSON data: $e");
    }
  }

  /////////////////// Data input and comunication server
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

  //Future<void> processSharedFiles(){}
  void processSharedFiles(audioFile, textFile, jsonFile) {
    print("processSharedFiles ---------> $audioFile, $textFile, $jsonFile");
  }

  Future<void> checkAudio(String filename) async {
    emit(state.copyWith(status: TranscriptionStatus.checkingAudio));
    print('Verificando audio: $filename');
    final url = 'http://localhost:5001/checkaudio?filename=$filename';
    print("url: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("data: $data");
        final checkAudioResult = CheckAudioResult(
          isTranscribed: data['isTranscribed'],
          message: data['message'],
          nombreAudio: data['nombreAudio'],
          action: data['action'],
          status: data['status'], // Añadido el status
        );
        emit(state.copyWith(status: TranscriptionStatus.audioChecked, checkAudioResult: checkAudioResult));
      } else {
        final data = jsonDecode(response.body);
        final checkAudioResult = CheckAudioResult(
          isTranscribed: false,
          message: data['message'],
          status: data['status'], // Añadido el status
        );
        emit(state.copyWith(status: TranscriptionStatus.error, checkAudioResult: checkAudioResult));
      }
    } catch (e) {
      final checkAudioResult = CheckAudioResult(
        isTranscribed: false,
        message: 'Network error: $e',
        status: 'error', // Añadido el status
      );
      emit(state.copyWith(status: TranscriptionStatus.error, checkAudioResult: checkAudioResult));
    }
  }

  Future<void> checkServerStatus() async {
    emit(state.copyWith(status: TranscriptionStatus.checkingServerStatus));
    print('Verificando estado del servidor');
    final url = 'http://localhost:5001/statusServerTranscription';
    print("url: $url");
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("data: $data");
        final serverStatusResult = ServerStatusResult(
          file: data['file'],
          status: data['status'],
        );
        emit(state.copyWith(status: TranscriptionStatus.serverStatusChecked, serverStatusResult: serverStatusResult));
      } else {
        final serverStatusResult = ServerStatusResult(
          status: 'error',
        );
        emit(state.copyWith(status: TranscriptionStatus.error, serverStatusResult: serverStatusResult));
      }
    } catch (e) {
      final serverStatusResult = ServerStatusResult(
        status: 'error',
      );
      emit(state.copyWith(status: TranscriptionStatus.error, serverStatusResult: serverStatusResult));
    }
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
        //print(jsonResponse);
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
      final headers = {'Content-Type': 'application/json'}; // Cambiado a application/json
      String audioFilePath = "";
      if (audioFile.path != null) {
        audioFilePath = audioFile.path!;
      } else {
        throw Exception("No se pudo leer el archivo");
      }
      final body = jsonEncode({'audio_path': audioFilePath}); // Enviando el path en un JSON
      final response = await http.post(url, headers: headers, body: body);

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
      } else if (response.statusCode == 409) {
        var jsonResponse = jsonDecode(response.body);
        emit(state.copyWith(status: TranscriptionStatus.serverBusy, errorMessage: jsonResponse['error'], serverStatusResult: ServerStatusResult(file: jsonResponse['file'], status: 'busy')));
      } else if (response.statusCode == 400) {
        var jsonResponse = jsonDecode(response.body);
        emit(state.copyWith(status: TranscriptionStatus.error, errorMessage: jsonResponse['error']));
      } else if (response.statusCode == 404) {
        var jsonResponse = jsonDecode(response.body);
        emit(state.copyWith(status: TranscriptionStatus.error, errorMessage: jsonResponse['error']));
      } else if (response.statusCode == 500) {
        var jsonResponse = jsonDecode(response.body);
        emit(state.copyWith(status: TranscriptionStatus.error, errorMessage: jsonResponse['error']));
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
      //emit(state.copyWith(status: TranscriptionStatus.loaded));
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

  Future<void> fetchDataAndUseReal(String filename, String? text) async { // Cambiado referenceText por text
    print("aaaaaaaaaaaa: $text");
    emit(state.copyWith(status: TranscriptionStatus.loading));
    try {


      // 1. Llamar al servidor Flask para obtener los datos
      final queryParameters = {
        'filename': filename,
        if (text != null) 'referenceText': text, // Usamos text como referenceText
      };
      final uri = Uri.parse('$_baseUrl/get_data').replace(queryParameters: queryParameters);
      final response = await http.get(uri); // Usamos http.get

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // Decodificamos el JSON con jsonDecode

        // 2. Procesar la respuesta del servidor
        List<Map<String, dynamic>> listmap = List<Map<String, dynamic>>.from(data['transcription']);
        String? normalizedAudioUrl = data['normalized_audio_url'];
        String serverReferenceText = data['reference_text'] ?? ''; // Usar el texto del servidor si existe, si no vacio

        //print("normalizedAudioUrl: $normalizedAudioUrl, serverReferenceText: $serverReferenceText");

        if (normalizedAudioUrl != null) {
          print("existe el audio: $normalizedAudioUrl, _audioLoaded: $_audioLoaded");
          await useReal(listmap, '$_baseUrl$normalizedAudioUrl', serverReferenceText);
          if (!_audioLoaded) {
            currentAudioUrl = '$_baseUrl$normalizedAudioUrl';
            // Reiniciar el AudioPlayer antes de cargar un nuevo audio
            await resetAudioPlayer();
            await audioPlayer.setSource(UrlSource('$_baseUrl$normalizedAudioUrl'));
            print("AudioPlayer state after setSource: ${audioPlayer.state}");
            _audioLoaded = true;
          }
        } else {
          await useReal(listmap, '', serverReferenceText);
        }
      } else {
        emit(state.copyWith(status: TranscriptionStatus.error));
      }
    } catch (e) {
      print('Error en fetchDataAndUseReal: $e');
      emit(state.copyWith(status: TranscriptionStatus.error));
    }
  }

  Future<void> useReal(List<Map<String, dynamic>> listmap, String audioPath, String referenceText) async {
    emit(state.copyWith(status: TranscriptionStatus.loading));

    transcription = Transcription.fromListMap(listMap: listmap, shouldInsertPunctuation: true, referenceText: referenceText);

    // Asignar el texto real a la transcripción
    transcription?.referenceText = referenceText;

    //await initAudioPlayer();
    //await audioPlayer.setSource(UrlSource(audioPath));
    /*if(audioPath.isNotEmpty){
      //await initAudioPlayer(); // Eliminamos la llamada a initAudioPlayer
      await audioPlayer.setSource(UrlSource(audioPath));
    }*/

    // Actualizar el estado
    emit(state.copyWith(status: TranscriptionStatus.success, transcription: transcription, textoRealformadoparrafos: referenceText));

    _createSegmentIndexMap();
  }

  Future<void> useMockTranscriptionEU() async {
    emit(state.copyWith(status: TranscriptionStatus.loading));

    // Reiniciar el AudioPlayer antes de cargar un nuevo audio
    await resetAudioPlayer();

    String jsonString = await rootBundle.loadString('assets/transcriptionWhisper_normalized.json');
    List<dynamic> jsonList = json.decode(jsonString);
    List<Map<String, dynamic>> listMap = jsonList.map((item) => item as Map<String, dynamic>).toList();

    String text = await rootBundle.loadString('assets/texto_ITSAS_IZARRAK.txt');

    final formattedRawRealText = text;

    // Formatear el texto real usando la nueva función
    //final formattedRawRealText = formatTextIntoParagraphs(text);
    //print("formattedRawRealText --> $formattedRawRealText");

    transcription = Transcription.fromListMap(listMap: listMap, shouldInsertPunctuation: true, referenceText: formattedRawRealText);

    // Asignar el texto real a la transcripción
    transcription?.referenceText = formattedRawRealText;

    //await initAudioPlayer();
    //await audioPlayer.setSource(AssetSource('/audio/audio_prueba_normalized.wav'));

    // Actualizar el estado
    emit(state.copyWith(status: TranscriptionStatus.success, transcription: transcription, textoRealformadoparrafos: formattedRawRealText));

    _createSegmentIndexMap();
  }

  Future<void> useMockTranscriptionES() async {
    emit(state.copyWith(status: TranscriptionStatus.loading));

    // Reiniciar el AudioPlayer antes de cargar un nuevo audio
    await resetAudioPlayer();

    String text = await rootBundle.loadString('assets/texto_LA_TORTUGA_KALI.txt');
    //print("text cargado del asset: $text");

    final formattedRawRealText = text;
    // Formatear el texto real usando la nueva función
    //final formattedRawRealText = formatTextIntoParagraphs(text);
    //print("formattedRawRealText --> $formattedRawRealText");

    transcription = Transcription.fromListMap(listMap: textoTransMock, shouldInsertPunctuation: true, referenceText: formattedRawRealText);

    // Asignar el texto real a la transcripción
    transcription?.referenceText = formattedRawRealText;

    //await initAudioPlayer();
    //await audioPlayer.setSource(AssetSource('/audio/audio_prueba_es.wav'));
    emit(state.copyWith(status: TranscriptionStatus.loaded, transcription: transcription, textoRealformadoparrafos: formattedRawRealText));
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

  void toggleEditMode() {
    emit(state.copyWith(editMode: !state.editMode));
  }

  void togglePlayAndStopWordOnSelect() {
    emit(state.copyWith(extradata: state.extradata?.copyWith(playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect)));
  }

  void resetState() {
    emit(const TranscriptionState(status: TranscriptionStatus.loading));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  /////////////////// Tags

  /*void addTagToSegment(int index, String tag) {
    print("Add Tag: $tag a ${state.transcription!.wordAlignmentSegmentsWithPunctuation![index].word}");
    if (state.transcription == null || index < 0 || index >= state.transcription!.wordAlignmentSegmentsWithPunctuation!.length) {
      return;
    }
    final segment = state.transcription!.wordAlignmentSegmentsWithPunctuation![index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    // Print the segment after adding the tag
    print("Segment after adding tag: $segment");

    final newSegments = List<Segment>.from(state.transcription!.wordAlignmentSegmentsWithPunctuation!)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(wordAlignmentSegmentsWithPunctuation: newSegments);
    emit(state.copyWith(transcription: newTranscription));
    print("wordAlignmentSegmentsWithPunctuation after adding tag: ${transcription!.wordAlignmentSegmentsWithPunctuation}");
  }*/

  void addTagToSegment(int segmentIndex, String tag) {
    // Check if the segmentIndex is valid
    if (segmentIndex >= 0 && segmentIndex < transcription!.wordAlignmentSegmentsWithPunctuation!.length) {
      print("Add Tag: $tag a ${state.transcription!.wordAlignmentSegmentsWithPunctuation![segmentIndex].word} con indice: $segmentIndex");
      // Get the segment
      Segment segment = transcription!.wordAlignmentSegmentsWithPunctuation![segmentIndex];

      // Add the tag to the segment
      segment.tags.add(tag);

      // Rebuild the widget
      final newSegments = List<Segment>.from(state.transcription!.wordAlignmentSegmentsWithPunctuation!)..[segmentIndex] = segment;
      final newTranscription = state.transcription!.copyWith(wordAlignmentSegmentsWithPunctuation: newSegments);
      emit(state.copyWith(transcription: newTranscription));
    } else {
      print("Error: Invalid segment index: $segmentIndex");
    }
  }

  void removeTagFromSegment(int segmentIndex, String tag) {
    print("Remove Tag: $tag a ${state.transcription!.wordAlignmentSegmentsWithPunctuation![segmentIndex].word}");
    if (segmentIndex >= 0 && segmentIndex < transcription!.wordAlignmentSegmentsWithPunctuation!.length) {
      print("Remove Tag: $tag from ${state.transcription!.wordAlignmentSegmentsWithPunctuation![segmentIndex].word} with index: $segmentIndex");
      // Get the segment
      Segment segment = transcription!.wordAlignmentSegmentsWithPunctuation![segmentIndex];

      // Check if the tag exists in the segment
      if (segment.tags.contains(tag)) {
        // Remove the tag from the segment
        segment.tags.remove(tag);

        // Rebuild the widget
        final newSegments = List<Segment>.from(state.transcription!.wordAlignmentSegmentsWithPunctuation!)..[segmentIndex] = segment;
        final newTranscription = state.transcription!.copyWith(wordAlignmentSegmentsWithPunctuation: newSegments);
        emit(state.copyWith(transcription: newTranscription));
      } else {
        print("Error: Tag '$tag' not found in segment with index: $segmentIndex");
      }
    } else {
      print("Error: Invalid segment index: $segmentIndex");
    }
  }

  ////////////// audio sync

  Future<void> stopAudioPlayer() async {
    await audioPlayer.stop();
  }

  Future<void> playAudio() async {
    if (audioPlayer.state == PlayerState.playing) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.resume();
    }
  }

  Future<void> resetAudioPlayer() async {
    print("666666666666666666666666666666666666666666");
    print("fffff: $currentAudioUrl");
    await audioPlayer.dispose();
    audioPlayer = AudioPlayer();
    _initAudioPlayer();
  }

  Future<void> disposeAudioPlayer() async {
    await audioPlayer.dispose();
  }

  @override
  Future<void> close() {
    disposeAudioPlayer();
    return super.close();
  }


  Future<void> _initAudioPlayer() async {
    // Set the audio context
    await audioPlayer.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.speech,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gainTransient,
      ),
    ));

    audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.playing) {
        emit(this.state.copyWith(status: TranscriptionStatus.isPlayerplaying));
      } else if (state == PlayerState.paused) {
        emit(this.state.copyWith(status: TranscriptionStatus.isPlayerpause));
      } else if (state == PlayerState.completed) {
        emit(this.state.copyWith(status: TranscriptionStatus.isPlayercompleted));
      } else if (state == PlayerState.stopped) {
        emit(this.state.copyWith(status: TranscriptionStatus.isPlayerstopped));
      }
    });
    audioPlayer.onPositionChanged.listen((Duration position) {
      emit(this.state.copyWith(extradata: this.state.extradata?.copyWith(audioPosition: position)));
    });
    audioPlayer.onDurationChanged.listen((Duration duration) {
      emit(this.state.copyWith(extradata: this.state.extradata?.copyWith(audioDuration: duration)));
    });
    audioPlayer.onPlayerComplete.listen((event) {
      print("Player completed");
      _audioLoaded = false;
    });
  }

  /*Future<void> initAudioPlayer() async {
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
      audio_duration_seconds = d.inSeconds;
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
  }*/

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
    if (state.transcription!.wordAlignmentSegments != null && state.transcription!.wordAlignmentSegmentsWithPunctuation!.isNotEmpty) {
      // Si de la posicion del audo encontro la palabra en audioTranscriptionSegments
      if (state.extradata!.currentWordIndex != null || currentAudioWordIndex != -1) {
        final forcedSegment = state.transcription!.audioTranscriptionSegments[state.extradata!.currentWordIndex!];
        if (currentMillis < (forcedSegment.start * 1000).toInt() || currentMillis > (forcedSegment.end * 1000).toInt()) {
          _isForceCurrentWord = false; // Reset the flag
          // Buscar la asociación correcta para la nueva palabra
          final segmentKey =
              "${state.transcription!.audioTranscriptionSegments[currentAudioWordIndex].start}-${state.transcription!.audioTranscriptionSegments[currentAudioWordIndex].end}";
          for (int i = 0; i < state.transcription!.wordAlignmentSegmentsWithPunctuation!.length; i++) {
            final associatedSegment = state.transcription!.wordAlignmentSegmentsWithPunctuation![i];
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
    if (state.transcription!.wordAlignmentSegmentsWithPunctuation != null) {
      for (int i = 0; i < state.transcription!.wordAlignmentSegmentsWithPunctuation!.length; i++) {
        final associatedSegment = state.transcription!.wordAlignmentSegmentsWithPunctuation![i];
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


}
