import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/associated_segments_table.dart'; // Importa el widget

class TranscribePage extends StatefulWidget {
  @override
  State<TranscribePage> createState() => _TranscribePageState();
}

class _TranscribePageState extends State<TranscribePage> {
  @override
  void initState() {
    super.initState();
    // Llamar a useMockTranscriptionEU() cuando se crea la página
    GetIt.instance<TranscriptionCubit>().useMockTranscriptionEU();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcribe Page'),
      ),
      body: BlocBuilder<TranscriptionCubit, TranscriptionState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  // ... (otros widgets)
                  AssociatedSegmentsTable(
                    associatedSegments: state.transcription?.associatedSegments,
                    realTextSegments: state.transcription?.realTextSegments,
                    realTextWords: state.transcription?.realTextWords,transcribedWords: state.transcription?.transcribedWords,
                  ),
                  // ... (otros widgets)
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}