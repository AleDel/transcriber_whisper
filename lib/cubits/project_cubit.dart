import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session_data.dart';
import 'package:uuid/uuid.dart';

import '../data_repository.dart';

part 'project_state.dart';

class ProjectCubit extends Cubit<ProjectState> {
  final DataRepository _dataRepository;
  final Uuid _uuid = const Uuid();

  ProjectCubit(this._dataRepository) : super(const ProjectState()) {
    loadProjects();
  }

  // Métodos para gestionar proyectos
  Future<void> loadProjects() async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      final projects = await _dataRepository.getProjects();
      emit(state.copyWith(projects: projects, status: ProjectStatus.success));
    } catch (e) {
      _handleError(e);
    }
  }

  Future<Project?> addProject(String projectName) async {
    print("Add proyecto: $projectName");
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      final projectId = _uuid.v4();
      final project = Project(id: projectId, name: projectName);
      await _dataRepository.saveProject(project);
      await loadProjects();
      return project; // Devolver el proyecto creado
    } catch (e) {
      _handleError(e);
      return null; // Devolver null en caso de error
    }
  }

  // Nuevo método para obtener el primer proyecto
  Future<Project?> getFirstProject() async {
    if (state.projects == null) return null;
    await loadProjects();
    if (state.projects!.isNotEmpty) {
      return state.projects?.first;
    } else {
      return null;
    }
  }

  Future<void> deleteProject(String projectId) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      await _dataRepository.deleteProject(projectId);
      await loadProjects();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> getProject(String projectId) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      final project = await _dataRepository.getProject(projectId);
      if (project != null) {
        emit(state.copyWith(project: project, status: ProjectStatus.success));
      } else {
        emit(state.copyWith(status: ProjectStatus.failure, errorMessage: 'No se pudo cargar el proyecto'));
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> addSessionsToProject(List<PlatformFile> files, {String? projectId}) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      Project? project;
      if (projectId != null) {
        project = await _dataRepository.getProject(projectId);
      }
      if (project == null) {
        projectId = _uuid.v4();
        final projectName = 'Proyecto ${state.projects?.length ?? 0 + 1}';
        project = Project(id: projectId, name: projectName, sessionsData: []);
      }
      final sessions = <SessionData>[];
      for (final file in files) {
        final sessionId = _uuid.v4();
        //final audioPlayer = AudioPlayer();
        final session = SessionData(id: sessionId, projectId: projectId!, audioFilename: file.name, userAudioBytes: file.bytes, name: file.name);
        sessions.add(session);
      }
      final updatedSessions = [...project.sessionsData, ...sessions];
      final updatedProject = project.copyWith(sessions: updatedSessions);
      await _dataRepository.saveProject(updatedProject);
      await loadProjects();
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> deleteAllSessions(String projectId) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      final project = await _dataRepository.getProject(projectId);
      if (project != null) {
        final updatedProject = project.copyWith(sessions: []);
        await _dataRepository.saveProject(updatedProject);
        await loadProjects();
      } else {
        emit(state.copyWith(status: ProjectStatus.failure, errorMessage: 'Project not found'));
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> startProcessingSession(SessionData session) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      await _dataRepository.saveSession(session);
      final project = await _dataRepository.getProject(session.projectId);
      if (project != null) {
        final sessionIndex = project.sessionsData.indexWhere((s) => s.id == session.id);
        if (sessionIndex != -1) {
          project.sessionsData[sessionIndex] = session;
        }
        await _dataRepository.saveProject(project);
        await loadProjects();
      } else {
        emit(state.copyWith(status: ProjectStatus.failure, errorMessage: 'Error al procesar la sesión', errorDetails: 'Proyecto no encontrado'));
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void updateProject(Project project) async {
    if (state.projects == null) return;
    emit(state.copyWith(status: ProjectStatus.loading));
    try {
      await _dataRepository.saveProject(project);
      emit(state.copyWith(status: ProjectStatus.success, project: project));
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> saveOriginalText(String projectId, String sessionId, String originalText) async {
    // Implementar la lógica para guardar el texto original de una sesión
    // ...
  }

  void addFiles(List<PlatformFile> files) {
    emit(state.copyWith(files: files));
  }

  void clearFiles() {
    emit(state.copyWith(files: []));
  }

  void setStatus(ProjectStatus status) {
    emit(state.copyWith(status: status));
  }

  void _handleError(Object e) {
    emit(state.copyWith(status: ProjectStatus.failure, errorMessage: e.toString()));
  }
}