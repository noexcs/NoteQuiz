import 'package:flutter/material.dart';
import 'notes/note_new.dart';
import 'note_detail_page.dart';
import 'note_service.dart';
import 'stats_service.dart'; // 添加统计服务导入

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> notes = [];
  final NoteService _noteService = NoteService();
  final StatsService _statsService = StatsService(); // 添加统计服务实例

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    await _noteService.init();
    await _statsService.init(); // 初始化统计服务
    final loadedNotes = await _noteService.loadNotes();
    setState(() {
      notes = loadedNotes;
    });
    
    // 更新笔记数量统计
    await _statsService.updateNotesCount(notes.length);
  }

  Future<void> _addNote() async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '新笔记',
      content: '',
    );

    // 直接导航到编辑页面
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailPage(note: newNote, noteService: _noteService),
      ),
    );

    if (result != null && mounted) {
      await _noteService.addNote(result);
      await _loadNotes();
    }
  }

  Future<void> _editNote(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailPage(note: note, noteService: _noteService),
      ),
    );

    if (result != null && mounted) {
      await _loadNotes();
    }
  }

  Future<void> _deleteNote(String id) async {
    await _noteService.deleteNote(id);
    await _loadNotes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNote,
          ),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Text(
                '暂无笔记，请添加新笔记',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return ListTile(
                  title: Text(note.title),
                  onTap: () => _editNote(note),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteNote(note.id),
                  ),
                );
              },
            ),
    );
  }
}