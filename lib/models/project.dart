import 'package:equatable/equatable.dart';
import 'package:transcriber_whisper/models/session_data.dart';

class Project extends Equatable {
  final String id;
  final String name;
  final List<SessionData> sessionsData;

  const Project({
    required this.id,
    required this.name,
    this.sessionsData = const [],
  });

  Project copyWith({
    String? id,
    String? name,
    List<SessionData>? sessions,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      sessionsData: sessions ?? this.sessionsData,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sessions': sessionsData.map((s) => s.toMap()).toList(),
    };
  }

  static Project fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as String,
      name: map['name'] as String,
      sessionsData: map['sessions'] != null
          ? List<SessionData>.from((map['sessions'] as List).map((s) => SessionData.fromMap(s as Map<String, dynamic>)))
          : [],
    );
  }

  @override
  List<Object?> get props => [id, name, sessionsData];
}