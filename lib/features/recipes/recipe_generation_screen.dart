import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/claude_client.dart';
import '../../core/api/recipe_prompts.dart';
import 'recipe_providers.dart';

enum _GenerationStatus { streaming, done, error }

class RecipeGenerationScreen extends ConsumerStatefulWidget {
  const RecipeGenerationScreen({required this.ingredients, super.key});

  final List<IngredientInput> ingredients;

  @override
  ConsumerState<RecipeGenerationScreen> createState() =>
      _RecipeGenerationScreenState();
}

class _RecipeGenerationScreenState
    extends ConsumerState<RecipeGenerationScreen> {
  StreamSubscription<RecipeStreamEvent>? _subscription;
  _GenerationStatus _status = _GenerationStatus.streaming;
  String _response = '';
  RecipeUsage _usage = const RecipeUsage();
  String? _errorMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_startStream());
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _startStream() async {
    await _subscription?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _GenerationStatus.streaming;
      _response = '';
      _usage = const RecipeUsage();
      _errorMessage = null;
      _saving = false;
    });

    if (widget.ingredients.isEmpty) {
      setState(() {
        _status = _GenerationStatus.error;
        _errorMessage = '冰箱空空，先加一些食材吧';
      });
      return;
    }

    final client = ref.read(claudeClientProvider);
    if (client == null) {
      setState(() {
        _status = _GenerationStatus.error;
        _errorMessage = '請在 env.json 設定 ANTHROPIC_API_KEY 後重啟';
      });
      return;
    }

    _subscription = client
        .streamRecipes(ingredients: widget.ingredients)
        .listen(
          (event) {
            if (!mounted) {
              return;
            }
            switch (event) {
              case RecipeDelta(:final text):
                setState(() => _response += text);
              case RecipeDone(:final usage):
                unawaited(
                  Future<void>.microtask(() async {
                    await _subscription?.cancel();
                  }),
                );
                setState(() {
                  _usage = usage;
                  _status = _GenerationStatus.done;
                });
            }
          },
          onError: (Object error) {
            if (!mounted) {
              return;
            }
            setState(() {
              _status = _GenerationStatus.error;
              _errorMessage = _messageForError(error);
            });
          },
        );
  }

  Future<void> _cancelStream() async {
    await _subscription?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = _GenerationStatus.error;
      _errorMessage = '已取消生成';
    });
  }

  Future<void> _save() async {
    if (_response.trim().isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    final repository = ref.read(recipeRepositoryProvider);
    await repository.save(
      RecipeSaveInput(
        title: extractRecipeTitle(_response).isEmpty
            ? '未命名食譜'
            : extractRecipeTitle(_response),
        inventorySnapshot: encodeInventorySnapshot(widget.ingredients),
        response: _response,
        usage: _usage,
      ),
    );
    if (mounted) {
      context.go('/recipes');
    }
  }

  String _messageForError(Object error) {
    if (error is ClaudeApiException) {
      return error.message;
    }
    return '食譜生成失敗：$error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('推薦食譜')),
      body: SafeArea(
        child: switch (_status) {
          _GenerationStatus.streaming => _StreamingRecipeView(
            response: _response,
            onCancel: _cancelStream,
          ),
          _GenerationStatus.done => _DoneRecipeView(
            response: _response,
            usage: _usage,
            saving: _saving,
            onSave: _save,
            onRegenerate: _startStream,
          ),
          _GenerationStatus.error => _ErrorRecipeView(
            message: _errorMessage ?? '食譜生成失敗',
            onRetry: _startStream,
          ),
        },
      ),
    );
  }
}

class _StreamingRecipeView extends StatelessWidget {
  const _StreamingRecipeView({required this.response, required this.onCancel});

  final String response;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const LinearProgressIndicator(),
        Expanded(child: _MarkdownRecipe(response: response)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('停止生成'),
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneRecipeView extends StatelessWidget {
  const _DoneRecipeView({
    required this.response,
    required this.usage,
    required this.saving,
    required this.onSave,
    required this.onRegenerate,
  });

  final String response;
  final RecipeUsage usage;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _MarkdownRecipe(response: response)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _formatUsage(usage),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('儲存到歷史'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: saving ? null : onRegenerate,
                icon: const Icon(Icons.refresh),
                label: const Text('重新生成'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatUsage(RecipeUsage usage) {
    final input = usage.inputTokens?.toString() ?? '-';
    final output = usage.outputTokens?.toString() ?? '-';
    final cacheRead = usage.cacheReadTokens?.toString() ?? '-';
    return 'tokens：input $input / output $output / cache read $cacheRead';
  }
}

class _ErrorRecipeView extends StatelessWidget {
  const _ErrorRecipeView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkdownRecipe extends StatelessWidget {
  const _MarkdownRecipe({required this.response});

  final String response;

  @override
  Widget build(BuildContext context) {
    if (response.isEmpty) {
      return const Center(child: Text('正在整理食譜...'));
    }
    return Markdown(
      data: response,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    );
  }
}
