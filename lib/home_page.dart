import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/main_page.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/transcribe_cubit.dart';
import 'package:transcriber_whisper/transcribe_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Proyectos'),
      ),
      body: BlocBuilder<TranscribeCubit, TranscribeState>(
        builder: (context, state) {
          if (state.status == TranscribeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == TranscribeStatus.error) {
            return Center(child: Text('Error: ${state.errorMessage}'));
          } else {
            final projects = state.projects ?? [];
            return ListView.separated(
              itemCount: projects.length,
              separatorBuilder: (context, index) => const Divider(), // Añade un divisor entre los elementos
              itemBuilder: (context, index) {
                final project = projects[index];
                return ListTile(
                  title: Text(project.name),
                  onTap: () {
                    context.read<TranscribeCubit>().loadProject(project.id);
                    context.read<TranscribeCubit>().selectProject(project);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MainPage()),
                    );
                  },
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.upload_file), // Icono de cargar
                        onPressed: () {
                          context.read<TranscribeCubit>().pickAudioFile(project.id);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _showDeleteConfirmationDialog(context, project.id);
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateProjectDialog(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    String projectName = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Crear Nuevo Proyecto'),
          content: TextField(
            onChanged: (value) {
              projectName = value;
            },
            decoration: const InputDecoration(hintText: 'Nombre del Proyecto'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Crear'),
              onPressed: () {
                if (projectName.isNotEmpty) {
                  context.read<TranscribeCubit>().createProject(projectName);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String projectId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Proyecto'),
          content: const Text('¿Estás seguro de que quieres eliminar este proyecto?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Eliminar'),
              onPressed: () {
                context.read<TranscribeCubit>().deleteProject(projectId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
