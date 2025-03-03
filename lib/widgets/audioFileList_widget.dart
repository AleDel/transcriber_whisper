import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/audioFileInfo.dart';
import 'audioPlayerItem_widget.dart';


class AudioFileList extends StatefulWidget {
  final List<AudioFileInfo> files;
  final Function(int) onRemoveFile;
  final Function() onClearFileList;

  const AudioFileList({
    Key? key,
    required this.files,
    required this.onRemoveFile,
    required this.onClearFileList,
  }) : super(key: key);

  @override
  AudioFileListState createState() => AudioFileListState();
}

class AudioFileListState extends State<AudioFileList> {
  double _getTotalSizeInMB() {
    double totalSizeInBytes = 0;
    for (var fileInfo in widget.files) {
      totalSizeInBytes += fileInfo.file.size;
    }
    return totalSizeInBytes / (1024 * 1024); // Convert bytes to MB
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${widget.files.length} archivos (${_getTotalSizeInMB().toStringAsFixed(2)} MB)',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: widget.onClearFileList,
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.files.length,
            itemBuilder: (context, index) {
              // Access the file and duration from AudioFileInfo
              final fileInfo = widget.files[index];
              final file = fileInfo.file;
              final duration = fileInfo.duration;
              return ListTile(
                title: Text(file.name),
                subtitle: duration != null
                    ? Text('Duration: ${duration.toString().split('.').first}, Size: ${file.size} bytes')
                    : Text('Size: ${file.size} bytes'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AudioPlayerItem(file: file),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => widget.onRemoveFile(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}