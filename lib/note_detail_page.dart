import 'package:flutter/material.dart';
import 'notes/note_new.dart';
import 'note_service.dart';
import 'ai/ai_question.dart';
import 'ai/ai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class NoteDetailPage extends StatefulWidget {
  final Note note;
  final NoteService noteService;

  const NoteDetailPage({super.key, required this.note, required this.noteService});

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _tabController = TabController(length: 4, vsync: this); // 4 tabs: 笔记详情 + 3种题型
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final updatedNote = widget.note.copyWith(
      title: _titleController.text,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    
    widget.noteService.updateNote(updatedNote).then((_) {
      if (mounted) {
        Navigator.pop(context, updatedNote);
      }
    });
  }

  Future<void> _generateQuestions(QuestionType type, int count) async {
    if (widget.note.content.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('笔记内容为空，无法生成题目')),
        );
      }
      return;
    }

    final String questionTypeText;
    switch (type) {
      case QuestionType.multipleChoice:
        questionTypeText = '选择题';
        break;
      case QuestionType.fillInBlank:
        questionTypeText = '填空题';
        break;
      case QuestionType.shortAnswer:
        questionTypeText = '问答题';
        break;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在生成$count道$questionTypeText...')),
        );
      }

      final aiService = AIService();
      final result = await aiService.generateQuestions(
        content: widget.note.content,
        questionType: questionTypeText,
        count: count,
      );

      final List<AIQuestion> newQuestions = [];
      final List<dynamic> questionsData = result['questions'] as List;

      for (final questionData in questionsData) {
        final Map<String, dynamic> data = questionData['data'] as Map<String, dynamic>;
        switch (questionTypeText) {
          case '选择题':
            newQuestions.add(AIQuestion(
              type: QuestionType.multipleChoice,
              questionData: MultipleChoiceQuestion.fromJson(data),
            ));
            break;
          case '填空题':
            newQuestions.add(AIQuestion(
              type: QuestionType.fillInBlank,
              questionData: FillInBlankQuestion.fromJson(data),
            ));
            break;
          case '问答题':
            newQuestions.add(AIQuestion(
              type: QuestionType.shortAnswer,
              questionData: ShortAnswerQuestion.fromJson(data),
            ));
            break;
        }
      }

      // 更新笔记
      final updatedQuestions = List<AIQuestion>.from(widget.note.questions);
      updatedQuestions.addAll(newQuestions);

      final updatedNote = widget.note.copyWith(questions: updatedQuestions);
      await widget.noteService.updateNote(updatedNote);

      if (mounted) {
        // 直接更新当前页面，不进行跳转
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pop(context, updatedNote);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功生成$count道$questionTypeText')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成题目失败: $e')),
        );
      }
    }
  }

  Future<void> _showGenerateQuestionsDialog(QuestionType type) async {
    final TextEditingController countController = TextEditingController(text: '5');
    
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('生成题目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请输入要生成的题目数量:'),
              const SizedBox(height: 16),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '题目数量',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final count = int.tryParse(countController.text) ?? 5;
                Navigator.of(context).pop();
                _generateQuestions(type, count);
              },
              child: const Text('生成'),
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
        title: const Text('笔记详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveNote,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '笔记详情'),
            Tab(text: '选择题'),
            Tab(text: '填空题'),
            Tab(text: '简答题'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNoteDetailTab(),
          _buildMultipleChoiceQuestionsTab(),
          _buildFillInBlankQuestionsTab(),
          _buildShortAnswerQuestionsTab(),
        ],
      ),
    );
  }

  Widget _buildNoteDetailTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题',
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _contentController.text.isNotEmpty
                ? SingleChildScrollView(
                    child: MarkdownBody(data: _contentController.text),
                  )
                : const Text('暂无内容'),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestionsTab() {
    final multipleChoiceQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.multipleChoice)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '选择题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showGenerateQuestionsDialog(QuestionType.multipleChoice),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('AI生成'),
              ),
            ],
          ),
        ),
        if (multipleChoiceQuestions.isEmpty)
          const Expanded(
            child: Center(
              child: Text('暂无选择题'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: multipleChoiceQuestions.length,
              itemBuilder: (context, index) {
                final question = multipleChoiceQuestions[index].questionData as MultipleChoiceQuestion;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(question.options.length, (i) {
                          return ListTile(
                            title: Text(question.options[i]),
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: i == question.correctAnswerIndex 
                                  ? Colors.green 
                                  : Colors.grey,
                              child: i == question.correctAnswerIndex
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : const SizedBox(),
                            ),
                          );
                        }),
                        if (question.explanation != null) ...[
                          const Divider(),
                          Text(
                            '解析: ${question.explanation}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFillInBlankQuestionsTab() {
    final fillInBlankQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.fillInBlank)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '填空题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showGenerateQuestionsDialog(QuestionType.fillInBlank),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('AI生成'),
              ),
            ],
          ),
        ),
        if (fillInBlankQuestions.isEmpty)
          const Expanded(
            child: Center(
              child: Text('暂无填空题'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: fillInBlankQuestions.length,
              itemBuilder: (context, index) {
                final question = fillInBlankQuestions[index].questionData as FillInBlankQuestion;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          children: [
                            const Chip(label: Text('参考答案:')),
                            ...question.correctAnswers.map((answer) => Chip(label: Text(answer))),
                          ],
                        ),
                        if (question.hint != null) ...[
                          const SizedBox(height: 8),
                          Text('提示: ${question.hint}'),
                        ],
                        if (question.explanation != null) ...[
                          const Divider(),
                          Text(
                            '解析: ${question.explanation}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildShortAnswerQuestionsTab() {
    final shortAnswerQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.shortAnswer)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '简答题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showGenerateQuestionsDialog(QuestionType.shortAnswer),
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('AI生成'),
              ),
            ],
          ),
        ),
        if (shortAnswerQuestions.isEmpty)
          const Expanded(
            child: Center(
              child: Text('暂无简答题'),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: shortAnswerQuestions.length,
              itemBuilder: (context, index) {
                final question = shortAnswerQuestions[index].questionData as ShortAnswerQuestion;
                return Card(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.question,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('可接受的答案:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        ...question.acceptableAnswers.map((answer) => 
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                            child: Text('• $answer'),
                          )
                        ),
                        if (question.explanation != null) ...[
                          const Divider(),
                          Text(
                            '解析: ${question.explanation}',
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}