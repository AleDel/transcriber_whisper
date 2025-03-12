part of 'project_cubit.dart';

enum ProjectStatus { initial, loading, loaded, error, success, failure }

class ProjectState extends Equatable {
  final ProjectStatus status;
  final List<Project>? projects;
  final Project? project;
  final String? errorMessage;
  final String? errorDetails;
  final List<PlatformFile> files;

  const ProjectState({
    this.status = ProjectStatus.initial,
    this.projects,
    this.project,
    this.errorMessage,
    this.errorDetails,
    this.files = const [],
  });

  ProjectState copyWith({
    ProjectStatus? status,
    List<Project>? projects,
    Project? project,
    String? errorMessage,
    String? errorDetails,
    List<PlatformFile>? files,
  }) {
    return ProjectState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      project: project ?? this.project,
      errorMessage: errorMessage ?? this.errorMessage,
      errorDetails: errorDetails ?? this.errorDetails,
      files: files ?? this.files,
    );
  }

  @override
  List<Object?> get props => [status, projects, project, errorMessage, errorDetails, files];
}