/*import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audioFileInfo.dart';

class AudioPlayerItem extends StatefulWidget {
  final AudioFileInfo fileInfo;

  const AudioPlayerItem({Key? key, required this.fileInfo}) : super(key: key);

  @override
  AudioPlayerItemState createState() => AudioPlayerItemState();
}

class AudioPlayerItemState extends State<AudioPlayerItem> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer.playerStateStream.listen((justAudioPlayerState) {
      if (mounted) {
        setState(() {
          if (justAudioPlayerState.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _currentPosition = Duration.zero;
          }
        });
      }
    });
    _audioPlayer.positionStream.listen((Duration p) {
      if (mounted) {
        setState(() {
          _currentPosition = p;
        });
      }
    });
    _audioPlayer.durationStream.listen((Duration? d) {
      if (mounted && d != null) {
        setState(() {
          _duration = d;
        });
      }
    });
  }

  Future<void> _loadAudio() async {
    if (!_isLoaded) {
      try {
        if (widget.fileInfo.file.path != null) {
          if (widget.fileInfo.file.path!.startsWith('http') || widget.fileInfo.file.path!.startsWith('blob')) {
            await _audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(widget.fileInfo.file.path!)));
          } else {
            await _audioPlayer.setAudioSource(AudioSource.file(widget.fileInfo.file.path!));
          }
          if (widget.fileInfo.duration == null) {
            final duration = await compute(getDuration, widget.fileInfo.file);
            final newFileInfo = widget.fileInfo.copyWith(duration: duration);
          }
          setState(() {
            _isLoaded = true;
          });
        }
      } catch (e) {
        print('Error al cargar el audio: $e');
      }
    }
  }

  static Future<Duration> getDuration(PlatformFile file) async {
    final audioPlayer = AudioPlayer();
    try {
      if (file.path != null) {
        if (file.path!.startsWith('http') || file.path!.startsWith('blob')) {
          await audioPlayer.setAudioSource(AudioSource.uri(Uri.parse(file.path!)));
        } else {
          await audioPlayer.setAudioSource(AudioSource.file(file.path!));
        }
        return audioPlayer.duration ?? Duration.zero;
      }
      return Duration.zero;
    } catch (e) {
      print('Error getting duration for file ${file.name}: $e');
      return Duration.zero;
    } finally {
      audioPlayer.dispose();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playAudio() async {
    await _loadAudio();
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.play();
      setState(() {
        _isPlaying = true;
      });
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
              _audioPlayer.seek(_currentPosition);
            },
          ),
        ),
        Text(
          '${_currentPosition.toString().split('.').first} / ${_duration.toString().split('.').first}',
        ),
      ],
    );
  }
}*/