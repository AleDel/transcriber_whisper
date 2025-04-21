import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';

import '../transcription_state.dart';

class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  GetIt getIt = GetIt.instance;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        //final cubit = context.read<TranscriptionCubit>();
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    state.status == TranscriptionStatus.isPlayerplaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    print("playerId: ${getIt<TranscriptionCubit>().audioPlayer} ${getIt<TranscriptionCubit>().audioPlayer.audioSource}");
                    if (state.status == TranscriptionStatus.isPlayerplaying) {
                      getIt<TranscriptionCubit>().audioPlayer.pause();
                    } else {
                      getIt<TranscriptionCubit>().audioPlayer.play();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.reply_all_rounded),
                  onPressed: () {
                    getIt<TranscriptionCubit>().audioPlayer.seek(const Duration(seconds: 0));
                  },
                ),
                Text(
                  '${state.extradata?.audioPosition.toString().split('.').first ?? "0:00"} / ${state.extradata?.audioDuration.toString().split('.').first ?? "0:00"}',
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
