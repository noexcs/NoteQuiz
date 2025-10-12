import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AIService {
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';
  
  String _baseUrl = _defaultBaseUrl;
  String _apiKey = '';
  String _model = _defaultModel;
  
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? _defaultBaseUrl;
    _apiKey = prefs.getString('api_key') ?? '';
    _model = prefs.getString('api_model') ?? _defaultModel;
  }
  
  Future<Map<String, dynamic>> generateQuestions({
    required String content,
    required String questionType,
    required int count,
  }) async {
    await initialize();
    
    final url = Uri.parse('$_baseUrl/chat/completions');
    
    // 根据中文类型转换为英文标识符
    String typeIdentifier = '';
    switch (questionType) {
      case '选择题':
        typeIdentifier = 'multiple choice';
        break;
      case '填空题':
        typeIdentifier = 'fill in the blank';
        break;
      case '问答题':
        typeIdentifier = 'short answer';
        break;
      default:
        typeIdentifier = 'mixed types';
        break;
    }
    
    final messages = [
      {
        'role': 'system',
        'content': '''
You are a professional education assistant who specializes in generating test questions based on text content. 
Return ONLY valid JSON data in the exact format specified, with no additional text.
Questions should be in Simplified Chinese.
''',
      },
      {
        'role': 'user',
        'content': '''
Based on the following text content, generate $count $questionType questions:

"$content"

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
''',
      },
    ];
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        
        // 尝试解析返回的JSON
        try {
          return jsonDecode(content);
        } catch (e) {
          // 如果解析失败，可能是格式问题，尝试提取其中的JSON部分
          final jsonStart = content.indexOf('{');
          final jsonEnd = content.lastIndexOf('}') + 1;
          if (jsonStart != -1 && jsonEnd > jsonStart) {
            final jsonString = content.substring(jsonStart, jsonEnd);
            return jsonDecode(jsonString);
          }
          rethrow;
        }
      } else {
        throw Exception('API请求失败: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('生成题目时出错: $e');
      }
  }
  
  // 添加根据标题生成内容的方法
  Future<Map<String, dynamic>> generateContentFromTitle(String title) async {
    await initialize();
    
    final url = Uri.parse('$_baseUrl/chat/completions');
    
    final messages = [
      {
        'role': 'system',
        'content': '''
You are a professional note-taking assistant who specializes in creating detailed and well-structured notes based on a title.
Return ONLY valid JSON data in the exact format specified, with no additional text.
Content should be in Markdown format and in Simplified Chinese.
''',
      },
      {
        'role': 'user',
        'content': '''
Based on the title "$title", generate detailed note content.

Requirements for content generation:
1. Create comprehensive and educational content related to the title
2. Use Markdown format for better structure (including headers, lists, code blocks if relevant, etc.)
3. Include multiple sections to organize the content clearly
4. Add specific details, examples, or explanations where appropriate

Return ONLY a valid JSON object in this exact format with no additional text:
{
  "content": "# Title\\n\\nContent in Markdown format..."
}
''',
      },
    ];
    
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'stream': true, // 启用流式输出
        }),
      );
      
      if (response.statusCode == 200) {
        // 流式响应处理
        return _processStreamResponse(response);
      } else {
        throw Exception('API请求失败: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      throw Exception('生成内容时出错: $e');
    }
  }
  
  // 处理流式响应
  Future<Map<String, dynamic>> _processStreamResponse(http.Response response) async {
    final completer = Completer<Map<String, dynamic>>();
    final StringBuffer buffer = StringBuffer();
    
    // 注意：这里只是一个示例实现，实际应该通过流的方式处理响应
    // 但由于http库的限制，我们需要模拟流式处理
    try {
      final content = response.body;
      buffer.write(content);
      
      // 这里简化处理，直接返回最终结果
      // 实际应用中需要逐行解析并发送数据块
      final data = jsonDecode(buffer.toString());
      final messageContent = data['choices'][0]['message']['content'];
      
      // 尝试解析返回的JSON
      try {
        return jsonDecode(messageContent);
      } catch (e) {
        // 如果解析失败，可能是格式问题，尝试提取其中的JSON部分
        final jsonStart = messageContent.indexOf('{');
        final jsonEnd = messageContent.lastIndexOf('}') + 1;
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final jsonString = messageContent.substring(jsonStart, jsonEnd);
          return jsonDecode(jsonString);
        }
        rethrow;
      }
    } catch (e) {
      completer.completeError(e);
    }
    
    return completer.future;
  }
  
  // 真正的流式内容生成功能
  Stream<String> streamContentFromTitle(String title) async* {
    await initialize();
    
    final url = Uri.parse('$_baseUrl/chat/completions');
    
    final messages = [
      {
        'role': 'system',
        'content': '''
You are a professional note-taking assistant who specializes in creating detailed and well-structured notes based on a title.
Content should be in Markdown format and in Simplified Chinese.
''',
      },
      {
        'role': 'user',
        'content': '''
Based on the title "$title", generate detailed note content.

Requirements for content generation:
1. Create comprehensive and educational content related to the title
2. Use Markdown format for better structure (including headers, lists, code blocks if relevant, etc.)
3. Include multiple sections to organize the content clearly
4. Add specific details, examples, or explanations where appropriate
''',
      },
    ];
    
    try {
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        })
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
              if (jsonData == '[DONE]') {
                return;
              }
              
              try {
                final parsed = jsonDecode(jsonData!);
                final content = parsed['choices'][0]['delta']['content'];
                if (content != null) {
                  yield content;
                }
              } catch (e) {
                // 忽略解析错误
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
}