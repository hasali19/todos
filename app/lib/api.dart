import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'task.dart';

String defaultApiUrl() {
  const fromEnv = String.fromEnvironment('API_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kIsWeb) return Uri.base.resolve('/api').toString();
  return 'http://localhost:3000';
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class TaskApi {
  TaskApi({String? baseUrl, http.Client? client})
    : baseUrl = baseUrl ?? defaultApiUrl(),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _jsonHeaders = {'content-type': 'application/json'};

  Future<List<Task>> listTasks() async {
    final res = await _client.get(Uri.parse('$baseUrl/tasks'));
    final body = _decode(res) as List<dynamic>;
    return body.map((t) => Task.fromJson(t as Map<String, dynamic>)).toList();
  }

  Future<Task> createTask({
    required String title,
    String description = '',
    TaskStatus? status,
  }) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'title': title,
        'description': description,
        if (status != null) 'status': status.wire,
      }),
    );
    return Task.fromJson(_decode(res) as Map<String, dynamic>);
  }

  /// Only the fields that are passed get changed.
  Future<Task> updateTask(
    int id, {
    String? title,
    String? description,
    TaskStatus? status,
  }) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl/tasks/$id'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'title': ?title,
        'description': ?description,
        if (status != null) 'status': status.wire,
      }),
    );
    return Task.fromJson(_decode(res) as Map<String, dynamic>);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    // The backend sends {"error": "..."}; axum's own rejections are plain text.
    String message = res.body;
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] is String) message = body['error'];
    } catch (_) {}
    throw ApiException('Request failed (${res.statusCode}): $message');
  }
}
