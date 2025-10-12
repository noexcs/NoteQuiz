import 'package:flutter/material.dart';
import 'notes/note_new.dart';
import 'note_detail_page.dart';
import 'note_service.dart';
import 'stats_service.dart'; // 添加统计服务导入
import 'directory_service.dart'; // 添加目录服务导入

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  List<Note> notes = [];
  final NoteService _noteService = NoteService();
  final StatsService _statsService = StatsService(); // 添加统计服务实例
  final DirectoryService _directoryService = DirectoryService(); // 添加目录服务实例
  String currentDirectory = ''; // 当前目录路径
  
  // 多选相关变量
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {}; // 存储选中的项目ID（笔记ID或目录名）

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    await _noteService.init();
    await _statsService.init(); // 初始化统计服务
    await _directoryService.init(); // 初始化目录服务
    final loadedNotes = await _noteService.loadNotes();
    // 只显示当前目录下的笔记
    final filteredNotes = loadedNotes.where((note) => note.directory == currentDirectory).toList();
    setState(() {
      notes = filteredNotes;
    });
    
    // 更新笔记数量统计
    await _statsService.updateNotesCount(notes.length);
  }

  Future<void> _addNote() async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '', // 默认标题为空
      content: '',
      directory: currentDirectory, // 设置当前目录
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

  Future<void> _addDirectory() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加新目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '目录名称',
            hintText: '请输入目录名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入目录名称')),
                );
                return;
              }
              // 检查目录名是否包含非法字符（这里简单检查是否包含斜杠）
              if (controller.text.contains('/')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('目录名称不能包含"/"字符')),
                );
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // 创建目录的完整路径
      final fullPath = currentDirectory.isEmpty ? result : '$currentDirectory/$result';
      
      // 添加目录到目录服务
      await _directoryService.addDirectory(fullPath);
      await _loadNotes();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "${result}" 创建成功')),
      );
    }
  }

  // 目录重命名方法
  Future<void> _renameDirectory(String oldDirectoryName) async {
    final TextEditingController controller = TextEditingController(text: oldDirectoryName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '新目录名称',
            hintText: '请输入新目录名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入目录名称')),
                );
                return;
              }
              // 检查目录名是否包含非法字符
              if (controller.text.contains('/')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('目录名称不能包含"/"字符')),
                );
                return;
              }
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      // 构建完整路径
      final oldFullPath = currentDirectory.isEmpty ? oldDirectoryName : '$currentDirectory/$oldDirectoryName';
      final newFullPath = currentDirectory.isEmpty ? result : '$currentDirectory/$result';
      
      // 重命名目录
      await _directoryService.renameDirectory(oldFullPath, newFullPath);
      
      // 更新所有笔记中的目录路径
      final allNotes = await _noteService.loadNotes();
      final notesToUpdate = allNotes.where((note) => note.directory != null && note.directory!.startsWith('$oldFullPath/')).toList();
      
      for (final note in notesToUpdate) {
        final newDirectoryPath = note.directory!.replaceFirst(oldFullPath, newFullPath);
        final updatedNote = Note(
          id: note.id,
          title: note.title,
          content: note.content,
          directory: newDirectoryPath,
        );
        await _noteService.updateNote(updatedNote);
      }
      
      await _loadNotes();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "$oldDirectoryName" 已重命名为 "$result"')),
      );
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
  
  // 单个目录删除方法
  Future<void> _deleteDirectory(String directoryName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除目录 "$directoryName" 及其所有内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      // 构建完整路径
      final fullPath = currentDirectory.isEmpty ? directoryName : '$currentDirectory/$directoryName';
      
      // 删除目录及其所有子目录
      await _directoryService.removeDirectory(fullPath);
      
      // 删除目录中的所有笔记
      final allNotes = await _noteService.loadNotes();
      final notesToDelete = allNotes.where((note) => note.directory != null && (note.directory == fullPath || note.directory!.startsWith('$fullPath/'))).toList();
      
      for (final note in notesToDelete) {
        await _noteService.deleteNote(note.id);
      }
      
      await _loadNotes();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "$directoryName" 删除成功')),
      );
    }
  }
  
  // 批量删除选中的项目
  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedItems.length} 个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      // 删除选中的目录和笔记
      for (final itemId in _selectedItems) {
        // 判断是目录还是笔记
        // 检查 itemId 是否为笔记 ID（通过查找笔记列表）
        final allNotes = await _noteService.loadNotes();
        final isNote = allNotes.any((note) => note.id == itemId);
        
        if (isNote) {
          // 这是一个笔记
          await _noteService.deleteNote(itemId);
        } else {
          // 这是一个目录名称，需要删除整个目录及其内容
          final fullPath = currentDirectory.isEmpty ? itemId : '$currentDirectory/$itemId';
          await _directoryService.removeDirectory(fullPath);
          
          // 删除目录中的所有笔记
          final notesToDelete = allNotes.where((note) => note.directory != null && (note.directory == fullPath || note.directory!.startsWith('$fullPath/'))).toList();
          
          for (final note in notesToDelete) {
            await _noteService.deleteNote(note.id);
          }
        }
      }
      
      // 清空选中项并退出选择模式
      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });
      
      await _loadNotes();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除成功')),
      );
    }
  }

  void _navigateToDirectory(String directory) {
    if (_isSelectionMode) {
      // 在选择模式下，切换该项目的选中状态
      setState(() {
        if (_selectedItems.contains(directory)) {
          _selectedItems.remove(directory);
        } else {
          _selectedItems.add(directory);
        }
      });
    } else {
      // 正常导航到目录
      setState(() {
        currentDirectory = directory;
      });
      _loadNotes();
    }
  }

  void _navigateUp() {
    if (currentDirectory.isEmpty) return;
    
    final parts = currentDirectory.split('/');
    parts.removeLast();
    setState(() {
      currentDirectory = parts.join('/');
    });
    _loadNotes();
  }

  // 获取当前目录下的子目录
  Future<List<String>> _getSubdirectories() async {
    final allDirectories = await _directoryService.loadDirectories();
    final subdirectories = <String>[];
    final prefix = currentDirectory.isEmpty ? '' : '$currentDirectory/';
    
    for (final dir in allDirectories) {
      // 检查目录是否在当前目录下
      if (dir.startsWith(prefix)) {
        final relativePath = dir.substring(prefix.length);
        if (relativePath.contains('/')) {
          // 多级目录，提取第一级
          final firstSegment = relativePath.split('/')[0];
          if (!subdirectories.contains(firstSegment)) {
            subdirectories.add(firstSegment);
          }
        } else if (relativePath.isNotEmpty) {
          // 直接子目录
          if (!subdirectories.contains(relativePath)) {
            subdirectories.add(relativePath);
          }
        }
      }
    }
    
    return subdirectories;
  }
  
  // 切换选择模式
  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedItems.clear();
      }
    });
  }
  
  // 切换项目选中状态
  void _toggleItemSelected(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('新建目录'),
                onTap: () {
                  Navigator.pop(context);
                  _addDirectory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.note_add),
                title: const Text('新建笔记'),
                onTap: () {
                  Navigator.pop(context);
                  _addNote();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentDirectory.isEmpty ? '笔记' : '笔记 / $currentDirectory'),
        actions: [
          // 选择模式相关操作
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedItems.isEmpty ? null : _deleteSelectedItems,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _toggleSelectionMode,
            ),
          ],
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _getSubdirectories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final subdirectories = snapshot.data!;
          
          return FutureBuilder<List<Note>>(
            future: _noteService.loadNotes(),
            builder: (context, notesSnapshot) {
              if (!notesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final allNotes = notesSnapshot.data!;
              final currentNotes = allNotes.where((note) => note.directory == currentDirectory).toList();
              
              return Column(
                children: [
                  // 面包屑导航和返回上一级按钮
                  if (currentDirectory.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.arrow_upward),
                      title: const Text('..'),
                      onTap: _navigateUp,
                    ),
                  
                  // 子目录列表
                  ...subdirectories.map((dir) => ListTile(
                        leading: _isSelectionMode 
                          ? Checkbox(
                              value: _selectedItems.contains(dir),
                              onChanged: (_) => _toggleItemSelected(dir),
                            )
                          : const Icon(Icons.folder),
                        title: Text(dir),
                        onTap: () => _navigateToDirectory(dir),
                        trailing: _isSelectionMode
                          ? null
                          : PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'rename') {
                                  _renameDirectory(dir);
                                } else if (value == 'delete') {
                                  _deleteDirectory(dir);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('重命名'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                      )),
                  
                  // 当前目录下的笔记
                  ...currentNotes.map((note) => ListTile(
                        leading: _isSelectionMode
                          ? Checkbox(
                              value: _selectedItems.contains(note.id),
                              onChanged: (_) => _toggleItemSelected(note.id),
                            )
                          : const Icon(Icons.description),
                        title: Text(note.title),
                        onTap: _isSelectionMode 
                          ? () => _toggleItemSelected(note.id) 
                          : () => _editNote(note),
                        trailing: _isSelectionMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteNote(note.id),
                            ),
                      )),
                  
                  // 如果没有内容，显示提示信息
                  if (subdirectories.isEmpty && currentNotes.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          '暂无内容，请添加新笔记或目录',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog();

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final TextEditingController _titleController = TextEditingController();
  bool _useAI = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加新笔记'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '笔记标题',
              hintText: '请输入笔记标题',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: _useAI,
                onChanged: (value) {
                  setState(() {
                    _useAI = value ?? false;
                  });
                },
              ),
              const Text('使用AI生成内容'),
            ],
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
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入笔记标题')),
              );
              return;
            }
            
            Navigator.of(context).pop({
              'title': _titleController.text,
              'useAI': _useAI,
            });
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}