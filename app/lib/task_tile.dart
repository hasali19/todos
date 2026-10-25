import 'package:flutter/material.dart';

import 'task.dart';

/// One task in a list. Tapping the status icon cycles the status.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onStatusTap,
    this.subtasks = const [],
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onStatusTap;

  /// Direct subtasks of [task], used to show progress.
  final List<Task> subtasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.done;
    final doneSubtasks = subtasks
        .where((t) => t.status == TaskStatus.done)
        .length;
    return ListTile(
      onTap: onTap,
      leading: IconButton(
        tooltip: '${task.status.label} – tap to change',
        icon: Icon(
          statusIcon(task.status),
          color: statusColor(context, task.status),
        ),
        onPressed: onStatusTap,
      ),
      title: Text(
        task.title,
        style: done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.onSurfaceVariant,
              )
            : null,
      ),
      subtitle: task.description.isEmpty && subtasks.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subtasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$doneSubtasks/${subtasks.length} subtasks',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      trailing: Text(
        formatDate(task.insertedAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

IconData statusIcon(TaskStatus status) => switch (status) {
  TaskStatus.todo => Icons.radio_button_unchecked,
  TaskStatus.inProgress => Icons.timelapse,
  TaskStatus.done => Icons.check_circle,
};

Color statusColor(BuildContext context, TaskStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    TaskStatus.todo => scheme.outline,
    TaskStatus.inProgress => scheme.tertiary,
    TaskStatus.done => scheme.primary,
  };
}

String formatDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
