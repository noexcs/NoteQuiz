import 'dart:async';
import 'package:flutter/material.dart';

import 'ai/ai_question.dart';
import 'note.dart';
import 'note_service.dart';
import 'srs_service.dart';
import 'stats_service.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final NoteService _noteService = NoteService();
  final StatsService _statsService = StatsService();
  final SRSService _srsService = SRSService();
  List<Note> _notes = [];
  List<AIQuestion> _allQuestions = [];
  List<int> _questionToNoteIndex = [];
  int _currentQuestionIndex = 0;
  bool _showAnswer = false;

  DateTime? _startTime;
  Timer? _studyTimer;
  int _studySeconds = 0;

  List<bool?> _userAnswers = [];
  List<int?> _selectedOptions = [];

  @override
  void initState() {
    super.initState();
    _loadNotesAndQuestions();
    _startStudyTimer();
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotesAndQuestions() async {
    await _noteService.init();
    await _statsService.init();
    final notes = await _noteService.loadNotes();
    final allQuestions = _extractAllQuestions(notes);
    setState(() {
      _notes = notes;
      _allQuestions = allQuestions;
      _currentQuestionIndex = 0;
      _showAnswer = false;
      _userAnswers = List.filled(allQuestions.length, null);
      _selectedOptions = List.filled(allQuestions.length, null);
    });
  }

  List<AIQuestion> _extractAllQuestions(List<Note> notes) {
    List<Map<String, dynamic>> indexedQuestions = [];
    for (int noteIndex = 0; noteIndex < notes.length; noteIndex++) {
      for (var question in notes[noteIndex].questions) {
        indexedQuestions.add({'question': question, 'noteIndex': noteIndex});
      }
    }
    indexedQuestions.shuffle();

    List<AIQuestion> questions = [];
    _questionToNoteIndex.clear();
    for (var item in indexedQuestions) {
      questions.add(item['question']);
      _questionToNoteIndex.add(item['noteIndex']);
    }
    return questions;
  }

  void _startStudyTimer() {
    _startTime = DateTime.now();
    _studyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _studySeconds = DateTime.now().difference(_startTime!).inSeconds;
        });
      }
    });
  }

  Future<void> _stopStudyTimer() async {
    _studyTimer?.cancel();
    if (_startTime != null) {
      final studyDuration = DateTime.now().difference(_startTime!).inSeconds;
      await _statsService.addStudyTime(studyDuration);
    }
  }

  void _toggleAnswer() {
    setState(() {
      _showAnswer = !_showAnswer;
    });
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
        _showAnswer = _userAnswers[_currentQuestionIndex] != null;
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _allQuestions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _showAnswer = false;
      });
    }
  }

  void _handleMultipleChoiceAnswer(int selectedIndex) {
    final currentQuestion = _allQuestions[_currentQuestionIndex];
    if (currentQuestion.type == QuestionType.multipleChoice) {
      final q = currentQuestion.questionData as MultipleChoiceQuestion;
      final isCorrect = (selectedIndex == q.correctAnswerIndex);
      setState(() {
        _selectedOptions[_currentQuestionIndex] = selectedIndex;
        _userAnswers[_currentQuestionIndex] = isCorrect;
        _statsService.recordAnswerResult(isCorrect);
        _showAnswer = true;
      });
    }
  }

  void _handleUserJudgment(bool isCorrect) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = isCorrect;
      _statsService.recordAnswerResult(isCorrect);
      _showAnswer = true;
    });
  }

  Future<void> _handleSRSScore(int quality) async {
    int noteIndex = _questionToNoteIndex[_currentQuestionIndex];
    Note currentNote = _notes[noteIndex];
    Note updatedNote = _srsService.updateNoteSRS(currentNote, quality);
    _notes[noteIndex] = updatedNote;
    await _noteService.saveNotes(_notes);

    if (_currentQuestionIndex < _allQuestions.length - 1) {
      _nextQuestion();
    } else {
      _showQuizResults();
    }
  }

  void _showQuizResults() async {
    await _stopStudyTimer();

    int correctCount = _userAnswers.where((answer) => answer == true).length;
    double accuracy =
        _allQuestions.isEmpty ? 0 : correctCount / _allQuestions.length;

    List<Map<String, dynamic>> wrongMultipleChoiceQuestions = [];
    for (int i = 0; i < _allQuestions.length; i++) {
      if (_allQuestions[i].type == QuestionType.multipleChoice &&
          _userAnswers[i] != true) {
        final q = _allQuestions[i].questionData as MultipleChoiceQuestion;
        wrongMultipleChoiceQuestions.add({
          'question': q.question,
          'options': q.options,
          'correctAnswerIndex': q.correctAnswerIndex,
          'userSelectedIndex': _selectedOptions[i],
          'explanation': q.explanation,
        });
      }
    }

    List<Map<String, dynamic>> wrongNonMultipleChoiceQuestions = [];
    for (int i = 0; i < _allQuestions.length; i++) {
      if (_allQuestions[i].type != QuestionType.multipleChoice &&
          _userAnswers[i] != true) {
        final question = _allQuestions[i];
        dynamic questionData = question.questionData;
        wrongNonMultipleChoiceQuestions.add({
          'type': question.type,
          'question': questionData.question,
          'correctAnswers': question.type == QuestionType.fillInBlank
              ? (questionData as FillInBlankQuestion).correctAnswers
              : (questionData as ShortAnswerQuestion).acceptableAnswers,
          'explanation': questionData.explanation,
        });
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _QuizResultsDialog(
          accuracy: accuracy,
          correctCount: correctCount,
          totalQuestions: _allQuestions.length,
          studySeconds: _studySeconds,
          wrongMultipleChoiceQuestions: wrongMultipleChoiceQuestions,
          wrongNonMultipleChoiceQuestions: wrongNonMultipleChoiceQuestions,
          onRestart: () {
            Navigator.of(context).pop();
            setState(() {
              _loadNotesAndQuestions();
              _startStudyTimer();
            });
          },
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _allQuestions.isEmpty
        ? 0.0
        : (_currentQuestionIndex + 1) / _allQuestions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        actions: [
          if (_allQuestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _showQuizResults,
                child: const Text('完成'),
              ),
            )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colorScheme.surfaceVariant.withOpacity(0.2),
          ),
        ),
      ),
      body: _allQuestions.isEmpty
          ? _buildEmptyState(colorScheme)
          : _buildQuizBody(),
      bottomNavigationBar:
          _allQuestions.isEmpty ? null : _buildBottomAppBar(colorScheme),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.quiz_outlined,
            size: 80,
            color: colorScheme.primary.withOpacity(0.6),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无题目，请先添加笔记并生成题目',
            style: TextStyle(fontSize: 18),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: Column(
          key: ValueKey<int>(_currentQuestionIndex),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuestionWidget(_allQuestions[_currentQuestionIndex]),
            if (_showAnswer) ...[
              const SizedBox(height: 20),
              if (_allQuestions[_currentQuestionIndex].type !=
                  QuestionType.multipleChoice)
                _buildAnswerWidget(_allQuestions[_currentQuestionIndex]),
              const SizedBox(height: 20),
              if (_userAnswers[_currentQuestionIndex] != null)
                _buildSRSRatingWidget(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAppBar(ColorScheme colorScheme) {
    final question = _allQuestions[_currentQuestionIndex];
    final isMcq = question.type == QuestionType.multipleChoice;
    final hasAnswered = _userAnswers[_currentQuestionIndex] != null;

    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: '上一题',
              onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
            ),
            if (!isMcq && !_showAnswer)
              FilledButton.tonal(
                onPressed: _toggleAnswer,
                child: const Text('显示答案'),
              ),
            if (!isMcq && _showAnswer && !hasAnswered)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _handleUserJudgment(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('答错了'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _handleUserJudgment(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('答对了'),
                  ),
                ],
              ),
            Text(
              '${_currentQuestionIndex + 1}/${_allQuestions.length}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionWidget(AIQuestion question) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (question.type) {
      case QuestionType.multipleChoice:
        final q = question.questionData as MultipleChoiceQuestion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withOpacity(0.7),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(q.question,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w500)),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(q.options.length, (index) {
              final selectedIndex = _selectedOptions[_currentQuestionIndex];
              final hasAnswered = selectedIndex != null;
              final isCorrectAnswer = index == q.correctAnswerIndex;
              final isSelectedAnswer = selectedIndex == index;

              Color? tileColor;
              Widget? trailingIcon;
              BorderSide borderSide =
                  BorderSide(color: colorScheme.outline.withOpacity(0.3));

              if (hasAnswered) {
                if (isCorrectAnswer) {
                  tileColor = Colors.green.withOpacity(0.1);
                  trailingIcon =
                      const Icon(Icons.check_circle, color: Colors.green);
                  if (isSelectedAnswer) {
                    borderSide =
                        const BorderSide(color: Colors.green, width: 1.5);
                  }
                } else if (isSelectedAnswer) {
                  tileColor = Colors.red.withOpacity(0.1);
                  trailingIcon = const Icon(Icons.cancel, color: Colors.red);
                  borderSide = const BorderSide(color: Colors.red, width: 1.5);
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                color: tileColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: borderSide,
                ),
                child: ListTile(
                  title: Text(q.options[index],
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isSelectedAnswer
                        ? colorScheme.primary
                        : colorScheme.secondaryContainer,
                    foregroundColor: isSelectedAnswer
                        ? colorScheme.onPrimary
                        : colorScheme.onSecondaryContainer,
                    child: Text(String.fromCharCode(65 + index)),
                  ),
                  trailing: trailingIcon,
                  onTap: hasAnswered
                      ? null
                      : () => _handleMultipleChoiceAnswer(index),
                ),
              );
            }),
          ],
        );
      default:
        dynamic q = question.questionData;
        return Card(
          elevation: 0,
          color: colorScheme.primaryContainer.withOpacity(0.7),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w500)),
                if (question.type == QuestionType.fillInBlank &&
                    (q as FillInBlankQuestion).hint != null) ...[
                  const SizedBox(height: 10),
                  Text('提示: ${q.hint}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurfaceVariant,
                      )),
                ],
              ],
            ),
          ),
        );
    }
  }

  Widget _buildAnswerWidget(AIQuestion question) {
    final colorScheme = Theme.of(context).colorScheme;
    dynamic q = question.questionData;
    List<String> answers = [];
    if (question.type == QuestionType.fillInBlank) {
      answers = (q as FillInBlankQuestion).correctAnswers;
    } else if (question.type == QuestionType.shortAnswer) {
      answers = (q as ShortAnswerQuestion).acceptableAnswers;
    }

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('参考答案:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            ...answers.map((answer) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text("• $answer",
                      style: const TextStyle(fontSize: 16)),
                )),
            if (q.explanation != null && q.explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('解析: ${q.explanation}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSRSRatingWidget() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('记忆如何？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSRSRatingButton('忘记', 0, Colors.red),
                _buildSRSRatingButton('困难', 1, Colors.orange),
                _buildSRSRatingButton('良好', 2, Colors.blue),
                _buildSRSRatingButton('简单', 3, Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSRSRatingButton(String text, int quality, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FilledButton.tonal(
          onPressed: () => _handleSRSScore(quality),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: color.withOpacity(0.15),
            foregroundColor: color,
          ),
          child: Text(text, style: const TextStyle(fontSize: 14)),
        ),
      ),
    );
  }
}

