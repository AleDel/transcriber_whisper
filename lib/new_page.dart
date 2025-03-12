import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:transcriber_whisper/cubits/project_cubit.dart';
import 'package:transcriber_whisper/cubits/session_cubit.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/session_screen.dart';

import 'models/session_data.dart';
import 'models/session_status_data.dart';

class NewPage extends StatefulWidget {

  const NewPage({super.key});

  @override
  State<NewPage> createState() => _NewPageState();
}

class _NewPageState extends State<NewPage> {
  final GetIt getIt = GetIt.instance;
  @override
  Widget build(BuildContext context) {
    final projectCubit = context.read<ProjectCubit>();
    final sessionCubit = context.read<SessionCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Page'),
      ),
      body: BlocBuilder<ProjectCubit, ProjectState>(
        builder: (context, projectState) {
          if (projectState.status == ProjectStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (projectState.status == ProjectStatus.failure) {
            return Center(child: Text('Error: ${projectState.errorMessage}'));
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ElevatedButton(
                    onPressed: () async {
                      // Check if there are any projects
                      if (projectState.projects == null || projectState.projects!.isEmpty) {
                        // Create a new project
                        final newProject = await projectCubit.addProject("Default Project");
                        //print(newProject);
                        if (newProject != null) {
                          await sessionCubit.createSession(newProject.id, "Nueva Sesion");
                        } else {
                          // Show an error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error creating project')),
                          );
                        }
                      } else {
                        // Get the first project
                        final project = await projectCubit.getFirstProject();
                        if (project != null) {
                          await sessionCubit.createSession(project.id, "Nueva Sesion");
                        } else {
                          // Show an error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error getting project')),
                          );
                        }
                      }
                    },
                    child: const Text('Create Session'),
                  ),
                  if (projectState.projects == null || projectState.projects!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No projects found. A new project will be created."),
                    ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}