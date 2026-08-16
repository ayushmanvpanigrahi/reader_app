import 'package:flutter_test/flutter_test.dart';
import 'package:reader_app/features/highlights/controllers/highlights_controller.dart';

void main() {
  group('HighlightsController.parseExplanation', () {
    test('parses standard LABLE: format', () {
      const raw = 'SIMPLE_MEANING: Life is about growth.\n'
          'AUTHOR_CONTEXT: The author wants to inspire.\n'
          'REFLECTION_QUESTION: How do you grow?\n'
          'ANALOGY: Like a seed in soil.\n'
          'TAKEAWAY: Keep growing every day.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Life is about growth.');
      expect(result.authorContext, 'The author wants to inspire.');
      expect(result.reflectionQuestion, 'How do you grow?');
      expect(result.analogy, 'Like a seed in soil.');
      expect(result.takeaway, 'Keep growing every day.');
    });

    test('parses markdown bold labels (**LABEL:**)', () {
      const raw = '**SIMPLE_MEANING:** This is important.\n'
          '**AUTHOR_CONTEXT:** Written in context.\n'
          '**REFLECTION_QUESTION:** Think about this.\n'
          '**ANALOGY:** Like baking bread.\n'
          '**TAKEAWAY:** Stay focused.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'This is important.');
      expect(result.authorContext, 'Written in context.');
    });

    test('parses heading-style labels (### LABEL:)', () {
      const raw = '### SIMPLE_MEANING: Deep meaning here.\n'
          '### AUTHOR_CONTEXT: Historical context.\n'
          '### REFLECTION_QUESTION: What matters?\n'
          '### ANALOGY: A river flowing.\n'
          '### TAKEAWAY: Flow with life.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Deep meaning here.');
      expect(result.analogy, 'A river flowing.');
    });

    test('handles multi-line paragraph bodies', () {
      const raw = 'SIMPLE_MEANING: This is a long explanation\n'
          'that spans multiple lines and provides detail.\n'
          'AUTHOR_CONTEXT: The author wrote this\n'
          'during a difficult period.\n'
          'REFLECTION_QUESTION: What困难 do you face?\n'
          'ANALOGY: Like climbing a mountain,\n'
          'the view is worth the effort.\n'
          'TAKEAWAY: Persevere.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, contains('long explanation'));
      expect(result.authorContext, contains('difficult period'));
      expect(result.analogy, contains('climbing a mountain'));
    });

    test('falls back to paragraph ordering when no labels found', () {
      const raw = 'Life is about growth.\n\n'
          'The author wants to inspire readers.\n\n'
          'How do you personally grow?\n\n'
          'Like a seed needs water.\n\n'
          'Keep growing every day.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Life is about growth.');
      expect(result.authorContext, 'The author wants to inspire readers.');
    });

    test('returns null when fewer than 3 sections found', () {
      const raw = 'SIMPLE_MEANING: Only one section.\n';
      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNull);
    });

    test('strips trailing separators', () {
      const raw = 'SIMPLE_MEANING: Clean text.\n'
          '---\n'
          'AUTHOR_CONTEXT: Context here.\n'
          '===\n'
          'REFLECTION_QUESTION: Question here.\n'
          'ANALOGY: Analogy here.\n'
          'TAKEAWAY: Takeaway here.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Clean text.');
      expect(result.authorContext, 'Context here.');
    });

    test('handles case-insensitive labels', () {
      const raw = 'simple_meaning: lowercase works.\n'
          'author_context: Also lowercase.\n'
          'reflection_question: Lowercase too.\n'
          'analogy: Still works.\n'
          'takeaway: Great.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'lowercase works.');
    });

    test('handles partial labels - fills what exists', () {
      const raw = 'SIMPLE_MEANING: Main point.\n'
          'AUTHOR_CONTEXT: Some context.\n'
          'TAKEAWAY: The key lesson.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Main point.');
      expect(result.authorContext, 'Some context.');
      expect(result.reflectionQuestion, isEmpty);
      expect(result.analogy, isEmpty);
      expect(result.takeaway, 'The key lesson.');
    });

    test('handles conversational markdown with bold sections', () {
      const raw = 'Here\'s what I think:\n\n'
          '**SIMPLE_MEANING:** Understanding comes from practice.\n\n'
          '**AUTHOR_CONTEXT:** The sage emphasizes daily discipline.\n\n'
          '**REFLECTION_QUESTION:** What practice do you follow daily?\n\n'
          '**ANALOGY:** Like sharpening a blade — consistent effort yields a keen edge.\n\n'
          '**TAKEAWAY:** Small daily actions compound into mastery.';

      final result = HighlightsController.parseExplanation(raw);
      expect(result, isNotNull);
      expect(result!.simpleMeaning, 'Understanding comes from practice.');
      expect(result.takeaway, 'Small daily actions compound into mastery.');
    });
  });
}
