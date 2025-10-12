import 'package:shared_preferences/shared_preferences.dart';

class DirectoryService {
  static const String _directoriesKey = 'directories';
  
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<String>> loadDirectories() async {
    final List<String>? directories = _prefs.getStringList(_directoriesKey);
    return directories ?? [];
  }

  Future<void> saveDirectories(List<String> directories) async {
    await _prefs.setStringList(_directoriesKey, directories);
  }

  Future<void> addDirectory(String path) async {
    final List<String> directories = await loadDirectories();
    if (!directories.contains(path)) {
      directories.add(path);
      await saveDirectories(directories);
    }
  }

  Future<void> removeDirectory(String path) async {
    final List<String> directories = await loadDirectories();
    // 删除指定路径的目录及其所有子目录
    directories.removeWhere((dir) => dir == path || dir.startsWith('$path/'));
    await saveDirectories(directories);
  }
  
  // 添加重命名目录功能
  Future<void> renameDirectory(String oldPath, String newPath) async {
    final List<String> directories = await loadDirectories();
    
    // 更新直接匹配的目录
    final List<String> updatedDirectories = [];
    for (final dir in directories) {
      if (dir == oldPath) {
        // 精确匹配要重命名的目录
        updatedDirectories.add(newPath);
      } else if (dir.startsWith('$oldPath/')) {
        // 匹配子目录
        final newDirPath = dir.replaceFirst(oldPath, newPath);
        updatedDirectories.add(newDirPath);
      } else {
        updatedDirectories.add(dir);
      }
    }
    
    await saveDirectories(updatedDirectories);
  }
}