import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/audioFileInfo.dart';

class AudioDropZone extends StatefulWidget {
  final Function(List<AudioFileInfo>) onFilesChanged;
  final VoidCallback onFilesReady;

  const AudioDropZone({Key? key, required this.onFilesChanged, required this.onFilesReady}) : super(key: key);

  @override
  AudioDropZoneState createState() => AudioDropZoneState();
}

class AudioDropZoneState extends State<AudioDropZone> {
  final List<AudioFileInfo> _files = [];
  bool _dragging = false;

  Future<void> _pickAudioFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: ["aac", "mp3", "wav", "ogg", "m4a"]);

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

  String _buildTooltipContent() {
    if (_files.isEmpty) {
      return "No hay archivos seleccionados.";
    }
    String content = "Archivos seleccionados:\n";
    for (var fileInfo in _files) {
      content += "- ${fileInfo.file.name}\n";
    }
    return content;
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
              bytes: null);
          if (!_files.any((element) => element.file.name == file.name)) {
            newFiles.add(AudioFileInfo(file: file));
          }
        }
        setState(() {
          _files.addAll(newFiles);
        });
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
      child: Tooltip(
        message: _buildTooltipContent(),
        child: GestureDetector(
          onTap: _pickAudioFile,
          child: Container(
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
                color: _dragging
                    ? Colors.blue.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.2),
                border: Border.all(color: Colors.grey)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_upload, size: 24, color: Colors.grey),
                if (_files.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    "(${_files.length})",
                    style: const TextStyle(fontSize: 14),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.grey),
                    onPressed: _clearFileList,
                    tooltip: 'Limpiar',
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: Colors.grey),
                    onPressed: widget.onFilesReady,
                    tooltip: 'Aceptar',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}