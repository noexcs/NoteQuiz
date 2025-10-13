import 'dart:convert';
import 'dart:math';

class MultipleChoiceQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;

  MultipleChoiceQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
    };
  }

  factory MultipleChoiceQuestion.fromJson(Map<String, dynamic> json) {
    return MultipleChoiceQuestion(
      question: json['question'] as String,
      options: List<String>.from(json['options'] as List),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      explanation: json['explanation'] as String?,
    );
  }
}

class FillInBlankQuestion {
  final String question;
  final List<String> correctAnswers;
  final String? hint;
  final String? explanation;

  FillInBlankQuestion({
    required this.question,
    required this.correctAnswers,
    this.hint,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'correctAnswers': correctAnswers,
      'hint': hint,
      'explanation': explanation,
    };
  }

  factory FillInBlankQuestion.fromJson(Map<String, dynamic> json) {
    return FillInBlankQuestion(
      question: json['question'] as String,
      correctAnswers: List<String>.from(json['correctAnswers'] as List),
      hint: json['hint'] as String?,
      explanation: json['explanation'] as String?,
    );
  }
}

class ShortAnswerQuestion {
  final String question;
  final List<String> acceptableAnswers;
  final String? explanation;

  ShortAnswerQuestion({
    required this.question,
    required this.acceptableAnswers,
    this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'acceptableAnswers': acceptableAnswers,
      'explanation': explanation,
    };
  }

  factory ShortAnswerQuestion.fromJson(Map<String, dynamic> json) {
    return ShortAnswerQuestion(
      question: json['question'] as String,
      acceptableAnswers: List<String>.from(json['acceptableAnswers'] as List),
      explanation: json['explanation'] as String?,
    );
  }
}

enum QuestionType { multipleChoice, fillInBlank, shortAnswer }

class AIQuestion {
  final String id;
  final QuestionType type;
  final dynamic questionData;

  AIQuestion({
    String? id,
    required this.type,
    required this.questionData,
  }) : id = id ?? _generateId();

  static String _generateId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = random.nextInt(1000000);
    return '$timestamp-$randomSuffix';
  }

  Map<String, dynamic> toJson() {
    late Map<String, dynamic> data;
    switch (type) {
      case QuestionType.multipleChoice:
        data = (questionData as MultipleChoiceQuestion).toJson();
        break;
      case QuestionType.fillInBlank:
        data = (questionData as FillInBlankQuestion).toJson();
        break;
      case QuestionType.shortAnswer:
        data = (questionData as ShortAnswerQuestion).toJson();
        break;
    }

    return {
      'id': id,
      'type': type.index,
      'questionData': data,
    };
  }

  factory AIQuestion.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final typeIndex = json['type'] as int;
    final type = QuestionType.values[typeIndex];
    final questionDataJson = json['questionData'] as Map<String, dynamic>;

    late dynamic questionData;
    switch (type) {
      case QuestionType.multipleChoice:
        questionData = MultipleChoiceQuestion.fromJson(questionDataJson);
        break;
      case QuestionType.fillInBlank:
        questionData = FillInBlankQuestion.fromJson(questionDataJson);
        break;
      case QuestionType.shortAnswer:
        questionData = ShortAnswerQuestion.fromJson(questionDataJson);
        break;
    }

    return AIQuestion(
      id: id,
      type: type,
      questionData: questionData,
    );
  }
}