class _QuizResultsDialog extends StatelessWidget {
  final double accuracy;
  final int correctCount;
  final int totalQuestions;
  final int studySeconds;
  final List<Map<String, dynamic>> wrongMultipleChoiceQuestions;
  final List<Map<String, dynamic>> wrongNonMultipleChoiceQuestions;
  final VoidCallback onRestart;
  final VoidCallback onClose;

  const _QuizResultsDialog({
    required this.accuracy,
    required this.correctCount,
    required this.totalQuestions,
    required this.studySeconds,
    required this.wrongMultipleChoiceQuestions,
    required this.wrongNonMultipleChoiceQuestions,
    required this.onRestart,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    String formatDuration(int totalSeconds) {
      final duration = Duration(seconds: totalSeconds);
      final minutes = duration.inMinutes;
      final seconds = totalSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return AlertDialog(
      title: const Text('测验结果'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('正确率',
                    '${(accuracy * 100).toStringAsFixed(0)}%', colorScheme.primary),
                _buildStatCard('正确数', '$correctCount/$totalQuestions',
                    Colors.green),
                _buildStatCard('用时', formatDuration(studySeconds), Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            if (wrongMultipleChoiceQuestions.isEmpty &&
                wrongNonMultipleChoiceQuestions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text('🎉 恭喜你，全部回答正确！',
                      style: textTheme.titleMedium?.copyWith(color: Colors.green)),
                ),
              )
            else
              _buildWrongAnswersList(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onRestart,
          child: const Text('重新开始'),
        ),
        FilledButton(
          onPressed: onClose,
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Column(
      children: [
        Text(title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildWrongAnswersList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wrongMultipleChoiceQuestions.isNotEmpty)
          ExpansionTile(
            title: Text('答错的选择题 (${wrongMultipleChoiceQuestions.length})'),
            initiallyExpanded: true,
            children: wrongMultipleChoiceQuestions.map((q) {
              return _buildWrongAnswerCard(
                context,
                question: q['question'],
                userAnswer: q['userSelectedIndex'] != null
                    ? '你的答案: ${q['options'][q['userSelectedIndex']]}'
                    : '你的答案: 未作答',
                correctAnswer:
                    '正确答案: ${q['options'][q['correctAnswerIndex']]}',
                explanation: q['explanation'],
              );
            }).toList(),
          ),
        if (wrongNonMultipleChoiceQuestions.isNotEmpty)
          ExpansionTile(
            title: Text('答错的非选择题 (${wrongNonMultipleChoiceQuestions.length})'),
            initiallyExpanded: true,
            children: wrongNonMultipleChoiceQuestions.map((q) {
              return _buildWrongAnswerCard(
                context,
                question: q['question'],
                userAnswer: '你的判断: 错误',
                correctAnswer: '参考答案: ${(q['correctAnswers'] as List).join(', ')}',
                explanation: q['explanation'],
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildWrongAnswerCard(
    BuildContext context, {
    required String question,
    required String userAnswer,
    required String correctAnswer,
    String? explanation,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(userAnswer, style: TextStyle(color: Colors.red.shade700)),
            Text(correctAnswer, style: TextStyle(color: Colors.green.shade800)),
            if (explanation != null && explanation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('解析: $explanation', style: textTheme.bodySmall),
            ]
          ],
        ),
      ),
    );
  }
}
