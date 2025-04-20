import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';

class TranscribePage extends StatefulWidget {
  final String? filePath;
  const TranscribePage({Key? key, this.filePath}) : super(key: key);

  @override
  _TranscribePageState createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  @override
  void initState() {
    super.initState();
    if (widget.filePath != null) {
      _transcribeFile(widget.filePath!);
    }
  }

  void _transcribeFile(String filePath) async {
    // Create a PlatformFile from the file path
    File file = File(filePath);
    if (await file.exists()) {
      PlatformFile platformFile = PlatformFile(
        name: file.path.split('/').last,
        path: file.path,
        size: file.lengthSync(),
      );
      context.read<TranscriptionCubit>().transcribeAudio(platformFile);
    } else {
      _showError('File does not exist: $filePath');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcribe Audio'),
      ),
      body: BlocConsumer<TranscriptionCubit, TranscriptionState>(
        listener: (context, state) {
          if (state.status == TranscriptionStatus.error) {
            _showError(state.errorMessage!);
          } else if (state.status == TranscriptionStatus.serverBusy) {
            _showError('Server is busy: ${state.serverStatusResult!.file}');
          }
        },
        builder: (context, state) {
          if (state.status == TranscriptionStatus.loading) {
            return const Center(
              child: LoadingWidget(),
            );
          } else if (state.status == TranscriptionStatus.loaded) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Transcription Complete!'),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to the page where you display the transcription
                    },
                    child: const Text('View Transcription'),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: widget.filePath == null
                  ? ElevatedButton(
                onPressed: () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.audio,
                  );
                  if (result != null) {
                    PlatformFile file = result.files.first;
                    context.read<TranscriptionCubit>().transcribeAudio(file);
                  }
                },
                child: const Text('Select Audio File'),
              )
                  : const Text('Waiting for transcription...'), // Show a message when filepath is provided
            );
          }
        },
      ),
    );
  }

  void _showError(String message) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}