import 'package:flutter/material.dart';

import 'api.dart';
import 'task.dart';
import 'task_form_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key, required this.api});

  final TaskApi api;

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  List<Task>? _tasks;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tasks = await widget.api.listTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  void _replace(Task updated) {
    setState(() {
      _tasks = [
        for (final t in _tasks ?? <Task>[]) t.id == updated.id ? updated : t,
      ];
    });
  }

  Future<void> _cycleStatus(Task task) async {
    try {
      _replace(await widget.api.updateTask(task.id, status: task.status.next));
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openForm([Task? task]) async {
    final saved = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => TaskFormPage(api: widget.api, task: task),
      ),
    );
    if (saved == null || !mounted) return;
    if (task == null) {
      setState(() => _tasks = [...?_tasks, saved]);
    } else {
      _replace(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'New task',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final tasks = _tasks;
    if (tasks == null && _error != null) {
      return _Message(
        icon: Icons.cloud_off,
        text: 'Could not load tasks.\n$_error',
        action: FilledButton(onPressed: _load, child: const Text('Retry')),
      );
    }
    if (tasks == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            _Message(icon: Icons.checklist, text: 'No tasks yet. Tap + to add one.'),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final task = tasks[i];
          return _TaskTile(
            task: task,
            onTap: () => _openForm(task),
            onStatusTap: () => _cycleStatus(task),
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onTap,
    required this.onStatusTap,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onStatusTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.done;
    return ListTile(
      onTap: onTap,
      leading: IconButton(
        tooltip: '${task.status.label} – tap to change',
        icon: Icon(statusIcon(task.status), color: statusColor(context, task.status)),
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
      subtitle: task.description.isEmpty
          ? null
          : Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatDate(task.insertedAt),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
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
