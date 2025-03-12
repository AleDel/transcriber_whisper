import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/widgets/alignsWidgets/tex_display_fonemas_widget.dart';
import 'package:transcriber_whisper/widgets/audioPlayer_widget.dart';
import 'package:transcriber_whisper/widgets/selectable_RichText_widget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';
import 'package:transcriber_whisper/widgets/alignsWidgets/tex_display_widget.dart';
import 'package:transcriber_whisper/widgets/transcriptionDiff_widget.dart';
import 'package:transcriber_whisper/widgets/vertical_text_widget.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({Key? key}) : super(key: key);

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> with WidgetsBindingObserver {
  GetIt getIt = GetIt.instance;
  late SessionCubit sessionCubit;

  @override
  void initState() {
    super.initState();
    sessionCubit = getIt<SessionCubit>();
    init();
  }

  Future<void> init() async {
    final newProject = await getIt<ProjectCubit>().addProject("Default Project");
    await sessionCubit.createSession(newProject!.id, "Nueva Sesion");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Session: ${sessionCubit.sessionData?.id ?? "Cargando..."}'),
              AudioPlayerWidget(),
            ],
          ),
        ),
        body: BlocBuilder<SessionCubit, SessionState>(
          builder: (context, state) {
            if (state.sessionData == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 100, child: TextDisplayWidget()),
                SizedBox(height: 40, child: TextDisplayFonemasWidget()),
                SizedBox(
                    height: 60,
                    child: SlidingText(
                      onSeek: (Duration d, int indexword) async {
                        try {
                          await sessionCubit.audioPlayer.seek(d).timeout(const Duration(seconds: 10));
                          sessionCubit.forceCurrentWord(indexword);
                        } on TimeoutException catch (e) {
                          print('Timeout seeking audio: $e');
                        } catch (e) {
                          print('Error seeking audio: $e');
                        }
                      },
                    )),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 200,
                        child: VerticalTranscription(
                          onSeek: (Duration d, int indexword) async {
                            print("seeeeek");
                            try {
                              await sessionCubit.audioPlayer.seek(d).timeout(const Duration(seconds: 10));
                              sessionCubit.forceCurrentWord(indexword);
                            } on TimeoutException catch (e) {
                              print('Timeout seeking audio: $e');
                            } catch (e) {
                              print('Error seeking audio: $e');
                            }
                          },
                        ),
                      ),
                      Expanded(child: SelectableRichText()),
                      Expanded(child: TranscriptionDiff(session: state.sessionData!,))
                    ],
                  ),
                ),
              ],
            );
          },
        ));
  }
}
