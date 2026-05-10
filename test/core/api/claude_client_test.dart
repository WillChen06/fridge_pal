import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fridge_pal/core/api/claude_client.dart';
import 'package:fridge_pal/core/api/recipe_prompts.dart';

void main() {
  const ingredients = [IngredientInput(name: '雞蛋', quantity: 6, unit: '顆')];

  test('normal stream emits deltas and done usage', () async {
    final adapter = _FakeAdapter(
      response: ResponseBody.fromString(
        _sse(<String>[
          _event('message_start', <String, Object?>{
            'usage': <String, Object?>{
              'input_tokens': 120,
              'cache_read_input_tokens': 80,
            },
          }),
          _event('content_block_delta', <String, Object?>{
            'delta': <String, Object?>{'text': '## 第一道：'},
          }),
          _event('content_block_delta', <String, Object?>{
            'delta': <String, Object?>{'text': '番茄炒蛋'},
          }),
          _event('message_delta', <String, Object?>{
            'usage': <String, Object?>{'output_tokens': 64},
          }),
          _event('message_stop', <String, Object?>{}),
        ]),
        200,
      ),
    );
    final client = ClaudeClient(
      apiKey: 'test-key',
      model: 'claude-sonnet-4-6',
      dio: Dio()..httpClientAdapter = adapter,
    );

    final events = await client
        .streamRecipes(ingredients: ingredients)
        .toList();

    expect(events.whereType<RecipeDelta>().map((event) => event.text), [
      '## 第一道：',
      '番茄炒蛋',
    ]);
    final done = events.whereType<RecipeDone>().single;
    expect(done.usage.inputTokens, 120);
    expect(done.usage.outputTokens, 64);
    expect(done.usage.cacheReadTokens, 80);
    expect(adapter.requestBody, contains('"stream":true'));
    expect(adapter.requestBody, contains('"cache_control"'));
  });

  test('401 maps to unauthorized exception', () async {
    final client = _clientForStatus(401);

    expect(
      client.streamRecipes(ingredients: ingredients).toList(),
      throwsA(
        isA<ClaudeApiException>().having(
          (error) => error.type,
          'type',
          ClaudeApiErrorType.unauthorized,
        ),
      ),
    );
  });

  test('429 maps to rate limited exception', () async {
    final client = _clientForStatus(429);

    expect(
      client.streamRecipes(ingredients: ingredients).toList(),
      throwsA(
        isA<ClaudeApiException>().having(
          (error) => error.type,
          'type',
          ClaudeApiErrorType.rateLimited,
        ),
      ),
    );
  });

  test('stream cancellation completes after first delta', () async {
    final client = ClaudeClient(
      apiKey: 'test-key',
      model: 'claude-sonnet-4-6',
      dio: Dio()
        ..httpClientAdapter = _FakeAdapter(
          response: ResponseBody.fromString(
            _event('content_block_delta', <String, Object?>{
              'delta': <String, Object?>{'text': '半成品'},
            }),
            200,
          ),
        ),
    );
    final events = <RecipeStreamEvent>[];
    final subscription = client
        .streamRecipes(ingredients: ingredients)
        .listen(events.add);

    await pumpEventQueue();
    await subscription.cancel();

    expect(events.single, isA<RecipeDelta>());
  });
}

ClaudeClient _clientForStatus(int statusCode) {
  return ClaudeClient(
    apiKey: 'test-key',
    model: 'claude-sonnet-4-6',
    dio: Dio()
      ..httpClientAdapter = _FakeAdapter(
        response: ResponseBody.fromString('', statusCode),
      ),
  );
}

String _event(String name, Map<String, Object?> data) {
  return 'event: $name\n'
      'data: ${jsonEncode(data)}\n\n';
}

String _sse(List<String> events) => events.join();

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.response});

  final ResponseBody response;
  String? requestBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.data != null) {
      requestBody = jsonEncode(options.data);
    }
    return response;
  }

  @override
  void close({bool force = false}) {}
}
