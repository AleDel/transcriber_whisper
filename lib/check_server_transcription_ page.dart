import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/loadingWidget.dart';

class CheckServerTranscriptionPage extends StatefulWidget {
  const CheckServerTranscriptionPage({Key? key}) : super(key: key);

  @override
  _CheckServerTranscriptionPageState createState() => _CheckServerTranscriptionPageState();
}

class _CheckServerTranscriptionPageState extends State<CheckServerTranscriptionPage> {
  @override
  void initState() {
    super.initState();
    print("estamos en la pagina CheckServerTranscriptionPage");
    context.read<TranscriptionCubit>().checkServerStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Status'),
      ),
      body: BlocConsumer<TranscriptionCubit, TranscriptionState>(
        listener: (context, state) {
          if (state.status == TranscriptionStatus.error) {
            _showError(state.checkAudioResult!.message);
          }
        },
        builder: (context, state) {
          if (state.status == TranscriptionStatus.checkingServerStatus) {
            return const Center(
              child: LoadingWidget(),
            );
          } else if (state.status == TranscriptionStatus.serverStatusChecked) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Status: ${state.serverStatusResult!.status}'),
                  if (state.serverStatusResult!.file != null)
                    Text('File: ${state.serverStatusResult!.file}'),
                ],
              ),
            );
          } else if (state.status == TranscriptionStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.serverStatusResult!.status}'),
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