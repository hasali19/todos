import 'package:flutter/material.dart';

import 'api.dart';
import 'task.dart';
import 'task_list_page.dart' show statusIcon;

/// Creates a new task, or edits [task] when one is given.
/// Pops with the saved [Task].
class TaskFormPage extends StatefulWidget {
  const TaskFormPage({super.key, required this.api, this.task});

  final TaskApi api;
  final Task? task;

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _description = TextEditingController(text: widget.task?.description);
  late TaskStatus _status = widget.task?.status ?? TaskStatus.todo;
  bool _saving = false;

  bool get _isNew => widget.task == null;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New task' : 'Edit task'),
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
          ],
        ),
      ),
    );
  }
}
