import 'package:flutter/material.dart';

import 'api.dart';
import 'task_list_page.dart';

void main() {
  runApp(TodosApp(api: TaskApi()));
}

class TodosApp extends StatelessWidget {
  const TodosApp({super.key, required this.api});

  final TaskApi api;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
    return MaterialApp(
      title: 'Todos',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: TaskListPage(api: api),
    );
  }
}
