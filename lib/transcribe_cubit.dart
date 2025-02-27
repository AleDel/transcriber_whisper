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
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:transcriber_whisper/models/data_model.dart';
import 'package:transcriber_whisper/models/transcription_model.dart';
import 'package:transcriber_whisper/segment_context_menu.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

import 'mockData/textotest.dart';


class TranscribeCubit extends Cubit<TranscribeState> {
  TranscribeCubit() : super(const TranscribeState(status: TranscribeStatus.initial)) {
    //initSocket();
    initAudioPlayer();
  }

  final ScrollController scrollController = ScrollController();
  final AudioPlayer audioPlayer = AudioPlayer();
  late IO.Socket socket;
  Transcription? transcription;
  bool _autoScrollEnabled = true;
  bool _userSelectedWord = false;
  bool _isPlayingWord = false;
  Timer? _wordPlayTimer;
  DateTime? _lastForceCurrentWordCall;
  final Duration _forceCurrentWordDebounceTime = const Duration(milliseconds: 100);
  final int totalSamples = 512;

  static Map<String, Color> availableTags = {
    "Omisión": Colors.red,
    "Relectura": Colors.green,
    "Repetición": Colors.blue,
    "Corrección": Colors.purple,
    'Tag5': Colors.orange,
    'Tag6': Colors.pink,

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
      //final url = Uri.parse('http://127.0.0.1:5001/transcribe');
      final url = Uri.parse('https://infanciadigital.duckdns.org/transcriber/transcribe');
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

        emit(
          state.copyWith(
            status: TranscribeStatus.loaded,
            transcription: transcription,
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
      }print('Error: $e');
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

  Future<void> useMockTranscription() async {
    transcription = Transcription.fromListMap(textoMock);
    //await audioPlayer.setSource(DeviceFileSource(audioFilePath));
    await audioPlayer.setSource(AssetSource('9183-2-2660_16000hz.wav'));
    emit(state.copyWith(status: TranscribeStatus.loaded, transcription: transcription)); /**/
  }

  void toggleEditMode() {
    emit(state.copyWith(editMode: !state.editMode));
  }

  void addTagToSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final segment = state.transcription!.segments[index];
    final newTags = List<String>.from(segment.tags)..add(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void removeTagFromSegment(int index, String tag) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final segment = state.transcription!.segments[index];
    final newTags = List<String>.from(segment.tags)..remove(tag);
    final newSegment = segment.copyWith(tags: newTags);
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegment(Segment newSegment) {
    if (state.transcription == null) return;
    final index = state.transcription!.segments.indexOf(newSegment);
    if (index == -1) return;
    final newSegments = List<Segment>.from(state.transcription!.segments)..[index] = newSegment;
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void editSegments(List<int> indexes, String newText) {
    if (state.transcription == null || indexes.isEmpty) return;
    final newSegments = List<Segment>.from(state.transcription!.segments);
    for (int index in indexes) {
      if (index >= 0 && index < newSegments.length) {
        final segment = newSegments[index];
        final newSegment = segment.copyWith(word: newText);
        newSegments[index] = newSegment;
      }
    }
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void deleteSegment(int index) {
    if (state.transcription == null || index < 0 || index >= state.transcription!.segments.length) {
      return;
    }
    final newSegments = List<Segment>.from(state.transcription!.segments)..removeAt(index);
    final newTranscription = state.transcription!.copyWith(segments: newSegments);
    emit(state.copyWith(transcription: newTranscription));
  }

  void setAutoScroll(bool value) {
    _autoScrollEnabled = value;
  }

  void updateCurrentWord() {
    if (state.transcription == null || state.transcription!.segments.isEmpty) return;
    if (_userSelectedWord) return;
    final currentPosition = state.extradata!.audioPosition;
    if (currentPosition == null) return;
    final currentMillis = currentPosition.inMilliseconds;
    final index = _binarySearch(state.transcription!.segments, currentMillis);
    if (index != -1) {
      emit(state.copyWith(extradata: state.extradata?.copyWith(currentWordIndex: index)));
    }
  }

  void forceCurrentWord(int index) {
    if (state.transcription == null || state.transcription!.segments.isEmpty) return;
    final now = DateTime.now();
    if (_lastForceCurrentWordCall != null && now.difference(_lastForceCurrentWordCall!) < _forceCurrentWordDebounceTime) {
      return;
    }
    _lastForceCurrentWordCall = now;
    _userSelectedWord = true;
    final segment = state.transcription!.segments[index];
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
    emit(
      state.copyWith(
        extradata: state.extradata?.copyWith(
          playAndStopWordOnSelect: !state.extradata!.playAndStopWordOnSelect,
        ),
      ),
    );
  }

  void showContextMenu(BuildContext context, Offset position, List<int> selectedIndexes) {
    List<String> selectedTags = [];
    if (selectedIndexes.isNotEmpty) {
      selectedTags = state.transcription!.segments[selectedIndexes.first].tags;
    } else {
      final index = _getSegmentIndexFromOffset(position);
      if (index != -1) {
        selectedTags = state.transcription!.segments[index].tags;
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
    final segment = state.transcription!.segments[index];
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
    String newText = state.transcription!.segments[indexes.first].word;
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