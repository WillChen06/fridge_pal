/// Centralized access to compile-time environment variables.
///
/// Values are injected via `--dart-define-from-file=env.json` (see
/// `env.example.json` for the schema). Never hard-code secrets here.
class Env {
  const Env._();

  static const String anthropicApiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
  );

  static const String anthropicModel = String.fromEnvironment(
    'ANTHROPIC_MODEL',
    defaultValue: 'claude-sonnet-4-20250514',
  );

  static bool get hasAnthropicKey => anthropicApiKey.isNotEmpty;
}
