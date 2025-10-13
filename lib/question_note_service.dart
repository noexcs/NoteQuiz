import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// 题目笔记服务，用于管理与特定题目关联的笔记
class QuestionNoteService {
  static const String _questionNotesKey = 'question_notes';
  
  late SharedPreferences _prefs;

  /// 初始化服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// 获取指定题目的笔记内容
  /// [questionId] 题目的唯一标识符
  Future<String?> getQuestionNote(String questionId) async {
    final Map<String, String> notesMap = await _getAllQuestionNotes();
    return notesMap[questionId];
  }

  /// 保存指定题目的笔记内容
  /// [questionId] 题目的唯一标识符
  /// [note] 笔记内容
  Future<void> saveQuestionNote(String questionId, String note) async {
    final Map<String, String> notesMap = await _getAllQuestionNotes();
    notesMap[questionId] = note;
    await _saveAllQuestionNotes(notesMap);
  }

  /// 删除指定题目的笔记
  /// [questionId] 题目的唯一标识符
  Future<void> deleteQuestionNote(String questionId) async {
    final Map<String, String> notesMap = await _getAllQuestionNotes();
    notesMap.remove(questionId);
    await _saveAllQuestionNotes(notesMap);
  }

  /// 获取所有题目笔记
  Future<Map<String, String>> _getAllQuestionNotes() async {
    final String? notesJson = _prefs.getString(_questionNotesKey);
    if (notesJson == null || notesJson.isEmpty) {
      return {};
    }
    
    try {
      final Map<String, dynamic> jsonMap = json.decode(notesJson);
      return jsonMap.map((key, value) => MapEntry(key, value as String));
    } catch (e) {
      // 如果解析失败，返回空映射
      return {};
    }
  }

  /// 保存所有题目笔记
  Future<void> _saveAllQuestionNotes(Map<String, String> notesMap) async {
    final String notesJson = json.encode(notesMap);
    await _prefs.setString(_questionNotesKey, notesJson);
  }
}