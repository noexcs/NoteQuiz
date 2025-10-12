import 'package:flutter/material.dart';
import 'notes/note_new.dart';
import 'note_service.dart';
import 'ai/ai_question.dart';

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
            child: TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: '内容',
              ),
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestionsTab() {
    final multipleChoiceQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.multipleChoice)
        .toList();

    if (multipleChoiceQuestions.isEmpty) {
      return const Center(
        child: Text('暂无选择题'),
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildFillInBlankQuestionsTab() {
    final fillInBlankQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.fillInBlank)
        .toList();

    if (fillInBlankQuestions.isEmpty) {
      return const Center(
        child: Text('暂无填空题'),
      );
    }

    return ListView.builder(
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
    );
  }

  Widget _buildShortAnswerQuestionsTab() {
    final shortAnswerQuestions = widget.note.questions
        .where((q) => q.type == QuestionType.shortAnswer)
        .toList();

    if (shortAnswerQuestions.isEmpty) {
      return const Center(
        child: Text('暂无简答题'),
      );
    }

    return ListView.builder(
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
    );
  }
}