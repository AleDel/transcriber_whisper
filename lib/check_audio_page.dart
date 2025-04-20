import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';

class CheckAudioPage extends StatefulWidget {
  final String? filename;

  const CheckAudioPage({Key? key, this.filename}) : super(key: key);

  @override
  _CheckAudioPageState createState() => _CheckAudioPageState();
}

class _CheckAudioPageState extends State<CheckAudioPage> {
  @override
  void initState() {
    super.initState();
    print("estamos en la pagina checkaudio");
    if (widget.filename != null) {
      context.read<TranscriptionCubit>().checkAudio(widget.filename!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Check Audio Status'),
      ),
      body: BlocConsumer<TranscriptionCubit, TranscriptionState>(
        listener: (context, state) {
          // No necesitamos hacer nada en el listener ahora, ya que todo se maneja en el builder
        },
        builder: (context, state) {
          if (state.status == TranscriptionStatus.checkingAudio) {
            return const Center(
              child: LoadingWidget(),
            );
          } else if (state.status == TranscriptionStatus.audioChecked) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Status: ${state.checkAudioResult!.status}'),
                  Text('Message: ${state.checkAudioResult!.message}'),
                  Text('isTranscribed: ${state.checkAudioResult!.isTranscribed}'),
                  if (state.checkAudioResult!.nombreAudio != null)
                    Text('Filename: ${state.checkAudioResult!.nombreAudio}'), // Mostrar nombreAudio
                  if (state.checkAudioResult!.action != null)
                    Text('Action: ${state.checkAudioResult!.action}'),
                ],
              ),
            );
          } else if (state.status == TranscriptionStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('isTranscribed: ${state.checkAudioResult!.isTranscribed}'),
                  //Text('Status: ${state.checkAudioResult!.status}'), // Mostrar el status
                  Text('Details: ${state.checkAudioResult!.message}'),
                ],
              ),
            );
          } else {
            return const Center(
              child: Text('Unknown State'),
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