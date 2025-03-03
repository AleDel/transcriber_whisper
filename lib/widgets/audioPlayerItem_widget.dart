import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AudioPlayerItem extends StatefulWidget {
  final PlatformFile file;

  const AudioPlayerItem({Key? key, required this.file}) : super(key: key);

  @override
  AudioPlayerItemState createState() => AudioPlayerItemState();
}

class AudioPlayerItemState extends State<AudioPlayerItem> {
  final audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {

    super.initState();
    audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _currentPosition = Duration.zero;
      });
    });
    audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });
    audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        _currentPosition = p;
      });
    });
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio() async {
    if (_isPlaying) {
      await audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      if (widget.file.path != null) {
        await audioPlayer.setSource(DeviceFileSource(widget.file.path!));
        await audioPlayer.resume();
        setState(() {
          _isPlaying = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _playAudio,
        ),
        SizedBox(
          width: 100,
          child: Slider(
            value: _currentPosition.inSeconds.toDouble(),
            min: 0,
            max: _duration.inSeconds.toDouble(),
            onChanged: (value) {
              setState(() {
                _currentPosition = Duration(seconds: value.toInt());
              });
              audioPlayer.seek(_currentPosition);
            },
          ),
        ),
        Text(
          '${_currentPosition.toString().split('.').first} / ${_duration.toString().split('.').first}',
        ),
      ],
    );
  }
}