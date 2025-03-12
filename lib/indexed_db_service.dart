import 'dart:async';
import 'package:idb_shim/idb_browser.dart';
import 'package:transcriber_whisper/models/project.dart';
import 'package:transcriber_whisper/models/session_data.dart';

class IndexedDBService {
  static const String dbName = 'transcriber_db';
  static const String projectStoreName = 'projects';
  static const String sessionStoreName = 'sessions';

  IdbFactory? _idbFactory;
  Database? _db;

  Future<IdbFactory> getIdbFactory() async {
    if (_idbFactory == null) {
      _idbFactory = idbFactoryBrowser;
    }
    return _idbFactory!;
  }

  Future<Database> getDb() async {
    if (_db == null) {
      final idbFactory = await getIdbFactory();
      //final idbFactory = getIdbFactoryPersistent('test/tmp/out');
      _db = await idbFactory.open(dbName, version: 1, onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;
        if (!db.objectStoreNames.contains(projectStoreName)) {
          db.createObjectStore(projectStoreName, keyPath: 'id');
        }
        if (!db.objectStoreNames.contains(sessionStoreName)) {
          db.createObjectStore(sessionStoreName, keyPath: 'id');
        }
      });
    }
    return _db!;
  }

  Future<void> saveProject(Project project) async {
    try {
      final db = await getDb();
      final txn = db.transaction(projectStoreName, idbModeReadWrite);
      final store = txn.objectStore(projectStoreName);
      await store.put(project.toMap());
      await txn.completed;
    } catch (e) {
      print("Error en IndexedDBService.saveProject: $e");
      rethrow;
    }
  }

  Future<Project?> getProject(String projectId) async {
    try {
      final db = await getDb();
      final txn = db.transaction(projectStoreName, idbModeReadOnly);
      final store = txn.objectStore(projectStoreName);
      final projectMap = await store.getObject(projectId);
      await txn.completed;
      return projectMap != null ? Project.fromMap(projectMap as Map<String, dynamic>) : null;
    } catch (e) {
      print("Error en IndexedDBService.loadProject: $e");
      rethrow;
    }
  }

  Future<List<Project>> getProjects() async {
    try {
      final db = await getDb();
      final txn = db.transaction(projectStoreName, idbModeReadOnly);
      final store = txn.objectStore(projectStoreName);
      final cursor = await store.openCursor(autoAdvance: true);
      final projects = <Project>[];
      await cursor.listen((event) {
        projects.add(Project.fromMap(event.value as Map<String, dynamic>));
      }).asFuture();
      await txn.completed;
      return projects;
    } catch (e) {
      print("Error en IndexedDBService.getProjects: $e");
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    try {
      final db = await getDb();
      final txn = db.transaction(projectStoreName, idbModeReadWrite);
      final store = txn.objectStore(projectStoreName);
      await store.delete(projectId);
      await txn.completed;
    } catch (e) {
      print("Error en IndexedDBService.deleteProject: $e");
      rethrow;
    }
  }

  Future<void> saveSession(SessionData session) async {
    try {
      final db = await getDb();
      final txn = db.transaction(sessionStoreName, idbModeReadWrite);
      final store = txn.objectStore(sessionStoreName);
      await store.put(session.toMap());
      await txn.completed;
    } catch (e) {
      print("Error en IndexedDBService.saveSession: $e");
      rethrow;
    }
  }

  Future<SessionData> getSessionById(String sessionId) async {
    try {
      final db = await getDb();
      final txn = db.transaction(sessionStoreName, idbModeReadOnly);
      final store = txn.objectStore(sessionStoreName);
      final sessionMap = await store.getObject(sessionId);
      await txn.completed;
      if(sessionMap == null){
        throw Exception("Session not found");
      }
      return SessionData.fromMap(sessionMap as Map<String, dynamic>);
    } catch (e) {
      print("Error en IndexedDBService.loadSession: $e");
      rethrow;
    }
  }

  Future<void> deleteSession(String sessionId) async {
    try {
      final db = await getDb();
      final txn = db.transaction(sessionStoreName, idbModeReadWrite);
      final store = txn.objectStore(sessionStoreName);
      await store.delete(sessionId);
      await txn.completed;
    } catch (e) {
      print("Error en IndexedDBService.deleteSession: $e");
      rethrow;
    }
  }
}