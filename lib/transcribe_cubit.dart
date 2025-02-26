import 'dart:async';
import 'dart:convert';
//import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/mockData/textotest.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';

class TranscribeCubit extends Cubit<TranscribeState> {
  final String TAG = "TranscribeCubit: ";

  Transcription? transcription;

  final AudioPlayer audioPlayer = AudioPlayer();

  //late AudioCache audioPlayer;

  String audioFilePath = "";
  List<double> samples = [];
  late int totalSamples;

  final ScrollController scrollController = ScrollController();
  //double lastpos = -1;
  final double _scrollMargin = 0.1;
  //final GlobalKey slidingTextKey = GlobalKey();
  bool _userSelectedWord = false;
  bool _autoScrollEnabled = true;
  String? melSpectrogramBase64;
  List<List<double>>? melSpectrogramData;
  late Duration maxDuration;
  late Duration elapsedDuration;

  String? waveformImageBase64;

  bool isRecording = false;

  late IO.Socket socket;
  List<String> logs = [];

  // New variables for debouncing
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 200);
  // New variable to control if a word is playing
  bool _isPlayingWord = false;
  Timer? _wordPlayTimer;

  TranscribeCubit() : super(TranscribeState(status: TranscribeStatus.initial)) {
    totalSamples = 10000;
    maxDuration = const Duration(milliseconds: 1000);

    audioPlayer.onDurationChanged.listen((Duration d) {
      maxDuration = d;
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioDuration: d)));
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      elapsedDuration = p;
      emit(state.copyWith(extradata: state.extradata?.copyWith(audioPosition: p)));
      updateCurrentWord(); // Mantenemos esta linea
    });

    audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      switch (s) {
        case PlayerState.playing:
          emit(state.copyWith(status: TranscribeStatus.isPlayerplaying));
          break;
        case PlayerState.paused:
          emit(state.copyWith(status: TranscribeStatus.isPlayerpause));
          break;
        case PlayerState.completed:
          emit(state.copyWith(status: TranscribeStatus.isPlayercompleted));
          break;
        case PlayerState.stopped:
          emit(state.copyWith(status: TranscribeStatus.isPlayerstopped));
          break;
        case PlayerState.disposed:
          emit(state.copyWith(status: TranscribeStatus.isPlayerdisposed));
          break;
      }
    });

    audioPlayer.onPlayerComplete.listen((event) {
      elapsedDuration = maxDuration;
    });
    connectToServer();
  }

  void connectToServer() {
    try {
      // Configure socket transports must be sepecified
      socket = IO.io('http://127.0.0.1:5000', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });
      socket.connect();
      socket.onConnect((_) {
        print('connect');
        socket.emit('msg', 'test');
      });
      socket.on('log', (data) {
        print("log: $data");
        // Crear una nueva lista en lugar de modificar la existente
        List<String> newLogs = List<String>.from(state.logs_mfa ?? []);
        newLogs.add(data['data']);
        emit(state.copyWith(logs_mfa: newLogs));
      });
      socket.on('my response', (data) {
        print(data);
      });
      socket.onDisconnect((_) => print('disconnect'));
      socket.on('fromServer', (_) => print("from server..."));
    } catch (e) {
      print(e.toString());
    }
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
    audioFilePath = audioFile.path ?? "";
    emit(state.copyWith(extradata: state.extradata?.copyWith(audioFilePath: audioFile.path)));

    try {
      //final url = Uri.parse('http://127.0.0.1:5001/transcribe');
      final url = Uri.parse('https://infanciadigital.duckdns.org/transcriber/transcribe');
      final headers = {'Content-Type': 'application/octet-stream'};

      Uint8List? fileBytes;
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
        melSpectrogramBase64 = jsonResponse['mel_spectrogram'];
        waveformImageBase64 = jsonResponse['waveform_image'];

        emit(
          state.copyWith(
            status: TranscribeStatus.loaded,
            transcription: transcription,
            melSpectrogramBase64: melSpectrogramBase64,
            //samples: samples,
            waveformImageBase64: waveformImageBase64,
          ),
        );
        //await audioPlayer.play(audioFilePath, isLocal: true);

        await audioPlayer.setSource(DeviceFileSource(audioFilePath));
        //await loadSamples(audioFilePath);
      } else {
        print('Error: ${response.statusCode}');
        emit(state.copyWith(status: TranscribeStatus.error));
      }
    } catch (e) {
      print('Error: $e');
      emit(state.copyWith(status: TranscribeStatus.error));
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
      // User canceled the picker
    }
  }

  List<double> loadparseJson(String jsonBody) {
    final data = jsonDecode(jsonBody);
    final List<double> points = List.castFrom(data['data']);
    List<double> filteredData = [];
    // Change this value to number of audio samples you want.
    // Values between 256 and 1024 are good for showing [RectangleWaveform] and [SquigglyWaveform]
    // While the values above them are good for showing [PolygonWaveform]
    int samples = totalSamples;
    final double blockSize = points.length / samples;

    for (int i = 0; i < samples; i++) {
      final double blockStart = blockSize * i; // the location of the first sample in the block
      double sum = 0;
      for (int j = 0; j < blockSize; j++) {
        sum =
            sum +
            points[(blockStart + j).toInt()]
                .toDouble(); // find the sum of all the samples in the block
      }
      filteredData.add(
        (sum / blockSize).toDouble(),
      ); // take the average of the block and add it to the filtered data
    }
    return filteredData;
  }

  int _binarySearch(double target) {
    if (transcription == null) return -1;
    int left = 0;
    int right = transcription!.segments.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = left + ((right - left) ~/ 2);
      var wordData = transcription!.segments[mid];
      double start = wordData.start * 1000;
      double end = wordData.end * 1000;

      if (target >= start && target <= end) {
        result = mid;
        return result;
      } else if (target < start) {
        right = mid - 1;
      } else {
        left = mid + 1;
      }
    }
    return result;
  }

  Future<void> useFakeTranscription() async {
    transcription = Transcription.fromListMap(textofake);
    //await audioPlayer.setSource(DeviceFileSource(audioFilePath));
    await audioPlayer.setSource(AssetSource('9183-2-2660_16000hz.wav'));
    emit(state.copyWith(status: TranscribeStatus.loaded, transcription: transcription)); /**/
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  void updateCurrentWord() {
    if (transcription == null || _userSelectedWord) return;

    int newIndex = _binarySearch(state.extradata!.audioPosition.inMilliseconds.toDouble());

    if (newIndex != state.extradata!.currentWordIndex) {
      print("updateCurrentWord newIndex: $newIndex");
      emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: newIndex)));
    }
  }

  void forceCurrentWord(int index) {
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null &&
        now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      print("forceCurrentWord: Ignorando llamada rápida");
      return; // Ignorar la llamada si es demasiado rápida
    }
    _lastForceCurrentWordCall = now;

    print("forceCurrentWord index: $index");

    _userSelectedWord = true;

    emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));

    final segment = transcription!.segments[index];
    final startMillis = (segment.start * 1000).toInt();
    final endMillis = (segment.end * 1000).toInt();
    print("Word start: ${startMillis}ms");
    print("Word end: ${endMillis}ms");
    print("Audio position: ${state.extradata!.audioPosition.inMilliseconds}ms");

    audioPlayer.seek(Duration(milliseconds: startMillis));

    // Cancelar el timer anterior si existe
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
    emit(
      state.copyWith(
        extradata: state.extradata?.copyWith(
          playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    socket.disconnect();
    audioPlayer.dispose();
    scrollController.dispose();

    return super.close();
  }
}

/////////// State

enum TranscribeStatus {
  initial,
  loaded,
  loading,
  error,
  noserver,
  isPlayerplaying,
  isPlayerpause,
  isPlayerstopped,
  isPlayercompleted,
  isPlayerdisposed,
}

class TranscribeState extends Equatable {
  final TranscribeStatus status;
  final Transcription? transcription;
  final Data? extradata;
  final String? melSpectrogramBase64;
  final List<List<double>>? melSpectrogramData;
  //final List<double> samples;
  final String? waveformImageBase64;
  final List<String>? logs_mfa;

  const TranscribeState({
    required this.status,
    this.transcription,
    this.extradata = const Data(),
    this.melSpectrogramBase64,
    this.melSpectrogramData,
    //this.samples = const [],
    this.waveformImageBase64,
    this.logs_mfa,
  });

  TranscribeState copyWith({
    TranscribeStatus? status,
    Transcription? transcription,
    Data? extradata,
    String? melSpectrogramBase64,
    List<List<double>>? melSpectrogramData,
    //List<double>? samples,
    String? waveformImageBase64,
    List<String>? logs_mfa,
  }) {
    return TranscribeState(
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      extradata: extradata ?? this.extradata,
      melSpectrogramBase64: melSpectrogramBase64 ?? this.melSpectrogramBase64,
      melSpectrogramData: melSpectrogramData ?? this.melSpectrogramData,
      //samples: samples ?? this.samples,
      waveformImageBase64: waveformImageBase64 ?? this.waveformImageBase64,
      logs_mfa: logs_mfa ?? this.logs_mfa,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transcription,
    extradata,
    melSpectrogramBase64,
    waveformImageBase64,
    logs_mfa,
  ];
}
