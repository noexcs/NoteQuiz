import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai/ai_question.dart';
import 'note.dart';
import 'note_service.dart';
import 'srs_service.dart';
import 'stats_service.dart';
import 'question_note_service.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final NoteService _noteService = NoteService();
  final StatsService _statsService = StatsService();
  final SRSService _srsService = SRSService();
  final QuestionNoteService _questionNoteService = QuestionNoteService();
  List<Note> _notes = [];
  List<Note> _selectedNotes = [];
  List<AIQuestion> _allQuestions = [];
  List<int> _questionToNoteIndex = [];
  int _currentQuestionIndex = 0;
  int _slideDirection = 1;
  bool _showAnswer = false;
  bool _showNoteEditor = false;
  String _currentQuestionNote = '';
  bool _isEditingNote = false;
  bool _showNoteSelection = true; // 控制是否显示笔记选择界面
  TextEditingController _noteController = TextEditingController();

  DateTime? _startTime;
  Timer? _studyTimer;
  int _studySeconds = 0;

  List<bool?> _userAnswers = [];
  List<int?> _selectedOptions = [];

  @override
  void initState() {
    super.initState();
    _loadNotesAndQuestions();
    //_startStudyTimer(); // 在选择笔记之前不启动计时器
  }

  @override
  void dispose() {
    _studyTimer?.cancel();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesAndQuestions() async {
    await _noteService.init();
    await _statsService.init();
    await _questionNoteService.init();
    final notes = await _noteService.loadNotes();
    
    // 加载上次保存的笔记选择
    final selectedNoteIds = await _loadSelectedNoteIds();
    List<Note> selectedNotes = [];
    if (selectedNoteIds.isEmpty) {
      // 如果没有保存的选择，则默认选择所有笔记
      selectedNotes = List.from(notes);
      // 如果有笔记，默认显示选择界面
      if (notes.isNotEmpty) {
        setState(() {
          _showNoteSelection = true;
        });
      }
    } else {
      // 根据保存的ID选择笔记
      selectedNotes = notes.where((note) => selectedNoteIds.contains(note.id)).toList();
    }
    
    setState(() {
      _notes = notes;
      _selectedNotes = selectedNotes;
      // 只有在不显示选择界面时才提取问题
      if (!_showNoteSelection) {
        final allQuestions = _extractAllQuestions(selectedNotes);
        _allQuestions = allQuestions;
        _currentQuestionIndex = 0;
        _showAnswer = false;
        _userAnswers = List.filled(allQuestions.length, null);
        _selectedOptions = List.filled(allQuestions.length, null);
      }
      _showNoteEditor = false;
      _isEditingNote = false;
    });
  }

  // 加载上次保存的笔记选择
  Future<List<String>> _loadSelectedNoteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedIds = prefs.getStringList('selected_note_ids') ?? [];
    return selectedIds;
  }

  // 保存笔记选择
  Future<void> _saveSelectedNoteIds(List<String> noteIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_note_ids', noteIds);
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
      _showNoteEditor = _showAnswer; // 显示答案时显示笔记编辑器
      // 重置当前显示的笔记内容
      if (_showAnswer) {
        _currentQuestionNote = '';
      }
    });
    
    // 显示答案时加载当前题目的笔记
    if (_showAnswer) {
      _loadCurrentQuestionNote();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _slideDirection = -1;
        _currentQuestionIndex--;
        _showAnswer = _userAnswers[_currentQuestionIndex] != null;
        _showNoteEditor = false; // 切换题目时隐藏笔记编辑器
        _isEditingNote = false; // 重置编辑状态
        // 立即重置当前显示的笔记内容，避免显示前一道题的笔记
        _currentQuestionNote = '';
      });
      
      // 如果已显示答案，则加载当前题目的笔记
      if (_showAnswer) {
        _loadCurrentQuestionNote();
      }
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _allQuestions.length - 1) {
      setState(() {
        _slideDirection = 1;
        _currentQuestionIndex++;
        // Restore the answer visibility if the user has already answered this question.
        _showAnswer = _userAnswers[_currentQuestionIndex] != null;
        _showNoteEditor = false; // 切换题目时隐藏笔记编辑器
        _isEditingNote = false; // 重置编辑状态
        // 立即重置当前显示的笔记内容，避免显示前一道题的笔记
        _currentQuestionNote = '';
      });
      
      // 如果已显示答案，则加载当前题目的笔记
      if (_showAnswer) {
        _loadCurrentQuestionNote();
      }
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
      
      // 加载当前题目的笔记
      _loadCurrentQuestionNote();
    }
  }

  void _handleUserJudgment(bool isCorrect) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = isCorrect;
      _statsService.recordAnswerResult(isCorrect);
      _showAnswer = true;
      _showNoteEditor = true; // 显示笔记编辑器
      // 重置当前显示的笔记内容
      _currentQuestionNote = '';
    });
    
    // 加载当前题目的笔记
    _loadCurrentQuestionNote();
  }

  Future<void> _handleSRSScore(int quality) async {
    int noteIndex = _questionToNoteIndex[_currentQuestionIndex];
    Note currentNote = _selectedNotes[noteIndex];
    Note updatedNote = _srsService.updateNoteSRS(currentNote, quality);
    _selectedNotes[noteIndex] = updatedNote;
    
    // 更新完整笔记列表中的对应笔记
    final originalNoteIndex = _notes.indexWhere((note) => note.id == updatedNote.id);
    if (originalNoteIndex != -1) {
      _notes[originalNoteIndex] = updatedNote;
    }
    
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

    // 重置笔记编辑状态
    setState(() {
      _showNoteEditor = false;
      _isEditingNote = false;
    });

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
              // 重新加载笔记和问题
              _loadNotesAndQuestions();
              //_startStudyTimer(); // 在_startStudy中启动
            });
          },
          onClose: () {
            Navigator.of(context).pop();
            // 返回笔记选择界面
            setState(() {
              _showNoteSelection = true;
              _allQuestions = [];
              _currentQuestionIndex = 0;
            });
          },
        );
      },
    );
  }

  // 开始学习，隐藏笔记选择界面
  void _startStudy() {
    setState(() {
      _showNoteSelection = false;
    });
    final allQuestions = _extractAllQuestions(_selectedNotes);
    setState(() {
      _allQuestions = allQuestions;
      _currentQuestionIndex = 0;
      _showAnswer = false;
      _userAnswers = List.filled(allQuestions.length, null);
      _selectedOptions = List.filled(allQuestions.length, null);
    });
    _startStudyTimer(); // 在开始学习时启动计时器
  }

  // 更新笔记选择
  void _updateNoteSelection(Note note, bool isSelected) {
    setState(() {
      if (isSelected) {
        if (!_selectedNotes.contains(note)) {
          _selectedNotes.add(note);
        }
      } else {
        _selectedNotes.removeWhere((n) => n.id == note.id);
      }
    });
  }

  // 保存并应用笔记选择
  void _saveAndApplyNoteSelection() async {
    final selectedNoteIds = _selectedNotes.map((note) => note.id).toList();
    await _saveSelectedNoteIds(selectedNoteIds);
    _startStudy();
  }

  // 全选所有笔记
  void _selectAllNotes() {
    setState(() {
      _selectedNotes = List.from(_notes);
    });
  }

  // 取消全选
  void _deselectAllNotes() {
    setState(() {
      _selectedNotes.clear();
    });
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
          if (_allQuestions.isNotEmpty && !_showNoteSelection)
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
      body: _showNoteSelection 
          ? _buildNoteSelectionBody() 
          : _allQuestions.isEmpty
              ? _buildEmptyState(colorScheme)
              : _buildQuizBody(),
      bottomNavigationBar: _showNoteSelection 
          ? null 
          : (_allQuestions.isEmpty ? null : _buildBottomAppBar(colorScheme)),
    );
  }

  Widget _buildNoteSelectionBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择要学习的笔记',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '已选择 ${_selectedNotes.length}/${_notes.length} 个笔记',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton(
                    onPressed: _selectAllNotes,
                    child: const Text('全选'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _deselectAllNotes,
                    child: const Text('清空'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saveAndApplyNoteSelection,
                    child: const Text('开始学习'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: _notes.isEmpty
              ? const Center(
                  child: Text('暂无笔记，请先添加笔记'),
                )
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    final isSelected = _selectedNotes.any((n) => n.id == note.id);
                    return CheckboxListTile(
                      title: Text(note.title),
                      value: isSelected,
                      onChanged: (bool? value) {
                        _updateNoteSelection(note, value ?? false);
                      },
                    );
                  },
                ),
        ),
      ],
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
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              setState(() {
                _showNoteSelection = true;
              });
            },
            child: const Text('选择笔记'),
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
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          // The animation logic was correct, the issue was layout.
          // The exiting child's animation is the reverse of the entering child's.
          // Let's use the original logic which was verified to be correct.
          final isEntering = (child.key as ValueKey<int>).value == _currentQuestionIndex;
          final offset = isEntering
              ? Tween<Offset>(begin: Offset(_slideDirection.toDouble(), 0), end: Offset.zero)
              : Tween<Offset>(begin: Offset(-_slideDirection.toDouble(), 0), end: Offset.zero);

          return SlideTransition(
            position: offset.animate(animation),
            child: child,
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
              const SizedBox(height: 20),
              _buildQuestionNoteWidget(), // 添加题目笔记组件
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

    Widget centerWidget;
    if (!isMcq && !_showAnswer) {
      centerWidget = FilledButton.tonal(
        onPressed: _toggleAnswer,
        child: const Text('显示答案'),
      );
    } else if (!isMcq && _showAnswer && !hasAnswered) {
      centerWidget = Row(
        mainAxisSize: MainAxisSize.min,
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
      );
    } else {
      // For MCQs or answered non-MCQs, just show the progress indicator.
      centerWidget = Text(
        '${_currentQuestionIndex + 1}/${_allQuestions.length}',
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      );
    }

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
            centerWidget,
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: '下一题',
              onPressed: (_currentQuestionIndex < _allQuestions.length - 1 &&
                      _userAnswers[_currentQuestionIndex] != null)
                  ? _nextQuestion
                  : null,
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

  /// 构建题目笔记组件
  Widget _buildQuestionNoteWidget() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('题目笔记',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                // 始终显示编辑按钮，用于创建或编辑笔记
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _startEditingNote,
                  tooltip: _currentQuestionNote.isEmpty ? '添加笔记' : '编辑笔记',
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_isEditingNote)
              _buildNoteEditor()
            else
              _buildNoteViewer(),
          ],
        ),
      ),
    );
  }

  /// 构建笔记查看器
  Widget _buildNoteViewer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentQuestionNote.isEmpty) ...[
          const Center(
            child: Text('暂无笔记'),
          ),
        ] else ...[
          Text(_currentQuestionNote),
        ],
      ],
    );
  }

  /// 构建笔记编辑器
  Widget _buildNoteEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _noteController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: '请输入笔记内容...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _cancelEditingNote,
              child: const Text('取消'),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _saveCurrentQuestionNote,
              child: const Text('保存'),
            ),
          ],
        ),
      ],
    );
  }

  /// 获取当前问题的唯一标识符
  String _getCurrentQuestionId() {
    final currentQuestion = _allQuestions[_currentQuestionIndex];
    // 使用问题的唯一ID作为标识符
    return currentQuestion.id;
  }

  /// 加载当前题目的笔记
  Future<void> _loadCurrentQuestionNote() async {
    final questionId = _getCurrentQuestionId();
    try {
      final note = await _questionNoteService.getQuestionNote(questionId);
      if (mounted) {
        setState(() {
          _currentQuestionNote = note ?? '';
          _noteController.text = _currentQuestionNote;
        });
      }
    } catch (e) {
      // 处理可能的异常
      if (mounted) {
        setState(() {
          _currentQuestionNote = '';
          _noteController.text = '';
        });
      }
    }
  }

  /// 保存当前题目的笔记
  Future<void> _saveCurrentQuestionNote() async {
    final questionId = _getCurrentQuestionId();
    await _questionNoteService.saveQuestionNote(questionId, _noteController.text);
    setState(() {
      _currentQuestionNote = _noteController.text;
      _isEditingNote = false;
    });
  }

  /// 开始编辑笔记
  void _startEditingNote() {
    setState(() {
      _isEditingNote = true;
      _showNoteEditor = true;
      _noteController.text = _currentQuestionNote;
    });
  }

  /// 取消编辑笔记
  void _cancelEditingNote() {
    setState(() {
      _isEditingNote = false;
      _noteController.text = _currentQuestionNote;
    });
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
