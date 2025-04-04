import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';

class FormattedTextNormalWidget extends StatelessWidget {
  const FormattedTextNormalWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        // Asegúrate de que el texto formateado esté disponible
        if (state.textoRealformadoparrafos == null || state.textoRealformadoparrafos!.isEmpty) {
          return const Center(child: Text('No hay texto para mostrar'));
        }
        final formattedText = state.textoRealformadoparrafos!;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Text(
                formattedText,
                style: const TextStyle(fontSize: 16.0),
                textAlign: TextAlign.justify,
              ),
            ),
          ),
        );
      },
    );
  }
}