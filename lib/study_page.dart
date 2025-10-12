import 'package:flutter/material.dart';
import 'note_service.dart';
import 'notes/note_new.dart';
import 'ai/ai_question.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final NoteService _noteService = NoteService();
  List<Note> _notes = [];
  List<AIQuestion> _allQuestions = [];
  int _currentQuestionIndex = 0;
  bool _showAnswer = false;
  
  // 添加用户答题记录
  List<bool?> _userAnswers = []; // null表示未答题，true表示答对，false表示答错
  List<int?> _selectedOptions = []; // 记录选择题用户选择的选项索引

  @override
  void initState() {
    super.initState();
    _loadNotesAndQuestions();
  }

  Future<void> _loadNotesAndQuestions() async {
    await _noteService.init();
    final notes = await _noteService.loadNotes();
    setState(() {
      _notes = notes;
      _allQuestions = _extractAllQuestions(notes);
      _currentQuestionIndex = 0;
      _showAnswer = false;
      
      // 初始化答题记录数组
      _userAnswers = List.filled(_allQuestions.length, null);
      _selectedOptions = List.filled(_allQuestions.length, null);
    });
  }

  List<AIQuestion> _extractAllQuestions(List<Note> notes) {
    List<AIQuestion> questions = [];
    for (var note in notes) {
      questions.addAll(note.questions);
    }
    return questions;
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
        _showAnswer = false;
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
  
  // 处理选择题选项点击事件
  void _handleMultipleChoiceAnswer(int selectedIndex) {
    final currentQuestion = _allQuestions[_currentQuestionIndex];
    if (currentQuestion.type == QuestionType.multipleChoice) {
      final q = currentQuestion.questionData as MultipleChoiceQuestion;
      
      setState(() {
        // 记录用户选择的选项
        _selectedOptions[_currentQuestionIndex] = selectedIndex;
        
        // 判断答案是否正确
        _userAnswers[_currentQuestionIndex] = (selectedIndex == q.correctAnswerIndex);
        
        // 自动跳转到下一题
        if (_currentQuestionIndex < _allQuestions.length - 1) {
          _currentQuestionIndex++;
          _showAnswer = false;
        } else {
          // 如果是最后一题，显示统计结果
          _showQuizResults();
        }
      });
    }
  }
  
  // 处理非选择题的用户自判答案
  void _handleUserJudgment(bool isCorrect) {
    setState(() {
      _userAnswers[_currentQuestionIndex] = isCorrect;
      
      // 跳转到下一题
      if (_currentQuestionIndex < _allQuestions.length - 1) {
        _currentQuestionIndex++;
        _showAnswer = false;
      } else {
        // 如果是最后一题，显示统计结果
        _showQuizResults();
      }
    });
  }
  
  // 显示测验结果
  void _showQuizResults() {
    // 计算正确率
    int correctCount = _userAnswers.where((answer) => answer == true).length;
    double accuracy = _allQuestions.isEmpty ? 0 : correctCount / _allQuestions.length;
    
    // 获取答错的选择题
    List<Map<String, dynamic>> wrongMultipleChoiceQuestions = [];
    for (int i = 0; i < _allQuestions.length; i++) {
      if (_allQuestions[i].type == QuestionType.multipleChoice && 
          (_userAnswers[i] == false || _userAnswers[i] == null)) {
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
    
    // 获取用户自判为错误的非选择题
    List<Map<String, dynamic>> wrongNonMultipleChoiceQuestions = [];
    for (int i = 0; i < _allQuestions.length; i++) {
      if (_allQuestions[i].type != QuestionType.multipleChoice && 
          (_userAnswers[i] == false || _userAnswers[i] == null)) {
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('测验结果'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('正确率: ${accuracy.toStringAsFixed(2)} (${correctCount}/${_allQuestions.length})'),
                const SizedBox(height: 20),
                if (wrongMultipleChoiceQuestions.isNotEmpty) ...[
                  const Text('答错的选择题:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...wrongMultipleChoiceQuestions.map((wrongQ) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('题目: ${wrongQ['question']}'),
                            const SizedBox(height: 5),
                            Text('你的答案: ${wrongQ['userSelectedIndex'] != null ? wrongQ['options'][wrongQ['userSelectedIndex']] : '未作答'}'),
                            Text('正确答案: ${wrongQ['options'][wrongQ['correctAnswerIndex']]}', style: const TextStyle(color: Colors.green)),
                            if (wrongQ['explanation'] != null) ...[
                              const SizedBox(height: 5),
                              Text('解析: ${wrongQ['explanation']}'),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ] else ...[
                  const Text('所有选择题都回答正确！'),
                ],
                if (wrongNonMultipleChoiceQuestions.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('答错的非选择题:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...wrongNonMultipleChoiceQuestions.map((wrongQ) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('题目: ${wrongQ['question']}'),
                            const SizedBox(height: 5),
                            Text('参考答案: ${wrongQ['correctAnswers'].join(', ')}', style: const TextStyle(color: Colors.green)),
                            if (wrongQ['explanation'] != null) ...[
                              const SizedBox(height: 5),
                              Text('解析: ${wrongQ['explanation']}'),
                            ]
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // 重置测验
                setState(() {
                  _currentQuestionIndex = 0;
                  _showAnswer = false;
                  _userAnswers = List.filled(_allQuestions.length, null);
                  _selectedOptions = List.filled(_allQuestions.length, null);
                });
              },
              child: const Text('重新开始'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('${_currentQuestionIndex + 1}/${_allQuestions.length}'),
          ),
        ],
      ),
      body: _allQuestions.isEmpty
          ? const Center(
              child: Text(
                '暂无题目，请先添加笔记并生成题目',
                style: TextStyle(fontSize: 18),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 题目区域 - 可滚动
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionWidget(_allQuestions[_currentQuestionIndex]),
                        if (_showAnswer) ...[
                          const SizedBox(height: 20),
                          _buildAnswerWidget(_allQuestions[_currentQuestionIndex]),
                        ],
                      ],
                    ),
                  ),
                ),
                // 固定在底部的按钮区域
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 只有非选择题才显示"显示答案"按钮
                      if (_allQuestions[_currentQuestionIndex].type != QuestionType.multipleChoice) 
                        Center(
                          child: ElevatedButton(
                            onPressed: _toggleAnswer,
                            child: Text(_showAnswer ? '隐藏答案' : '显示答案'),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // 添加用户判断答案正确性的按钮
                      if (_showAnswer && _allQuestions[_currentQuestionIndex].type != QuestionType.multipleChoice) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => _handleUserJudgment(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('答错了'),
                            ),
                            ElevatedButton(
                              onPressed: () => _handleUserJudgment(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('答对了'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _currentQuestionIndex > 0 ? _previousQuestion : null,
                            child: const Text('上一题'),
                          ),
                          ElevatedButton(
                            onPressed: _currentQuestionIndex < _allQuestions.length - 1
                                ? () {
                                    // 如果是选择题且已作答，或者非选择题且已显示答案并已判断，则自动跳转
                                    final isMultipleChoice = _allQuestions[_currentQuestionIndex].type == QuestionType.multipleChoice;
                                    final hasAnswered = _selectedOptions[_currentQuestionIndex] != null;
                                    final hasShownAnswer = _showAnswer;
                                    final hasJudged = _userAnswers[_currentQuestionIndex] != null;
                                    
                                    if ((isMultipleChoice && hasAnswered) || 
                                        (!isMultipleChoice && hasShownAnswer && hasJudged)) {
                                      setState(() {
                                        if (_currentQuestionIndex < _allQuestions.length - 1) {
                                          _currentQuestionIndex++;
                                          _showAnswer = false;
                                        } else {
                                          _showQuizResults();
                                        }
                                      });
                                    } else {
                                      // 对于非选择题，如果还没显示答案，则显示答案
                                      if (!isMultipleChoice && !hasShownAnswer) {
                                        _toggleAnswer();
                                      }
                                    }
                                  }
                                : () {
                                    // 最后一题，检查是否需要显示答案或直接显示结果
                                    final isMultipleChoice = _allQuestions[_currentQuestionIndex].type == QuestionType.multipleChoice;
                                    final hasAnswered = _selectedOptions[_currentQuestionIndex] != null;
                                    final hasShownAnswer = _showAnswer;
                                    final hasJudged = _userAnswers[_currentQuestionIndex] != null;
                                    
                                    if (isMultipleChoice && hasAnswered) {
                                      _showQuizResults();
                                    } else if (!isMultipleChoice && hasShownAnswer && hasJudged) {
                                      _showQuizResults();
                                    } else {
                                      // 还没有完成最后一步操作
                                      if (!isMultipleChoice && !hasShownAnswer) {
                                        _toggleAnswer();
                                      }
                                    }
                                  },
                            child: const Text('下一题'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildQuestionWidget(AIQuestion question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        final q = question.questionData as MultipleChoiceQuestion;
        final selectedIndex = _selectedOptions[_currentQuestionIndex];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...List.generate(q.options.length, (index) {
              return ListTile(
                title: Text(q.options[index]),
                leading: CircleAvatar(
                  child: Text('${index + 1}'),
                ),
                tileColor: selectedIndex == index ? Colors.blue.withOpacity(0.3) : null,
                onTap: selectedIndex == null ? () => _handleMultipleChoiceAnswer(index) : null,
              );
            }),
          ],
        );
      case QuestionType.fillInBlank:
        final q = question.questionData as FillInBlankQuestion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (q.hint != null) ...[
              const SizedBox(height: 10),
              Text('提示: ${q.hint}'),
            ],
          ],
        );
      case QuestionType.shortAnswer:
        final q = question.questionData as ShortAnswerQuestion;
        return Text(
          q.question,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        );
    }
  }

  Widget _buildAnswerWidget(AIQuestion question) {
    switch (question.type) {
      case QuestionType.multipleChoice:
        final q = question.questionData as MultipleChoiceQuestion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '答案:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ListTile(
              title: Text(q.options[q.correctAnswerIndex]),
              leading: const Icon(Icons.check_circle, color: Colors.green),
            ),
            if (q.explanation != null) ...[
              const SizedBox(height: 10),
              Text('解析: ${q.explanation}'),
            ],
          ],
        );
      case QuestionType.fillInBlank:
        final q = question.questionData as FillInBlankQuestion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '参考答案:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...q.correctAnswers.map((answer) => ListTile(
                  title: Text(answer),
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                )),
            if (q.explanation != null) ...[
              const SizedBox(height: 10),
              Text('解析: ${q.explanation}'),
            ],
          ],
        );
      case QuestionType.shortAnswer:
        final q = question.questionData as ShortAnswerQuestion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '参考答案:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...q.acceptableAnswers.map((answer) => ListTile(
                  title: Text(answer),
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                )),
            if (q.explanation != null) ...[
              const SizedBox(height: 10),
              Text('解析: ${q.explanation}'),
            ],
          ],
        );
    }
  }
}