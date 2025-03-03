import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

import 'diff_text_widget.dart';

class TranscriptionDiff extends StatelessWidget {
  final String originalText;

  const TranscriptionDiff({Key? key, required this.originalText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscribeCubit, TranscribeState>(
      builder: (context, state) {
        if (state.transcription == null) {
          return const Center(child: Text('No hay transcripción disponible.'));
        }
        final transcribedText = state.transcription!.fulltext;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Texto Original:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(originalText),
              const SizedBox(height: 16),
              const Text('Comparación:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: DiffText(
                    originalText: originalText,
                    transcribedText: transcribedText,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}