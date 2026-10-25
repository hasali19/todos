enum TaskStatus {
  todo('todo', 'To do'),
  inProgress('in_progress', 'In progress'),
  done('done', 'Done');

  const TaskStatus(this.wire, this.label);

  /// The value the API uses.
  final String wire;
  final String label;

  static TaskStatus fromWire(String value) =>
      values.firstWhere((s) => s.wire == value);

  TaskStatus get next => values[(index + 1) % values.length];
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.insertedAt,
  });

  final int id;
  final String title;
  final String description;
  final TaskStatus status;
  final DateTime insertedAt;

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String,
        status: TaskStatus.fromWire(json['status'] as String),
        insertedAt: DateTime.parse(json['inserted_at'] as String),
      );
}
