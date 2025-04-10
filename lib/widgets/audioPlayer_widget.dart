import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';

import '../transcription_state.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) {
        final cubit = context.read<TranscriptionCubit>();
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
                    if (state.status == TranscriptionStatus.isPlayerplaying) {
                      cubit.audioPlayer.pause();
                    } else {

                      cubit.audioPlayer.resume();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.reply_all_rounded),
                  onPressed: () {
                    cubit.audioPlayer.seek(const Duration(seconds: 0));
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
