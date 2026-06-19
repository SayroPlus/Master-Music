/// Exception thrown when the Groq API key has not been configured.
///
/// The user must paste their API key in Settings before AI features can work.
class GroqNotConfiguredException implements Exception {
  final String message;

  const GroqNotConfiguredException([
    this.message =
        'Groq API key not configured. Please add your API key in Settings.',
  ]);

  @override
  String toString() => 'GroqNotConfiguredException: $message';
}
