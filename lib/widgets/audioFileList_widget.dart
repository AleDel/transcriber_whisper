import 'package:flutter/material.dart';
import '../models/audioFileInfo.dart';

class AudioFileList extends StatelessWidget {
  final List<AudioFileInfo> files;
  final Function(int) onRemoveFile;
  final VoidCallback onClearFileList;

  const AudioFileList({Key? key, required this.files, required this.onRemoveFile, required this.onClearFileList}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (files.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onClearFileList,
                child: const Text('Limpiar Lista'),
              ),
            ],
          ),
        Expanded(
          child: SingleChildScrollView(
            // Usamos SingleChildScrollView para permitir el scroll
            child: Column(
              // Usamos Column en lugar de ListView
              children: [
                for (int index = 0; index < files.length; index++)

                  ListTile(

                      title: Text(files[index].file.name),
                      subtitle: files[index].duration != null
                          ? Text('Duration: ${files[index].duration.toString().split('.').first}, Size: ${files[index].file.size} bytes')
                          : Text('Size: ${files[index].file.size} bytes'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          //AudioPlayerItem(fileInfo: files[index]),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => onRemoveFile(index),
                          ),
                        ],
                      ),),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
