import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/session_data.dart';

class AudioPlayerWidget extends StatelessWidget {
  const AudioPlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      // Agrega esta línea para escuchar los cambios en playerStatus
      buildWhen: (previous, current) =>
      previous.sessionData?.playerStatus != current.sessionData?.playerStatus ||
          previous.sessionData?.audioPosition != current.sessionData?.audioPosition ||
          previous.sessionData?.audioDuration != current.sessionData?.audioDuration,
      builder: (context, state) {
        final cubit = context.read<SessionCubit>();
        final sessionData = state.sessionData;
        if (sessionData == null) {
          return const Center(child: Text("No hay datos de sesión"));
        }
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    sessionData.playerStatus == PlayerStatus.playing
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  onPressed: () {
                    if (sessionData.playerStatus == PlayerStatus.playing) {
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
                  '${sessionData.audioPosition.toString().split('.').first} / ${sessionData.audioDuration.toString().split('.').first}',
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