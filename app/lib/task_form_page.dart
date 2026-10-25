import 'package:flutter/material.dart';

import 'api.dart';
import 'task.dart';
import 'task_tile.dart';

/// Creates a new task, or edits [task] when one is given.
/// A new task becomes a subtask when [parentId] is set.
/// Pops with the saved [Task].
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, required this.api, this.task, this.parentId});

  final TaskApi api;
  final Task? task;
  final int? parentId;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(
    text: widget.task?.description,
  );
  late TaskStatus _status = widget.task?.status ?? TaskStatus.todo;
  bool _saving = false;

  /// Every task, so subtasks can show their own progress; null while loading.
  List<Task>? _allTasks;

  List<Task> _childrenOf(int id) => [
    for (final t in _allTasks ?? <Task>[])
      if (t.parentId == id) t,
  ];

  bool get _isNew => widget.task == null;

  @override
  void initState() {
    super.initState();
    if (!_isNew) _loadSubtasks();
  }

  Future<void> _loadSubtasks() async {
    try {
      final all = await widget.api.listTasks();
      if (!mounted) return;
      setState(() => _allTasks = all);
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  /// Opens a form for a new subtask (no [task]) or an existing one.
  Future<void> _openSubtask([Task? task]) async {
    await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (_) => TaskFormPage(
          api: widget.api,
          task: task,
          parentId: task == null ? widget.task!.id : null,
        ),
      ),
    );
    if (mounted) await _loadSubtasks();
  }

  Future<void> _cycleSubtaskStatus(Task task) async {
    try {
      final updated = await widget.api.updateTask(
        task.id,
        status: task.status.next,
      );
      if (!mounted) return;
      setState(() {
        _allTasks = [
          for (final t in _allTasks!) t.id == updated.id ? updated : t,
        ];
      });
    } catch (e) {
      _showError(e);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final title = _title.text.trim();
      final description = _description.text.trim();
      final saved = _isNew
          ? await widget.api.createTask(
              title: title,
              description: description,
              status: _status,
              parentId: widget.parentId,
            )
          : await widget.api.updateTask(
              widget.task!.id,
              title: title,
              description: description,
              status: _status,
            );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch ((
          _isNew,
          widget.parentId ?? widget.task?.parentId,
        )) {
          (true, null) => 'New task',
          (true, _) => 'New subtask',
          (false, null) => 'Edit task',
          (false, _) => 'Edit subtask',
        }),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              autofocus: _isNew,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Description',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Status', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TaskStatus>(
              segments: [
                for (final s in TaskStatus.values)
                  ButtonSegment(
                    value: s,
                    label: Text(s.label),
                    icon: Icon(statusIcon(s)),
                  ),
              ],
              selected: {_status},
              onSelectionChanged: (sel) => setState(() => _status = sel.first),
            ),
            if (!_isNew) ..._buildSubtasks(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSubtasks() {
    final subtasks = _allTasks == null ? null : _childrenOf(widget.task!.id);
    return [
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: Text(
              'Subtasks',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          TextButton.icon(
            onPressed: () => _openSubtask(),
            icon: const Icon(Icons.add),
            label: const Text('Add subtask'),
          ),
        ],
      ),
      if (subtasks == null)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (subtasks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No subtasks yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, sub) in subtasks.indexed) ...[
                if (i > 0) const Divider(height: 1),
                TaskTile(
                  task: sub,
                  subtasks: _childrenOf(sub.id),
                  onTap: () => _openSubtask(sub),
                  onStatusTap: () => _cycleSubtaskStatus(sub),
                ),
              ],
            ],
          ),
        ),
    ];
  }
}
