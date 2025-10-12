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
  late Note _currentNote;
  bool _isEditing = false; // 添加编辑状态标志
  bool _isGenerating = false; // 添加AI生成状态标志
  String _initialTitle = ''; // 记录初始标题
  String _initialContent = ''; // 记录初始内容
  FocusNode? _titleFocusNode; // 标题输入框焦点节点

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note.title);
    _contentController = TextEditingController(text: widget.note.content);
    _tabController = TabController(length: 4, vsync: this); // 4 tabs: 笔记详情 + 3种题型
    _currentNote = widget.note;
    // 如果是新增笔记（假设内容为空表示新增），则默认进入编辑模式
    _isEditing = widget.note.content.isEmpty;
    
    // 记录初始值用于比较
    _initialTitle = widget.note.title;
    _initialContent = widget.note.content;
    
    // 初始化焦点节点
    _titleFocusNode = FocusNode();
    
    // 如果是新笔记，延迟请求焦点以确保widget已构建完成
    if (widget.note.title.isEmpty && widget.note.content.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _titleFocusNode?.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tabController.dispose();
    _titleFocusNode?.dispose(); // 释放焦点节点资源
    super.dispose();
  }

  // 检查笔记是否有未保存的更改
  bool _hasUnsavedChanges() {
    return _titleController.text != _initialTitle || _contentController.text != _initialContent;
  }

  // 处理返回操作
  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges()) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('保存笔记'),
            content: const Text('您有未保存的更改，是否保存后再退出？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // 不保存
                child: const Text('不保存'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // 保存
                child: const Text('保存'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null), // 取消
                child: const Text('取消'),
              ),
            ],
          );
        },
      );

      if (result == true) {
        // 用户选择保存
        _saveNote();
        return true; // 允许退出
      } else if (result == false) {
        // 用户选择不保存
        return true; // 允许退出
      } else {
        // 用户选择取消
        return false; // 阻止退出
      }
    }
    return true; // 没有未保存的更改，允许退出
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveNote() {
    // 如果标题为空，则使用内容的前几个字符作为标题
    String noteTitle = _titleController.text;
    if (noteTitle.isEmpty) {
      // 使用内容的前20个字符作为标题，去除换行符
      String content = _contentController.text;
      noteTitle = content.replaceAll('\n', ' ').trim();
      if (noteTitle.length > 20) {
        noteTitle = noteTitle.substring(0, 20) + '...';
      }
      
      // 如果内容也为空，则使用默认标题
      if (noteTitle.isEmpty) {
        noteTitle = '未命名笔记';
      }
    }

    final updatedNote = _currentNote.copyWith(
      title: noteTitle,
      content: _contentController.text,
      updatedAt: DateTime.now(),
    );
    
    widget.noteService.updateNote(updatedNote).then((_) {
      if (mounted) {
        // 保存后更新初始值
        setState(() {
          _initialTitle = noteTitle;
          _initialContent = _contentController.text;
          _isEditing = false;
          _titleController.text = noteTitle; // 更新标题控制器的文本
        });
        Navigator.pop(context, updatedNote);
      }
    });
  }

  // 新增方法：使用AI填充内容（流式输出版本）
  Future<void> _fillContentWithAIStream() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先输入笔记标题')),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final aiService = AIService();
      final stream = aiService.streamContentFromTitle(title);
      
      // 清空当前内容
      _contentController.text = '';
      
      // 流式接收内容并实时显示
      await for (final content in stream) {
        if (mounted) {
          setState(() {
            _contentController.text += content;
          });
        }
      }

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI内容生成成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI生成内容失败: $e')),
        );
      }
    }
  }

  Future<void> _generateQuestions(QuestionType type, int count) async {
    if (_currentNote.content.isEmpty) {
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
        content: _currentNote.content,
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
      final updatedQuestions = List<AIQuestion>.from(_currentNote.questions);
      updatedQuestions.addAll(newQuestions);

      final updatedNote = _currentNote.copyWith(questions: updatedQuestions);
      await widget.noteService.updateNote(updatedNote);

      if (mounted) {
        setState(() {
          _currentNote = updatedNote;
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('笔记详情'),
          actions: [
            IconButton(
              icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
              onPressed: _toggleEdit,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveNote,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: '笔记详情'),
              Tab(text: '选择题(${_currentNote.questions.where((q) => q.type == QuestionType.multipleChoice).length})'),
              Tab(text: '填空题(${_currentNote.questions.where((q) => q.type == QuestionType.fillInBlank).length})'),
              Tab(text: '简答题(${_currentNote.questions.where((q) => q.type == QuestionType.shortAnswer).length})'),
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
        floatingActionButton: _isEditing ? FloatingActionButton.extended(
          onPressed: _isGenerating ? null : _fillContentWithAIStream,
          icon: _isGenerating 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.auto_fix_high),
          label: Text(_isGenerating ? '正在AI填充' : 'AI填充内容'),
        ) : null,
      ),
    );
  }

  Widget _buildNoteDetailTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_isEditing)
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '请输入笔记标题', // 添加placeholder提示
              ),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              // 使用专门创建的FocusNode
              focusNode: _titleFocusNode,
            )
          else
            Text(
              _titleController.text,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: _isEditing
                ? TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      hintText: '请输入笔记内容...',
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    expands: true,
                  )
                : _contentController.text.isNotEmpty
                    ? SingleChildScrollView(
                        child: MarkdownBody(data: _contentController.text),
                      )
                    : const Center(child: Text('暂无内容')),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleChoiceQuestionsTab() {
    final multipleChoiceQuestions = _currentNote.questions
        .where((q) => q.type == QuestionType.multipleChoice)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '选择题(${multipleChoiceQuestions.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showGenerateQuestionsDialog(QuestionType.multipleChoice),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('AI生成'),
                  ),
                  const SizedBox(width: 8),
                  if (multipleChoiceQuestions.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: Colors.red,
                      onPressed: () => _confirmDeleteAllQuestions(QuestionType.multipleChoice),
                    ),
                ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.question,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDeleteQuestion(index, QuestionType.multipleChoice),
                            ),
                          ],
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
    final fillInBlankQuestions = _currentNote.questions
        .where((q) => q.type == QuestionType.fillInBlank)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '填空题(${fillInBlankQuestions.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showGenerateQuestionsDialog(QuestionType.fillInBlank),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('AI生成'),
                  ),
                  const SizedBox(width: 8),
                  if (fillInBlankQuestions.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: Colors.red,
                      onPressed: () => _confirmDeleteAllQuestions(QuestionType.fillInBlank),
                    ),
                ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.question,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDeleteQuestion(index, QuestionType.fillInBlank),
                            ),
                          ],
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
    final shortAnswerQuestions = _currentNote.questions
        .where((q) => q.type == QuestionType.shortAnswer)
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '简答题(${shortAnswerQuestions.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showGenerateQuestionsDialog(QuestionType.shortAnswer),
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('AI生成'),
                  ),
                  const SizedBox(width: 8),
                  if (shortAnswerQuestions.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_forever),
                      color: Colors.red,
                      onPressed: () => _confirmDeleteAllQuestions(QuestionType.shortAnswer),
                    ),
                ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.question,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _confirmDeleteQuestion(index, QuestionType.shortAnswer),
                            ),
                          ],
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

  Future<void> _confirmDeleteQuestion(int index, QuestionType type) async {
    final String typeName;
    switch (type) {
      case QuestionType.multipleChoice:
        typeName = '选择题';
        break;
      case QuestionType.fillInBlank:
        typeName = '填空题';
        break;
      case QuestionType.shortAnswer:
        typeName = '简答题';
        break;
    }

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除这道$typeName吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteQuestion(index, type);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteAllQuestions(QuestionType type) async {
    final String typeName;
    switch (type) {
      case QuestionType.multipleChoice:
        typeName = '选择题';
        break;
      case QuestionType.fillInBlank:
        typeName = '填空题';
        break;
      case QuestionType.shortAnswer:
        typeName = '简答题';
        break;
    }

    int count = 0;
    switch (type) {
      case QuestionType.multipleChoice:
        count = widget.note.questions.where((q) => q.type == QuestionType.multipleChoice).length;
        break;
      case QuestionType.fillInBlank:
        count = widget.note.questions.where((q) => q.type == QuestionType.fillInBlank).length;
        break;
      case QuestionType.shortAnswer:
        count = widget.note.questions.where((q) => q.type == QuestionType.shortAnswer).length;
        break;
    }

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除所有$count道$typeName吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllQuestions(type);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('全部删除'),
            ),
          ],
        );
      },
    );
  }

  void _deleteQuestion(int index, QuestionType type) {
    final updatedQuestions = List<AIQuestion>.from(_currentNote.questions);
    
    // 找到正确的索引（因为列表是过滤后的）
    int actualIndex = 0;
    int filteredIndex = 0;
    for (var i = 0; i < updatedQuestions.length; i++) {
      if (updatedQuestions[i].type == type) {
        if (filteredIndex == index) {
          actualIndex = i;
          break;
        }
        filteredIndex++;
      }
    }
    
    updatedQuestions.removeAt(actualIndex);
    final updatedNote = _currentNote.copyWith(questions: updatedQuestions);
    widget.noteService.updateNote(updatedNote).then((_) {
      if (mounted) {
        setState(() {
          _currentNote = updatedNote;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('题目删除成功')),
        );
      }
    });
  }

  void _deleteAllQuestions(QuestionType type) {
    final String typeName;
    switch (type) {
      case QuestionType.multipleChoice:
        typeName = '选择题';
        break;
      case QuestionType.fillInBlank:
        typeName = '填空题';
        break;
      case QuestionType.shortAnswer:
        typeName = '简答题';
        break;
    }

    final updatedQuestions = List<AIQuestion>.from(_currentNote.questions);
    updatedQuestions.removeWhere((q) => q.type == type);
    final updatedNote = _currentNote.copyWith(questions: updatedQuestions);
    widget.noteService.updateNote(updatedNote).then((_) {
      if (mounted) {
        setState(() {
          _currentNote = updatedNote;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('所有$typeName已删除')),
        );
      }
    });
  }
}