import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:todos/api.dart';
import 'package:todos/main.dart';

/// A tiny in-memory stand-in for the backend.
MockClient fakeBackend() {
  final tasks = <Map<String, dynamic>>[];
  return MockClient((req) async {
    final json = {'content-type': 'application/json'};
    if (req.method == 'GET' && req.url.path == '/tasks') {
      return http.Response(jsonEncode(tasks), 200, headers: json);
    }
    if (req.method == 'POST' && req.url.path == '/tasks') {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final task = {
        'id': tasks.length + 1,
        'title': body['title'],
        'description': body['description'] ?? '',
        'status': body['status'] ?? 'todo',
        'parent_id': body['parent_id'],
        'inserted_at': '2026-10-25T15:13:12.754Z',
      };
      tasks.add(task);
      return http.Response(jsonEncode(task), 201, headers: json);
    }
    final match = RegExp(r'^/tasks/(\d+)$').firstMatch(req.url.path);
    if (req.method == 'PATCH' && match != null) {
      final id = int.parse(match.group(1)!);
      final task = tasks.firstWhere((t) => t['id'] == id);
      task.addAll(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(task), 200, headers: json);
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

void main() {
  testWidgets('create a task, then change its status', (tester) async {
    final api = TaskApi(baseUrl: 'http://test', client: fakeBackend());
    await tester.pumpWidget(TodosApp(api: api));
    await tester.pumpAndSettle();

    expect(find.textContaining('No tasks yet'), findsOneWidget);

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Buy milk',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.timelapse), findsOneWidget);
  });

  testWidgets('empty title is rejected', (tester) async {
    final api = TaskApi(baseUrl: 'http://test', client: fakeBackend());
    await tester.pumpWidget(TodosApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('add a subtask from the edit page', (tester) async {
    final api = TaskApi(baseUrl: 'http://test', client: fakeBackend());
    await api.createTask(title: 'Plan trip');
    await tester.pumpWidget(TodosApp(api: api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan trip'));
    await tester.pumpAndSettle();
    expect(find.text('No subtasks yet.'), findsOneWidget);

    await tester.tap(find.text('Add subtask'));
    await tester.pumpAndSettle();
    expect(find.text('New subtask'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Book flights',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back on the parent's edit page, the subtask is listed.
    expect(find.text('Book flights'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The main list only shows top-level tasks, with subtask progress.
    expect(find.text('Plan trip'), findsOneWidget);
    expect(find.text('Book flights'), findsNothing);
    expect(find.text('0/1 subtasks'), findsOneWidget);
  });
}
