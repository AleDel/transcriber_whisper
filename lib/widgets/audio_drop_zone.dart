import 'package:audioplayers/audioplayers.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/audioFileInfo.dart';
import 'audioFileList_widget.dart';

class AudioDropZone extends StatefulWidget {
  final Function(List<AudioFileInfo>) onFilesChanged;

  const AudioDropZone({Key? key, required this.onFilesChanged}) : super(key: key);

  @override
  AudioDropZoneState createState() => AudioDropZoneState();
}

class AudioDropZoneState extends State<AudioDropZone> {
  final List<AudioFileInfo> _files = [];
  bool _dragging = false;

  Future<void> _getDuration(PlatformFile file) async {
    final audioPlayer = AudioPlayer();
    if (file.path != null) {
      await audioPlayer.setSource(DeviceFileSource(file.path!));
      audioPlayer.onDurationChanged.listen((Duration d) {
        final index = _files.indexWhere((element) => element.file.name == file.name);
        if (index != -1) {
          _files[index] = _files[index].copyWith(duration: d);
          setState(() {});
        }
      });
    }
  }

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,allowedExtensions: ["aac","mp3","wav","ogg"]
    );

    if (result != null) {
      List<AudioFileInfo> newFiles = [];
      for (var file in result.files) {
        if (!_files.any((element) => element.file.name == file.name)) {
          newFiles.add(AudioFileInfo(file: file));
        }
      }
      setState(() {
        _files.addAll(newFiles);
      });
      for (var fileInfo in newFiles) {
        _getDuration(fileInfo.file);
      }
      widget.onFilesChanged(_files);
    }
  }

  void _removeFile(int index) {
    setState(() {
      _files.removeAt(index);
    });
    widget.onFilesChanged(_files);
  }

  void _clearFileList() {
    setState(() {
      _files.clear();
    });
    widget.onFilesChanged(_files);
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) async {
        List<AudioFileInfo> newFiles = [];
        for (var dropItem in detail.files) {
          final file = PlatformFile(
            name: dropItem.name,
            path: dropItem.path,
            size: await dropItem.length(),
            bytes: null,
          );
          if (!_files.any((element) => element.file.name == file.name)) {
            newFiles.add(AudioFileInfo(file: file));
          }
        }
        setState(() {
          _files.addAll(newFiles);
        });
        for (var fileInfo in newFiles) {
          _getDuration(fileInfo.file);
        }
        widget.onFilesChanged(_files);
      },
      onDragEntered: (detail) {
        setState(() {
          _dragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _dragging = false;
        });
      },
      child: GestureDetector(
        onTap: _pickAudioFile,
        child: Container(
          decoration: BoxDecoration(
            color: _dragging ? Colors.blue.withOpacity(0.4) : Colors.grey.withOpacity(0.2),
            border: Border.all(color: Colors.grey),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('Arrastra y suelta los archivos de audio aquí o haz clic para seleccionar', textAlign: TextAlign.center,),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      height: constraints.maxHeight,
                      child: AudioFileList(
                        files: _files,
                        onRemoveFile: _removeFile,
                        onClearFileList: _clearFileList,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}