/// A single chat message passed to the OpenAI-compatible chat completion API.
class AIMessage {
  final String role;
  final String content;

  const AIMessage({required this.role, required this.content});
}
