import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/widgets/audio_drop_zone.dart';
import 'package:transcriber_whisper/widgets/session_detail_page.dart';
import 'package:file_picker/file_picker.dart';

import 'models/audioFileInfo.dart';

class MainPage extends StatefulWidget {
  final String projectId;
  const MainPage({Key? key, required this.projectId}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final List<bool> _isExpandedList = [];
  late SessionCubit _sessionCubit;
  late ProjectCubit _projectCubit;

  @override
  void initState() {
    super.initState();
    context.read<ProjectCubit>().getProject(widget.projectId);
    _sessionCubit = GetIt.instance<SessionCubit>();
    _projectCubit = GetIt.instance<ProjectCubit>();
  }

  void _onFilesChanged(List<AudioFileInfo> files) {
    print('_onFilesChanged: ${files.length}');
    if (files.isNotEmpty) {
      _projectCubit.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
      //cubitProject.addSessionsToProject(files.map((e) => e.file).toList(), projectId: widget.projectId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubitProject = context.read<ProjectCubit>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcriber Whisper'),
      ),
      body: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, state) {
          if (state.project != null) {
            if (_isExpandedList.length != state.project!.sessionsData.length) {
              // Si la cantidad de sesiones ha cambiado, actualizamos _isExpandedList
              _isExpandedList.clear(); // Limpiamos la lista
              for (var i = 0; i < state.project!.sessionsData.length; i++) {
                _isExpandedList.add(false); // Agregamos elementos con valor false
              }
            }
          }
          return Column(
            children: [
              // Lista de Sesiones
              if (state.project != null && state.project!.sessionsData.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: state.project!.sessionsData.length,
                    itemBuilder: (context, index) {
                      final session = state.project!.sessionsData[index];
                      return GestureDetector(
                        // Añadimos GestureDetector
                        onTap: () async {
                          print("Le di a: ${session.id}");
                          //await _sessionCubit.loadSession(session.id);
                          // _sessionCubit.setSession(session);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Center(child: Text("cambiar esto"),)//SessionDetailPage(session: session),
                            ),
                          );
                        },
                        child: ExpansionPanelList(
                          expansionCallback: (int panelIndex, bool isExpanded) {
                            setState(() {
                              _isExpandedList[index] = !_isExpandedList[index];
                            });
                          },
                          children: [
                            ExpansionPanel(
                              headerBuilder: (BuildContext context, bool isExpanded) {
                                return ListTile(
                                  //title: Text('Sesión ${index + 1}'),
                                  title: Text('Sesión ${session.id}'),
                                  subtitle: Text('Nombre: ${session.audioFilename}'),
                                );
                              },
                              body: const Center(child: Text('No hay nada')),
                              isExpanded: _isExpandedList[index],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (state.project != null && state.project!.sessionsData.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No hay sesiones guardadas para este proyecto.'),
                ),
              // Botón para Añadir Sesiones
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Mostrar el DropZone para añadir archivos
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return BlocBuilder<ProjectCubit, ProjectState>(
                              builder: (context, state) {
                                return SizedBox(
                                  height: 300, // Ajusta la altura según tus necesidades
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: AudioDropZone(
                                          onFilesChanged: (files) => _onFilesChanged(files),
                                          onFilesReady: () {
                                            print("ssss");
                                          },
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: state.files.isEmpty
                                            ? null
                                            : () async {
                                                if (state.project != null) {
                                                  //await cubitProject.addFilesToProject(state.project!.id, state.files);
                                                  cubitProject.clearFiles();
                                                  Navigator.pop(context); // Cerrar el BottomSheet
                                                }
                                              },
                                        child: const Text('Aceptar'),
                                      )
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      child: const Text('Añadir Sesión'),
                    ),
                    const SizedBox(width: 16), // Espacio entre los botones
                    ElevatedButton(
                      onPressed: state.project == null
                          ? null
                          : () async {
                              // Aquí podrías mostrar un diálogo para que el usuario elija el proyecto
                              // o podrías usar el primer proyecto de la lista
                              if (state.project != null) {
                                final projectId = state.project!.id;
                                await cubitProject.deleteAllSessions(projectId);
                              }
                            },
                      child: const Text('Borrar Sesiones'),
                    ),
                  ],
                ),
              ),

              // Información Adicional
              if (state.status == ProjectStatus.error) Center(child: Text('Error de conexión al servidor ${state.errorMessage} ${state.errorDetails}'))
            ],
          );
        },
      ),
    );
  }
}
