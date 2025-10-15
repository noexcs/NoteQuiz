import 'package:flutter/material.dart';
import 'note.dart';
import 'note_detail_page.dart';
import 'note_service.dart';
import 'stats_service.dart';
import 'directory_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  // 服务实例
  final NoteService _noteService = NoteService();
  final StatsService _statsService = StatsService();
  final DirectoryService _directoryService = DirectoryService();

  // 状态变量
  bool _isLoading = true;
  String currentDirectory = ''; // 当前目录路径

  // 数据缓存
  List<Note> _allNotes = [];
  List<Note> _currentNotes = [];
  List<String> _subdirectories = [];

  // 多选相关变量
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {}; // 存储选中的项目ID（笔记ID或目录名）

  // 剪切板状态变量
  bool _isCutMode = false;
  Set<String> _cutItems = {}; // 存储被剪切的项目ID
  String _cutSourceDirectory = ''; // 剪切源目录

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 统一的数据加载方法，取代旧的 _loadNotes 和 FutureBuilder
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    // 初始化服务
    await _noteService.init();
    await _statsService.init();
    await _directoryService.init();

    // 并行加载笔记和目录数据
    final allNotesFuture = _noteService.loadNotes();
    final allDirectoriesFuture = _directoryService.loadDirectories();

    _allNotes = await allNotesFuture;
    final allDirectories = await allDirectoriesFuture;

    // 筛选当前目录下的笔记
    _currentNotes = _allNotes.where((note) => note.directory == currentDirectory).toList();

    // 计算当前目录下的子目录
    final subdirectoriesSet = <String>{};
    final prefix = currentDirectory.isEmpty ? '' : '$currentDirectory/';
    for (final dir in allDirectories) {
      if (dir.startsWith(prefix)) {
        final relativePath = dir.substring(prefix.length);
        if (relativePath.isNotEmpty) {
          final firstSegment = relativePath.split('/')[0];
          subdirectoriesSet.add(firstSegment);
        }
      }
    }
    _subdirectories = subdirectoriesSet.toList()..sort();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // 更新笔记总数统计
    await _statsService.updateNotesCount(_allNotes.length);
  }

  // --- UI交互方法 ---

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

  // --- 笔记和目录操作 ---

  Future<void> _addNote() async {
    final newNote = Note(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '', // 默认标题为空
      content: '',
      directory: currentDirectory,
    );

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailPage(note: newNote, noteService: _noteService),
      ),
    );

    if (result != null && mounted) {
      await _noteService.addNote(result);
      await _loadData();
    }
  }

  Future<void> _editNote(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailPage(note: note, noteService: _noteService),
      ),
    );

    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteNote(String id) async {
    final confirmed = await _showConfirmationDialog(
      title: '确认删除',
      content: '确定要删除这条笔记吗？',
    );

    if (confirmed == true && mounted) {
      await _noteService.deleteNote(id);
      await _loadData();
    }
  }

  Future<void> _addDirectory() async {
    final result = await _showDirectoryDialog(title: '添加新目录', label: '目录名称');
    if (result != null && mounted) {
      final fullPath = currentDirectory.isEmpty ? result : '$currentDirectory/$result';
      await _directoryService.addDirectory(fullPath);
      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "$result" 创建成功')),
      );
    }
  }

  Future<void> _renameDirectory(String oldDirectoryName) async {
    final result = await _showDirectoryDialog(
      title: '重命名目录',
      label: '新目录名称',
      initialValue: oldDirectoryName,
    );
    if (result != null && mounted) {
      final oldFullPath = currentDirectory.isEmpty ? oldDirectoryName : '$currentDirectory/$oldDirectoryName';
      final newFullPath = currentDirectory.isEmpty ? result : '$currentDirectory/$result';

      await _directoryService.renameDirectory(oldFullPath, newFullPath);

      // 使用缓存的 _allNotes 更新笔记目录，提高效率
      final notesToUpdate = _allNotes.where((note) =>
          note.directory != null &&
          (note.directory == oldFullPath || note.directory!.startsWith('$oldFullPath/')));

      for (final note in notesToUpdate) {
        final newDirectoryPath = note.directory!.replaceFirst(oldFullPath, newFullPath);
        await _noteService.updateNote(note.copyWith(directory: newDirectoryPath));
      }

      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "$oldDirectoryName" 已重命名为 "$result"')),
      );
    }
  }

  Future<void> _deleteDirectory(String directoryName) async {
    final confirmed = await _showConfirmationDialog(
      title: '确认删除',
      content: '确定要删除目录 "$directoryName" 及其所有内容吗？',
    );

    if (confirmed == true && mounted) {
      final fullPath = currentDirectory.isEmpty ? directoryName : '$currentDirectory/$directoryName';
      await _directoryService.removeDirectory(fullPath);

      // 使用缓存的 _allNotes 删除相关笔记，提高效率
      final notesToDelete = _allNotes.where((note) =>
          note.directory != null &&
          (note.directory == fullPath || note.directory!.startsWith('$fullPath/')));

      for (final note in notesToDelete) {
        await _noteService.deleteNote(note.id);
      }

      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('目录 "$directoryName" 删除成功')),
      );
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;
    final confirmed = await _showConfirmationDialog(
      title: '确认删除',
      content: '确定要删除选中的 ${_selectedItems.length} 个项目吗？',
    );

    if (confirmed == true && mounted) {
      for (final itemId in _selectedItems) {
        // 判断是笔记还是目录
        final isNote = _allNotes.any((note) => note.id == itemId);

        if (isNote) {
          await _noteService.deleteNote(itemId);
        } else {
          final fullPath = currentDirectory.isEmpty ? itemId : '$currentDirectory/$itemId';
          await _directoryService.removeDirectory(fullPath);

          final notesToDelete = _allNotes.where((note) =>
              note.directory != null &&
              (note.directory == fullPath || note.directory!.startsWith('$fullPath/')));
          
          for (final note in notesToDelete) {
            await _noteService.deleteNote(note.id);
          }
        }
      }

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      await _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('删除成功')),
      );
    }
  }

  // --- 移动功能相关方法 ---

  Future<void> _cutSelectedItems() async {
    if (_selectedItems.isEmpty) return;
    
    setState(() {
      _isCutMode = true;
      _cutItems = Set<String>.from(_selectedItems);
      _cutSourceDirectory = currentDirectory;
      _isSelectionMode = false;
      _selectedItems.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已剪切，浏览到目标目录后点击粘贴')),
    );
  }

  Future<void> _pasteItems() async {
    if (_cutItems.isEmpty) return;

    final targetDirectory = currentDirectory;
    int moveCount = 0;

    try {
      for (final itemId in _cutItems) {
        // 判断是笔记还是目录
        final isNote = _allNotes.any((note) => note.id == itemId);

        if (isNote) {
          // 移动笔记
          final note = _allNotes.firstWhere((note) => note.id == itemId);
          final updatedNote = note.copyWith(directory: targetDirectory);
          await _noteService.updateNote(updatedNote);
          moveCount++;
        } else {
          // 移动目录
          final oldFullPath = _cutSourceDirectory.isEmpty 
              ? itemId 
              : '$_cutSourceDirectory/$itemId';
          
          final newFullPath = targetDirectory.isEmpty 
              ? itemId 
              : '$targetDirectory/$itemId';

          // 检查目标目录是否已存在同名目录
          final allDirectories = await _directoryService.loadDirectories();
          final directoryExists = allDirectories.contains(newFullPath);
          if (directoryExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('目录 "$itemId" 在目标位置已存在')),
              );
            }
            continue;
          }

          await _directoryService.renameDirectory(oldFullPath, newFullPath);

          // 更新目录内笔记的路径
          final notesToUpdate = _allNotes.where((note) =>
              note.directory != null &&
              (note.directory == oldFullPath || note.directory!.startsWith('$oldFullPath/')));

          for (final note in notesToUpdate) {
            final newDirectoryPath = note.directory!.replaceFirst(
                RegExp('^$oldFullPath'), newFullPath);
            await _noteService.updateNote(note.copyWith(directory: newDirectoryPath));
          }
          moveCount++;
        }
      }

      // 重置剪切状态
      setState(() {
        _isCutMode = false;
        _cutItems.clear();
        _cutSourceDirectory = '';
      });

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('成功移动 $moveCount 个项目')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('移动过程中发生错误')),
        );
      }
    }
  }

  void _cancelCutMode() {
    setState(() {
      _isCutMode = false;
      _cutItems.clear();
      _cutSourceDirectory = '';
    });
  }

  // --- 导航和多选模式 ---

  void _navigateToDirectory(String directory) {
    if (_isSelectionMode) {
      _toggleItemSelected(directory);
    } else {
      setState(() {
        currentDirectory = currentDirectory.isEmpty ? directory : '$currentDirectory/$directory';
      });
      _loadData();
    }
  }

  void _navigateUp() {
    if (currentDirectory.isEmpty) return;
    final parts = currentDirectory.split('/');
    parts.removeLast();
    setState(() {
      currentDirectory = parts.join('/');
    });
    _loadData();
  }

  void _toggleSelectionMode([String? initialItemId]) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
      if (initialItemId != null && _isSelectionMode) {
        _selectedItems.add(initialItemId);
      }
    });
  }

  void _toggleItemSelected(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  // --- 对话框 ---

  Future<String?> _showDirectoryDialog({
    required String title,
    required String label,
    String initialValue = '',
  }) {
    final controller = TextEditingController(text: initialValue);
    final focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => focusNode.requestFocus());

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: label, hintText: '请输入名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名称不能为空')));
                  return;
                }
                if (text.contains('/')) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('名称不能包含"/"字符')));
                  return;
                }
                Navigator.of(context).pop(text);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    ).whenComplete(() => focusNode.dispose());
  }
  
  Future<bool?> _showConfirmationDialog({required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
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
  }

  // --- 构建方法 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(currentDirectory.isEmpty ? '笔记' : '笔记 / $currentDirectory'),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.content_cut),
                  onPressed: _selectedItems.isEmpty ? null : _cutSelectedItems,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedItems.isEmpty ? null : _deleteSelectedItems,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _toggleSelectionMode(),
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.check_box_outline_blank),
                  onPressed: () => _toggleSelectionMode(),
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddOptions,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: _isCutMode 
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pasteItems,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('粘贴'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _cancelCutMode,
                    icon: const Icon(Icons.cancel),
                    label: const Text('取消'),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    if (_subdirectories.isEmpty && _currentNotes.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          if (currentDirectory.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('..'),
              onTap: _navigateUp,
            ),
          const Expanded(
            child: Center(
              child: Text(
                '暂无内容，请添加新笔记或目录',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        if (currentDirectory.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.arrow_upward),
            title: const Text('..'),
            onTap: _navigateUp,
          ),
        ..._subdirectories.map(_buildDirectoryItem),
        ..._currentNotes.map(_buildNoteItem),
      ],
    );
  }

  Widget _buildDirectoryItem(String dir) {
    final isSelected = _selectedItems.contains(dir);
    final isCut = _isCutMode && _cutItems.contains(dir) && currentDirectory == _cutSourceDirectory;
    
    return ListTile(
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleItemSelected(dir),
            )
          : isCut
              ? const Icon(Icons.content_cut, color: Colors.red)
              : const Icon(Icons.folder),
      title: Text(dir),
      onTap: () => _navigateToDirectory(dir),
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode(dir);
        }
      },
      trailing: !_isSelectionMode
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _renameDirectory(dir);
                if (value == 'delete') _deleteDirectory(dir);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'rename', child: Text('重命名')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            )
          : null,
      selected: isSelected || isCut,
    );
  }

  Widget _buildNoteItem(Note note) {
    final isSelected = _selectedItems.contains(note.id);
    final isCut = _isCutMode && _cutItems.contains(note.id) && note.directory == _cutSourceDirectory;
    
    return ListTile(
      leading: _isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleItemSelected(note.id),
            )
          : isCut
              ? const Icon(Icons.content_cut, color: Colors.red)
              : const Icon(Icons.description),
      title: Text(note.title.isEmpty ? '(无标题)' : note.title),
      onTap: _isSelectionMode ? () => _toggleItemSelected(note.id) : () => _editNote(note),
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode(note.id);
        }
      },
      trailing: !_isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteNote(note.id),
            )
          : null,
      selected: isSelected || isCut,
    );
  }
}