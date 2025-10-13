import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIService {

  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';

  static const String _defaultContentSystemPrompt = '''
You are a professional note-taking assistant who specializes in creating detailed and well-structured notes based on a title.
Content should be in Markdown format and in Simplified Chinese.
''';
  static const String _contentRequirementsPrompt = '''
Requirements for content generation:
1. Create comprehensive and educational content related to the title
2. Use Markdown format for better structure (including headers, lists, code blocks if relevant, etc.)
3. Include multiple sections to organize the content clearly
4. Add specific details, examples, or explanations where appropriate
''';

  static const String _defaultQuestionSystemPrompt = '''
You are a professional education assistant who specializes in generating questions based on text content. 
Return ONLY valid JSON data in the exact format specified, with no additional text.
Questions should be in Simplified Chinese.
''';
  static const String _questionRequirementsPrompt = '''
Requirements for question generation:
1. Multiple Choice: Include question, options list, correct answer index (0-based), and explanation
2. Fill in the Blank: Include question with blank (______), correct answers list, hint, and explanation
3. Short Answer: Include question, acceptable answers list, and explanation

Return ONLY a valid JSON object in this exact format with no additional text:
{
  "questions": [
    {
      "type": "multipleChoice",
      "data": {
        "question": "Question text",
        "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
        "correctAnswerIndex": 0,
        "explanation": "Explanation text"
      }
    },
    {
      "type": "fillInBlank",
      "data": {
        "question": "Question with blank ______",
        "correctAnswers": ["answer1", "answer2"],
        "hint": "Hint text",
        "explanation": "Explanation text"
      }
    },
    {
      "type": "shortAnswer",
      "data": {
        "question": "Question text",
        "acceptableAnswers": ["answer1", "answer2"],
        "explanation": "Explanation text"
      }
    }
  ]
}

''';

  static const String _multipleChoiceSystemPrompt = '''
You are a professional education assistant who specializes in generating multiple choice questions based on text content. 
Return ONLY valid JSON data in the exact format specified, with no additional text.
Questions should be in Simplified Chinese.
''';
  static const String _multipleChoiceRequirementsPrompt = '''
Requirements for question generation:
Include question, options list, correct answer index (0-based), and explanation

Return ONLY a valid JSON object in this exact format with no additional text:
{
  "questions": [
    {
      "type": "multipleChoice",
      "data": {
        "question": "Question text",
        "options": ["Option 1", "Option 2", "Option 3", "Option 4"],
        "correctAnswerIndex": 0,
        "explanation": "Explanation text"
      }
    }
  ]
}
''';

  static const String _fillInBlankSystemPrompt = '''
You are a professional education assistant who specializes in generating fill-in-the-blank questions based on text content. 
Return ONLY valid JSON data in the exact format specified, with no additional text.
Questions should be in Simplified Chinese.
''';
  static const String _fillInBlankRequirementsPrompt = '''
Requirements for question generation:
Include question with blank (______), correct answers list, hint, and explanation

Return ONLY a valid JSON object in this exact format with no additional text:
{
  "questions": [
    {
      "type": "fillInBlank",
      "data": {
        "question": "Question with blank ______",
        "correctAnswers": ["answer1", "answer2"],
        "hint": "Hint text",
        "explanation": "Explanation text"
      }
    }
  ]
}
''';

  static const String _shortAnswerSystemPrompt = '''
You are a professional education assistant who specializes in generating short answer questions based on text content. 
Return ONLY valid JSON data in the exact format specified, with no additional text.
Questions should be in Simplified Chinese.
''';
  static const String _shortAnswerRequirementsPrompt = '''
Requirements for question generation:
Include question, acceptable answers list, and explanation

Return ONLY a valid JSON object in this exact format with no additional text:
{
  "questions": [
    {
      "type": "shortAnswer",
      "data": {
        "question": "Question text",
        "acceptableAnswers": ["answer1", "answer2"],
        "explanation": "Explanation text"
      }
    }
  ]
}
''';

  // --- Configuration ---
  String _baseUrl = _defaultBaseUrl;
  String _apiKey = '';
  String _model = _defaultModel;

  // --- Custom Prompts ---
  String _questionSystemPrompt = _defaultQuestionSystemPrompt;
  String _questionUserPrompt = '';
  String _contentSystemPrompt = _defaultContentSystemPrompt;
  String _contentUserPrompt = '';

  // --- Singleton Setup ---
  static final AIService _instance = AIService._internal();

  factory AIService() => _instance;

  AIService._internal();

  // --- Initialization ---
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? _defaultBaseUrl;
    _apiKey = prefs.getString('api_key') ?? '';
    _model = prefs.getString('api_model') ?? _defaultModel;

    // Load custom prompts, falling back to defaults if empty
    _questionSystemPrompt =
        prefs.getString('question_system_prompt')?.trim().isNotEmpty ?? false
        ? prefs.getString('question_system_prompt')!
        : _defaultQuestionSystemPrompt;
    _questionUserPrompt = prefs.getString('question_user_prompt') ?? '';

    _contentSystemPrompt =
        prefs.getString('content_system_prompt')?.trim().isNotEmpty ?? false
        ? prefs.getString('content_system_prompt')!
        : _defaultContentSystemPrompt;
    _contentUserPrompt = prefs.getString('content_user_prompt') ?? '';
  }

  // --- Public API Methods ---

  Future<Map<String, dynamic>> generateQuestions({
    required String content,
    required String questionType,
    required int count,
  }) async {
    await initialize();
    final url = Uri.parse('$_baseUrl/chat/completions');

    // Select appropriate system prompt based on question type
    String systemPrompt;
    String requirementsPrompt;
    switch (questionType.toLowerCase()) {
      case '选择题':
        systemPrompt = _multipleChoiceSystemPrompt;
        requirementsPrompt = _multipleChoiceRequirementsPrompt;
        break;
      case '填空题':
        systemPrompt = _fillInBlankSystemPrompt;
        requirementsPrompt = _fillInBlankRequirementsPrompt;
        break;
      case '问答题':
        systemPrompt = _shortAnswerSystemPrompt;
        requirementsPrompt = _shortAnswerRequirementsPrompt;
        break;
      default:
        systemPrompt = _questionSystemPrompt;
        requirementsPrompt = _questionRequirementsPrompt;
    }

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'user',
        'content':
            '''
Based on the following text content, generate $count $questionType questions:

$content


$requirementsPrompt


$_questionUserPrompt
''',
      },
    ];

    try {
      final response = await http.post(
        url,
        headers: _buildHeaders(),
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'response_format': {'type': 'json_object'},
        }),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('生成题目时出错: $e');
    }
  }

  Stream<String> streamContentFromTitle(String title) async* {
    await initialize();
    final url = Uri.parse('$_baseUrl/chat/completions');
    final messages = [
      // Use a dedicated system prompt for streaming that does NOT ask for JSON.
      {'role': 'system', 'content': _contentSystemPrompt},
      {
        'role': 'user',
        'content':
            '''
Based on the title "$title", generate detailed note content.

$_contentRequirementsPrompt

$_contentUserPrompt
''',
      },
    ];

    try {
      final request = http.Request('POST', url)
        ..headers.addAll(_buildHeaders())
        ..body = jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'stream': true,
        });
      final response = await request.send();

      if (response.statusCode == 200) {
        final stream = response.stream.transform(utf8.decoder);
        final RegExp dataRegExp = RegExp(r'data: (.*)');
        await for (final data in stream) {
          final lines = data.split('\n');
          for (final line in lines) {
            final match = dataRegExp.firstMatch(line);
            if (match != null) {
              final jsonData = match.group(1);
              if (jsonData == '[DONE]') return;
              try {
                final parsed = jsonDecode(jsonData!);
                final content = parsed['choices'][0]['delta']['content'];
                if (content != null) yield content;
              } catch (e) {
                // Ignore parsing errors for incomplete JSON chunks
              }
            }
          }
        }
      } else {
        throw Exception('API请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('流式生成内容时出错: $e');
    }
  }

  // --- Private Helper Methods ---

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
  }

  Map<String, dynamic> _processResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'];

      // Handle empty or null content
      if (content == null || content.isEmpty) {
        return {'questions': []}; // Return empty list instead of null
      }

      String jsonString = content;

      final codeBlockMatch = RegExp(
        r'```(json)?\s*(\{[\s\S]*\})\s*```',
      ).firstMatch(content);
      if (codeBlockMatch != null) {
        jsonString = codeBlockMatch.group(2)!;
      } else {
        final jsonStart = content.indexOf('{');
        final jsonEnd = content.lastIndexOf('}') + 1;
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          jsonString = content.substring(jsonStart, jsonEnd);
        }
      }

      try {
        return jsonDecode(jsonString);
      } catch (e) {
        throw Exception(
          'Failed to parse JSON from AI response. Content: "$content"',
        );
      }
    } else {
      throw Exception('API请求失败: ${response.statusCode}, ${response.body}');
    }
  }
}
