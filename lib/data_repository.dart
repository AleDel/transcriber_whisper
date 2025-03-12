import 'package:transcriber_whisper/indexed_db_service.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session_data.dart';
import 'models/transcription_model.dart';
import 'package:uuid/uuid.dart';

class DataRepository {
  final IndexedDBService _indexedDBService;
  final Uuid _uuid = const Uuid();

  DataRepository(this._indexedDBService);

  Future<List<Project>> loadProjects() async {
    try {
      return await _indexedDBService.getProjects();
    } catch (e) {
      // Aquí puedes manejar el error de una manera más específica,
      // por ejemplo, loguearlo o lanzar una excepción personalizada.
      print("Error en DataRepository.loadProjects: $e");
      rethrow; // Re-lanza la excepción para que el ProjectCubit la maneje.
    }
  }

  Future<List<Project>> getProjects() async {
    return await _indexedDBService.getProjects();
  }

  Future<void> saveProject(Project project) async {
    await _indexedDBService.saveProject(project);
  }

  Future<Project?> getProject(String projectId) async {
    return await _indexedDBService.getProject(projectId);
  }

  Future<void> deleteProject(String projectId) async {
    await _indexedDBService.deleteProject(projectId);
  }

  Future<void> saveSession(SessionData session) async {
    await _indexedDBService.saveSession(session);
  }

  Future<SessionData> getSessionById(String sessionId) async {
    return await _indexedDBService.getSessionById(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _indexedDBService.deleteSession(sessionId);
  }

  Future<void> deleteSessions(String projectId) async {
    final project = await getProject(projectId);
    if (project != null) {
      for (var session in project.sessionsData) {
        await deleteSession(session.id);
      }
    }
  }

  Future<void> saveOriginalText(String projectId, String sessionId, String text) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(originalText: text);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveTranscription(String projectId, String sessionId, Transcription transcription) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex =project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(transcription: transcription);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveWaveformData(String projectId, String sessionId, String waveformData) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(waveformData: waveformData);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveWaveformImage(String projectId, String sessionId, String waveformImage) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(waveformImage: waveformImage);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveMelSpectrogram(String projectId, String sessionId, String melSpectrogram) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(melSpectrogram: melSpectrogram);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> saveAudio(List<int>? audioBytes, String filename, String projectId, String sessionId) async {
    try {
      final project = await getProject(projectId);
      if (project != null) {
        final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
        if (sessionIndex != -1) {
          final newSession = project.sessionsData[sessionIndex].copyWith(audioFilename: filename);
          final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
          final newProject = project.copyWith(sessions: newSessions);
          await saveProject(newProject);
        }
      }
    } catch (e) {
      print('Error saving audio: $e');
    }
  }

  Future<void> deleteAudio(String projectId, String sessionId) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(audioFilename: null);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> deleteTranscription(String projectId, String sessionId) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(transcription: null);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<void> deleteOriginalText(String projectId, String sessionId) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionIndex = project.sessionsData.indexWhere((s) => s.id == sessionId);
      if (sessionIndex != -1) {
        final newSession = project.sessionsData[sessionIndex].copyWith(originalText: null);
        final newSessions = List<SessionData>.from(project.sessionsData)..[sessionIndex] = newSession;
        final newProject = project.copyWith(sessions: newSessions);
        await saveProject(newProject);
      }
    }
  }

  Future<Project?> getFirstProject() async {
    final projects = await getProjects();
    if (projects.isNotEmpty) {
      return projects.first;
    }
    return null;
  }

  Future<SessionData> createSession(String projectId, String name) async {
    final project = await getProject(projectId);
    if (project != null) {
      final sessionId = _uuid.v4();
      final session = SessionData(id: sessionId, projectId: projectId, audioFilename: "audio.wav", name: name);
      final newSessions = List<SessionData>.from(project.sessionsData)..add(session);
      final newProject = project.copyWith(sessions: newSessions);
      await saveProject(newProject);
      return session;
    } else {
      throw Exception("Project not found");
    }
  }
}