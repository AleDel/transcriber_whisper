import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session.dart';

import 'models/transcription_model.dart';

class DataRepository {
  static const String _projectsKey = 'projects';

  // Métodos para los proyectos
  Future<List<Project>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_projectsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ProjectExtension.fromMap(json)).toList(); // Usa la extensión
  }

  Future<void> saveProjects(List<Project> projects) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = projects.map((project) => project.toMap()).toList(); // Usa la extensión
    prefs.setString(_projectsKey, jsonEncode(jsonList));
  }

  Future<void> saveProject(Project project) async {
    final projects = await loadProjects();
    final existingIndex = projects.indexWhere((p) => p.id == project.id);
    if (existingIndex != -1) {
      projects[existingIndex] = project;
    } else {
      projects.add(project);
    }
    await saveProjects(projects);
  }

  Future<Project?> loadProject(String projectId) async {
    final projects = await loadProjects();
    try {
      return projects.firstWhere((p) => p.id == projectId);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteProject(String projectId) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == projectId);
    await saveProjects(projects);
  }

  // Métodos para las sesiones
  Future<void> saveSession(String projectId, Session session) async {
    final project = await loadProject(projectId);
    if (project != null) {
      final newSessions = List<Session>.from(project.sessions)..add(session);
      final newProject = project.copyWith(sessions: newSessions);
      await saveProject(newProject);
    }
  }

  Future<List<Session>> loadSessions(String projectId) async {
    final project = await loadProject(projectId);
    if (project != null) {
      return project.sessions;
    } else {
      return [];
    }
  }

  Future<void> deleteSession(String projectId, String sessionId) async {
    final project = await loadProject(projectId);
    if (project != null) {
      final newSessions = List<Session>.from(project.sessions)..removeWhere((s) => s.id == sessionId);
      final newProject = project.copyWith(sessions: newSessions);
      await saveProject(newProject);
    }
  }

  Future<void> deleteSessions(String projectId) async {
    final project = await loadProject(projectId);
    if (project != null) {
      final newProject = project.copyWith(sessions: []);
      await saveProject(newProject);
    }
  }

  Future<void> saveOriginalText(String projectId, String sessionId, String text) async {
    final project = await loadProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessions[sessionIndex].copyWith(originalText: text);
        final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveTranscription(String projectId, String sessionId, Transcription transcription) async {
    final project = await loadProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessions[sessionIndex].copyWith(transcription: transcription);
        final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> _saveFile(List<int>? fileBytes, String filename) async {
    if (fileBytes == null) {
      print('No se pudo guardar el archivo porque fileBytes es null');
      return;
    }
    final blob = html.Blob([Uint8List.fromList(fileBytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = filename;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Future<void> saveAudio(List<int>? audioBytes, String filename, String projectId, String sessionId) async {
    try {
      final project = await loadProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessions[sessionIndex].copyWith(audioFilename: filename);
          final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
      await _saveFile(audioBytes, filename);
    } catch (e) {
      print('Error saving audio: $e');
    }
  }
  Future<void> saveWav(List<int>? audioBytes, String filename, String projectId, String sessionId) async {
    try {
      final project = await loadProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessions[sessionIndex].copyWith(audioFilename: filename);
          final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
      await _saveFile(audioBytes, filename);
    } catch (e) {
      print('Error saving audio: $e');
    }
  }

  Future<void> deleteAudio(String projectId, String sessionId) async {
    try {
      final project = await loadProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessions[sessionIndex].copyWith(audioFilename:null);
          final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
    } catch (e) {
      print('Error deleting audio: $e');
    }
  }

  Future<void> deleteTranscription(String projectId, String sessionId) async {
    try {
      final project = await loadProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessions[sessionIndex].copyWith(transcription: null);
          final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
    } catch (e) {
      print('Error deleting transcription: $e');}
  }

  Future<void> deleteOriginalText(String projectId, String sessionId) async {
    try {
      final project = await loadProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessions.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessions[sessionIndex].copyWith(originalText: null);
          final newSessions = List<Session>.from(project.sessions)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
    } catch (e) {
      print('Error deleting original text: $e');
    }
  }

  Future<void> loadAudio(String projectId, String sessionId) async {
    try {
      print('No se puede cargar el audio porque se descarga');
    } catch (e) {
      print('Error loading audio: $e');
    }
  }
}

// Extensiones para convertir a Map y desde Map
extension ProjectExtension on Project {
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sessions': sessions.map((s) => s.toMap()).toList(),
    };
  }

  static Project fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      sessions: (map['sessions'] as List<dynamic>?)?.map((s) => Session.fromMap(s)).toList() ?? [],
    );
  }
}