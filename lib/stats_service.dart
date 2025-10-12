import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StatsService {
  static const String _statsKey = 'learning_stats';
  
  late SharedPreferences _prefs;

  // 统计数据模型
  late StatsData _statsData;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadStats();
  }

  Future<void> _loadStats() async {
    final String? statsJson = _prefs.getString(_statsKey);
    if (statsJson != null && statsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(statsJson);
        _statsData = StatsData.fromJson(jsonMap);
        return;
      } catch (e) {
        // 如果解析失败，使用默认数据
      }
    }
    
    // 默认统计数据
    _statsData = StatsData(
      totalStudyTime: 0,
      totalQuestionsAnswered: 0,
      totalCorrectAnswers: 0,
      totalNotes: 0,
      dailyStats: {},
    );
  }

  Future<void> _saveStats() async {
    final String statsJson = json.encode(_statsData.toJson());
    await _prefs.setString(_statsKey, statsJson);
  }

  // 增加学习时间（秒）
  Future<void> addStudyTime(int seconds) async {
    _statsData.totalStudyTime += seconds;
    await _saveStats();
  }

  // 记录答题结果
  Future<void> recordAnswerResult(bool isCorrect) async {
    _statsData.totalQuestionsAnswered++;
    if (isCorrect) {
      _statsData.totalCorrectAnswers++;
    }
    
    // 更新每日统计
    final String today = DateTime.now().toIso8601String().split('T')[0];
    if (_statsData.dailyStats.containsKey(today)) {
      final DailyStats todayStats = _statsData.dailyStats[today]!;
      todayStats.questionsAnswered++;
      if (isCorrect) {
        todayStats.correctAnswers++;
      }
    } else {
      _statsData.dailyStats[today] = DailyStats(
        questionsAnswered: 1,
        correctAnswers: isCorrect ? 1 : 0,
      );
    }
    
    await _saveStats();
  }

  // 更新笔记数量
  Future<void> updateNotesCount(int count) async {
    _statsData.totalNotes = count;
    await _saveStats();
  }

  // 获取统计数据
  StatsData getStats() {
    return _statsData;
  }

  // 重置统计数据
  Future<void> resetStats() async {
    _statsData = StatsData(
      totalStudyTime: 0,
      totalQuestionsAnswered: 0,
      totalCorrectAnswers: 0,
      totalNotes: 0,
      dailyStats: {},
    );
    await _saveStats();
  }
}

class StatsData {
  int totalStudyTime; // 总学习时间（秒）
  int totalQuestionsAnswered; // 总答题数
  int totalCorrectAnswers; // 总正确答题数
  int totalNotes; // 笔记数量
  Map<String, DailyStats> dailyStats; // 每日统计数据

  StatsData({
    required this.totalStudyTime,
    required this.totalQuestionsAnswered,
    required this.totalCorrectAnswers,
    required this.totalNotes,
    required this.dailyStats,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> dailyStatsJson = {};
    dailyStats.forEach((key, value) {
      dailyStatsJson[key] = value.toJson();
    });

    return {
      'totalStudyTime': totalStudyTime,
      'totalQuestionsAnswered': totalQuestionsAnswered,
      'totalCorrectAnswers': totalCorrectAnswers,
      'totalNotes': totalNotes,
      'dailyStats': dailyStatsJson,
    };
  }

  factory StatsData.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> dailyStatsJson = json['dailyStats'] as Map<String, dynamic>;
    final Map<String, DailyStats> dailyStats = {};
    dailyStatsJson.forEach((key, value) {
      dailyStats[key] = DailyStats.fromJson(value as Map<String, dynamic>);
    });

    return StatsData(
      totalStudyTime: json['totalStudyTime'] as int? ?? 0,
      totalQuestionsAnswered: json['totalQuestionsAnswered'] as int? ?? 0,
      totalCorrectAnswers: json['totalCorrectAnswers'] as int? ?? 0,
      totalNotes: json['totalNotes'] as int? ?? 0,
      dailyStats: dailyStats,
    );
  }
}

class DailyStats {
  int questionsAnswered;
  int correctAnswers;

  DailyStats({
    required this.questionsAnswered,
    required this.correctAnswers,
  });

  Map<String, dynamic> toJson() {
    return {
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
    };
  }

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      questionsAnswered: json['questionsAnswered'] as int? ?? 0,
      correctAnswers: json['correctAnswers'] as int? ?? 0,
    );
  }
}