import 'dart:convert';
import 'ai/ai_question.dart';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AIQuestion> questions;
  final String? directory; // 添加目录属性
  
  // SRS相关字段
  final DateTime? nextReviewDate;
  final double interval;
  final double difficultyFactor;
  final int reviewCount;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.directory, // 添加目录参数
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AIQuestion>? questions,
    this.nextReviewDate,
    this.interval = 0.0,
    this.difficultyFactor = 0.3, // 默认难度因子
    this.reviewCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        questions = questions ?? [];

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? directory, // 添加目录参数
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AIQuestion>? questions,
    DateTime? nextReviewDate,
    double? interval,
    double? difficultyFactor,
    int? reviewCount,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      directory: directory ?? this.directory, // 添加目录参数
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      questions: questions ?? this.questions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      interval: interval ?? this.interval,
      difficultyFactor: difficultyFactor ?? this.difficultyFactor,
      reviewCount: reviewCount ?? this.reviewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'directory': directory, // 添加目录到JSON
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
      // SRS相关字段
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'interval': interval,
      'difficultyFactor': difficultyFactor,
      'reviewCount': reviewCount,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    List<AIQuestion> questions = [];
    if (json['questions'] != null) {
      final List<dynamic> questionsJson = json['questions'];
      questions = questionsJson.map((q) => AIQuestion.fromJson(q as Map<String, dynamic>)).toList();
    }

    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      directory: json['directory'] as String?, // 从JSON读取目录
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      questions: questions,
      // SRS相关字段
      nextReviewDate: json['nextReviewDate'] != null 
          ? DateTime.parse(json['nextReviewDate'] as String) 
          : null,
      interval: (json['interval'] as num?)?.toDouble() ?? 0.0,
      difficultyFactor: (json['difficultyFactor'] as num?)?.toDouble() ?? 0.3,
      reviewCount: json['reviewCount'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        other.directory == directory && // 添加目录比较
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.questions == questions &&
        other.nextReviewDate == nextReviewDate &&
        other.interval == interval &&
        other.difficultyFactor == difficultyFactor &&
        other.reviewCount == reviewCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        content.hashCode ^
        directory.hashCode ^ // 添加目录hashCode
        createdAt.hashCode ^
        updatedAt.hashCode ^
        questions.hashCode ^
        nextReviewDate.hashCode ^
        interval.hashCode ^
        difficultyFactor.hashCode ^
        reviewCount.hashCode;
  }
}

class NoteList {
  static List<Note> fromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    final List<dynamic> jsonData = json.decode(jsonString);
    return jsonData.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String toJson(List<Note> notes) {
    final List<Map<String, dynamic>> jsonData = notes.map((e) => e.toJson()).toList();
    return json.encode(jsonData);
  }
}