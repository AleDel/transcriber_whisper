/*import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:transcriber_whisper/sliderwidget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _transcription = [];
  bool _isLoading = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _audioFilePath = '';
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  bool _isPlaying = false;
  String _fullTextTranscription = '';
  int _currentWordIndex = -1;
  final ScrollController _scrollController = ScrollController();
  double lastpos = -1;
  final double _scrollMargin = 0.1; // Margen del 30% para el desplazamiento
  final GlobalKey _slidingTextKey = GlobalKey(); // GlobalKey para SlidingText

  @override
  void initState() {
    super.initState();
    _audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() => _audioDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        _audioPosition = p;
        print(_audioPosition);
        _updateCurrentWord();
      });
    });
    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      setState(() => _isPlaying = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _transcribeAudio(File audioFile) async {
    setState(() {
      _isLoading = true;
      _transcription = [];
      _fullTextTranscription = '';
      _currentWordIndex = -1;
      _audioFilePath = audioFile.path;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5000/transcribe'));
      request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        var data = jsonDecode(responseBody);
        print(data);
        setState(() {
          _transcription = List<Map<String, dynamic>>.from(data['transcription']);
          _fullTextTranscription = _transcription.map((wordData) => wordData['word']).join(' ');
        });
        await _audioPlayer.setSource(DeviceFileSource(_audioFilePath));
      } else {
        print('Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result != null) {
      File file = File(result.files.single.path!);
      _transcribeAudio(file);
    } else {
      // User canceled the picker
    }
  }

  void _updateCurrentWord() {
    if (_transcription.isEmpty) return;

    for (int i = 0; i < _transcription.length; i++) {
      var wordData = _transcription[i];
      if (_audioPosition.inSeconds >= wordData['start'] &&
          _audioPosition.inSeconds <= wordData['end']) {
        setState(() {
          _currentWordIndex = i;
          print(_currentWordIndex);
        });
        //_scrollToCurrentPosition();
        return;
      }
    }
    if (_currentWordIndex != -1) {
      setState(() {
        _currentWordIndex = -1;
      });
      //_scrollToCurrentPosition();
    }
  }

  void _scrollToCurrentPosition() {
    print("222222222222222222222222");

    if (_transcription.isEmpty || !_scrollController.hasClients) return; // Comprobación añadida

    double totalDuration = _transcription.last['end'].toDouble();
    double currentPosition = _audioPosition.inSeconds.toDouble();
    double scrollPosition =
        (currentPosition / totalDuration) * (_scrollController.position.maxScrollExtent);

    // Calcular la posición de la palabra actual
    double currentWordStart = _transcription[_currentWordIndex]['start'].toDouble();
    double currentWordEnd = _transcription[_currentWordIndex]['end'].toDouble();
    double currentWordPosition =
        (currentWordStart / totalDuration) * (_scrollController.position.maxScrollExtent);
    double currentWordWidth =
        ((currentWordEnd - currentWordStart) / totalDuration) *
        (_scrollController.position.maxScrollExtent);

    // Calcular el final de la vista visible
    double visibleEnd =
        _scrollController.position.pixels + _scrollController.position.viewportDimension;

    // Calcular el margen
    double margin = _scrollController.position.viewportDimension * _scrollMargin;

    print("oooooooooo");
    // Comprobar si la palabra está dentro del margen
    bool shouldScroll = (currentWordPosition + currentWordWidth) > (visibleEnd - margin);
    print("------------------------------------------- ini ");
    print("currentWordStart: $currentWordStart");
    print("currentWordEnd: $currentWordEnd");
    print("scrollPosition: $scrollPosition");

    print("currentWordPosition: $currentWordPosition");
    print("currentWordWidth: $currentWordWidth");
    print("visibleEnd: $visibleEnd");
    print("margin: $margin");
    print("shouldScroll: $shouldScroll");
    print("------------------------------------------- end");

    if ((shouldScroll && scrollPosition != lastpos) || scrollPosition <= 0) {
      if (_scrollController.position.maxScrollExtent == 0) {
        _scrollController.jumpTo(scrollPosition); // Usar jumpTo si maxScrollExtent es 0
      } else {
        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
    lastpos = scrollPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audio Transcriber')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(onPressed: _pickAudioFile, child: Text('Pick Audio File')),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: () {
                              if (_isPlaying) {
                                _audioPlayer.pause();
                              } else {
                                _audioPlayer.resume();
                              }
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.reply_all_rounded),
                            onPressed: () {
                              _audioPlayer.seek(Duration(seconds: 0));
                              //_audioPlayer.play(DeviceFileSource(_audioFilePath));
                            },
                          ),
                          Text(
                            '${_audioPosition.toString().split('.').first} / ${_audioDuration.toString().split('.').first}',
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      _transcription.isNotEmpty
                          ? SingleChildScrollView(
                            controller: _scrollController,
                            scrollDirection: Axis.horizontal,
                            child: SlidingText(
                              transcription: _transcription,
                              audioPosition: _audioPosition,
                              currentWordIndex: _currentWordIndex,
                            ),
                          )
                          : Expanded(child: Container()),
                      SizedBox(height: 20),
                      Expanded(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: 500,
                            //height: 200,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    // <-- Added explicit TextStyle
                                    color: Colors.black, // <-- Set text color to black
                                    fontSize: 16.0, // <-- Set text size
                                  ),
                                  children:
                                      _transcription.asMap().entries.map((entry) {
                                        int index = entry.key;
                                        var wordData = entry.value;
                                        return TextSpan(
                                          text: wordData['word'] + ' ',
                                          style: TextStyle(
                                            backgroundColor:
                                                index == _currentWordIndex ? Colors.yellow : null,
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      //SizedBox(height: 100, child: _audioFilePath.isNotEmpty ? PolygonWaveform(size: Size(MediaQuery.of(context).size.width, 100), playerController: controller, enableSeekGesture: true, waveformType: WaveformType.fitWidth, playerWaveStyle: const PlayerWaveStyle(fixedWaveColor: Colors.white54, liveWaveColor: Colors.white, spacing: 6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF1E1B26)), padding: const EdgeInsets.only(left: 8), margin: const EdgeInsets.only(right: 8), maxDuration: _audioDuration, absolute: false, filePath: _audioFilePath) : const SizedBox()),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}*/
