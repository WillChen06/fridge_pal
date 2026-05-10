import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env.dart';
import 'recipe_prompts.dart';

enum ClaudeApiErrorType {
  missingApiKey,
  unauthorized,
  rateLimited,
  temporary,
  network,
  unknown,
}

class ClaudeApiException implements Exception {
  const ClaudeApiException(this.type, this.message, {this.statusCode});

  final ClaudeApiErrorType type;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class RecipeUsage {
  const RecipeUsage({
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
  });

  final int? inputTokens;
  final int? outputTokens;
  final int? cacheReadTokens;

  RecipeUsage copyWith({
    int? inputTokens,
    int? outputTokens,
    int? cacheReadTokens,
  }) {
    return RecipeUsage(
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cacheReadTokens: cacheReadTokens ?? this.cacheReadTokens,
    );
  }
}

sealed class RecipeStreamEvent {
  const RecipeStreamEvent();
}

class RecipeDelta extends RecipeStreamEvent {
  const RecipeDelta(this.text);

  final String text;
}

class RecipeDone extends RecipeStreamEvent {
  const RecipeDone(this.usage);

  final RecipeUsage usage;
}

class ClaudeClient {
  ClaudeClient({required String apiKey, required String model, Dio? dio})
    : _apiKey = apiKey,
      _model = model,
      _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.anthropic.com',
              responseType: ResponseType.stream,
            ),
          );

  final String _apiKey;
  final String _model;
  final Dio _dio;

  Stream<RecipeStreamEvent> streamRecipes({
    required List<IngredientInput> ingredients,
  }) async* {
    if (_apiKey.isEmpty) {
      throw const ClaudeApiException(
        ClaudeApiErrorType.missingApiKey,
        '請在 env.json 設定 ANTHROPIC_API_KEY 後重啟',
      );
    }

    final response = await _postStreamingRequest(ingredients);
    RecipeUsage usage = const RecipeUsage();

    await for (final event in _parseSse(response.data!.stream)) {
      final data = event.data;
      switch (event.name) {
        case 'message_start':
        case 'message_delta':
          usage = _readUsage(data, usage);
        case 'content_block_delta':
          final text = _readDeltaText(data);
          if (text != null && text.isNotEmpty) {
            yield RecipeDelta(text);
          }
        case 'message_stop':
          usage = _readUsage(data, usage);
          yield RecipeDone(usage);
        case 'error':
          throw _exceptionFromErrorEvent(data);
      }
    }
  }

  Future<Response<ResponseBody>> _postStreamingRequest(
    List<IngredientInput> ingredients,
  ) async {
    try {
      return await _dio
          .post<ResponseBody>(
            '/v1/messages',
            data: <String, Object?>{
              'model': _model,
              'max_tokens': 2048,
              'system': <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'text',
                  'text': kRecipeSystemPrompt,
                  'cache_control': <String, Object?>{'type': 'ephemeral'},
                },
              ],
              'messages': <Map<String, Object?>>[
                <String, Object?>{
                  'role': 'user',
                  'content': RecipePromptBuilder.buildUserMessage(ingredients),
                },
              ],
              'stream': true,
            },
            options: Options(
              responseType: ResponseType.stream,
              headers: <String, Object?>{
                'x-api-key': _apiKey,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
              },
              validateStatus: (_) => true,
            ),
          )
          .then((response) {
            final statusCode = response.statusCode ?? 0;
            if (statusCode < 200 || statusCode >= 300) {
              throw _exceptionFromStatus(statusCode);
            }
            return response;
          });
    } on DioException catch (error) {
      throw _exceptionFromDio(error);
    } on SocketException {
      throw const ClaudeApiException(
        ClaudeApiErrorType.network,
        '網路連線失敗，請稍後再試',
      );
    }
  }

  Stream<_SseEvent> _parseSse(Stream<List<int>> stream) async* {
    final lines = stream
        .map<List<int>>((bytes) => bytes)
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    String? eventName;
    final dataLines = <String>[];

    await for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        final event = _buildSseEvent(eventName, dataLines);
        if (event != null) {
          yield event;
        }
        eventName = null;
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trim());
      }
    }

    final event = _buildSseEvent(eventName, dataLines);
    if (event != null) {
      yield event;
    }
  }

  _SseEvent? _buildSseEvent(String? eventName, List<String> dataLines) {
    if (eventName == null || dataLines.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(dataLines.join('\n'));
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    return _SseEvent(eventName, decoded);
  }

  String? _readDeltaText(Map<String, Object?> data) {
    final delta = data['delta'];
    if (delta is! Map<String, Object?>) {
      return null;
    }
    final text = delta['text'];
    return text is String ? text : null;
  }

  RecipeUsage _readUsage(Map<String, Object?> data, RecipeUsage previous) {
    final usage = data['usage'];
    if (usage is! Map<String, Object?>) {
      return previous;
    }
    return previous.copyWith(
      inputTokens: _readInt(usage['input_tokens']),
      outputTokens: _readInt(usage['output_tokens']),
      cacheReadTokens:
          _readInt(usage['cache_read_input_tokens']) ??
          _readInt(usage['cache_read_tokens']),
    );
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  ClaudeApiException _exceptionFromStatus(int statusCode) {
    return switch (statusCode) {
      401 => const ClaudeApiException(
        ClaudeApiErrorType.unauthorized,
        'Claude API 認證失敗，請檢查 ANTHROPIC_API_KEY',
        statusCode: 401,
      ),
      429 => const ClaudeApiException(
        ClaudeApiErrorType.rateLimited,
        'Claude API 額度或速率限制已達上限，請稍後再試',
        statusCode: 429,
      ),
      >= 500 => ClaudeApiException(
        ClaudeApiErrorType.temporary,
        'Claude API 暫時無法使用，請稍後再試',
        statusCode: statusCode,
      ),
      _ => ClaudeApiException(
        ClaudeApiErrorType.unknown,
        'Claude API 回傳錯誤（HTTP $statusCode）',
        statusCode: statusCode,
      ),
    };
  }

  ClaudeApiException _exceptionFromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return _exceptionFromStatus(statusCode);
    }
    return const ClaudeApiException(ClaudeApiErrorType.network, '網路連線失敗，請稍後再試');
  }

  ClaudeApiException _exceptionFromErrorEvent(Map<String, Object?> data) {
    final error = data['error'];
    if (error is Map<String, Object?>) {
      final type = error['type'];
      final message = error['message'];
      if (type == 'rate_limit_error') {
        return ClaudeApiException(
          ClaudeApiErrorType.rateLimited,
          message is String ? message : 'Claude API 額度或速率限制已達上限',
        );
      }
      return ClaudeApiException(
        ClaudeApiErrorType.unknown,
        message is String ? message : 'Claude API 串流回傳錯誤',
      );
    }
    return const ClaudeApiException(
      ClaudeApiErrorType.unknown,
      'Claude API 串流回傳錯誤',
    );
  }
}

final claudeClientProvider = Provider<ClaudeClient?>((ref) {
  if (!Env.hasAnthropicKey) {
    return null;
  }
  return ClaudeClient(apiKey: Env.anthropicApiKey, model: Env.anthropicModel);
});

class _SseEvent {
  const _SseEvent(this.name, this.data);

  final String name;
  final Map<String, Object?> data;
}
