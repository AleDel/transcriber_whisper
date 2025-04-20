import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:transcriber_whisper/transcription_cubit.dart';
import 'package:transcriber_whisper/transcription_state.dart';
import 'package:transcriber_whisper/widgets/highlighted_real_text_widget.dart';
import 'package:transcriber_whisper/widgets/sliding_text_widget.dart';


class ViewerPage extends StatefulWidget {
  final String filename;
  final String? text;

  const ViewerPage({Key? key, required this.filename, required this.text}) : super(key: key);

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {

  final ScrollController _scrollController = ScrollController();
  GetIt getIt = GetIt.instance;

  @override
  void initState() {
    super.initState();
    // Llama a la función del cubit para obtener los datos al iniciar la página
    context.read<TranscriptionCubit>().fetchDataAndUseReal(widget.filename, widget.text);
    context.read<TranscriptionCubit>().resetAudioPlayer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    //getIt<TranscriptionCubit>().stopAudioPlayer();
    //getIt<TranscriptionCubit>().disposeAudioPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Viewer Page'),),
      body: Stack(
        children: [
          BlocBuilder<TranscriptionCubit, TranscriptionState>(
            builder: (context, state) {
              print("state.status ---------------------> ${state.status}");
              if (state.status == TranscriptionStatus.error) {
                return const Center(child: Text('Error al obtener los datos'));
              }
              if (state.status == TranscriptionStatus.noserver) {
                return const Center(child: Text('No se pudo conectar con el servidor'));
              }
              if (state.status == TranscriptionStatus.loading) {
                //return Center(child: CircularProgressIndicator());
                //return LoadingWidget();
                return LoadingAnimationWidget.hexagonDots(color: Colors.red, size: 100);
              }
              return Column(
                // Eliminado Center y añadido Column
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // botones transcribir, etc
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        //ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().pickAudioFile(), child: const Text('Cargar Audio')),
                        //ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionEU(), child: const Text('Usar Mock data')),
                        ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionES(), child: const Text('Usar Mock data Es')),
                        ElevatedButton(onPressed: () async => getIt<TranscriptionCubit>().useMockTranscriptionEU(), child: const Text('Usar Mock data Eu')),
                        //ElevatedButton(onPressed: () async => context.go('/details/audio8'), child: const Text('Go details')),
                        ElevatedButton(
                          onPressed: () {
                            //getIt<TranscriptionCubit>().playAudio();
                            String audiourl = getIt<TranscriptionCubit>().currentAudioUrl;
                            print("audiourl: $audiourl");
                            final AudioPlayer audioPlayer = AudioPlayer(playerId: "Audioplayer 1000");
                            audioPlayer.play(UrlSource(getIt<TranscriptionCubit>().currentAudioUrl));
                            //getIt<TranscriptionCubit>().audioPlayer.play(UrlSource(getIt<TranscriptionCubit>().currentAudioUrl));
                          },
                          child: const Text('Play Audio'),
                        ),ElevatedButton(
                          onPressed: () {


                            getIt<TranscriptionCubit>().audioPlayer.play(UrlSource(getIt<TranscriptionCubit>().currentAudioUrl));
                          },
                          child: const Text('Play Audio'),
                        ),
                      ],
                    ),
                  ),
                  // interfaz grafica principal
                  if (state.transcription != null)
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 60,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SlidingText(
                                      transcription: state.transcription!,
                                      audioPosition: state.extradata!.audioPosition,
                                      currentWordIndex: state.extradata!.currentWordIndex,
                                      waveformImageBase64: state.waveformImageBase64,
                                      scrollController: _scrollController,
                                      onWordTap: (index) {
                                        getIt<TranscriptionCubit>().forceCurrentWord(index);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              //Expanded(child: SizedBox(height: 60, child: AudioPlayerWidget())),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: HighlightedRealTextWidget(
                                currentWordIndex: state.extradata?.currentWordIndex ?? -1,
                                onWordTap: (index) {
                                  getIt<TranscriptionCubit>().forceCurrentWord(index);
                                },
                                transcription: state.transcription!,
                                audioPosition: state.extradata!.audioPosition,
                                scrollController: ScrollController(),
                                onShowAssociatedWordsChanged: (bool value) {},
                                onShowOnlyDifferentWordsChanged: (bool value) {},
                                onHighlightDifferencesChanged: (bool value) {},
                                onHighlightDeletedWordsChanged: (bool value) {},
                                onShowOnlyInsertionsChanged: (bool value) {},
                                onShowInsertionsAndDeletionsWithArrowsChanged: (bool value) {},
                                onShowCoincidencePunctuationAndDeletedChanged: (bool value) {},
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          //FloatingWindow(title: "MFA Logs", initialX: 10, initialY: 10, initialWidth: 300, initialHeight: 100, child: MfaLogsWidget()),
        ],
      ),
    );
  }
}