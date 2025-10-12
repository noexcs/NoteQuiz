import 'package:shared_preferences/shared_preferences.dart';
import 'group.dart';

class GroupService {
  static const String _groupsKey = 'groups';
  
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // 确保默认组存在
    await _ensureDefaultGroupExists();
  }

  /// 确保默认组存在
  Future<void> _ensureDefaultGroupExists() async {
    final String? groupsJson = _prefs.getString(_groupsKey);
    
    // 如果没有组数据，创建默认组
    if (groupsJson == null || groupsJson.isEmpty) {
      final defaultGroup = Group(id: 'default', name: '默认组');
      await saveGroups([defaultGroup]);
    } else {
      final List<Group> groups = GroupList.fromJson(groupsJson);
      final defaultGroupExists = groups.any((group) => group.id == 'default');
      
      if (!defaultGroupExists) {
        final defaultGroup = Group(id: 'default', name: '默认组');
        groups.insert(0, defaultGroup);
        await saveGroups(groups);
      }
    }
  }

  Future<List<Group>> loadGroups() async {
    final String? groupsJson = _prefs.getString(_groupsKey);
    if (groupsJson == null || groupsJson.isEmpty) {
      // 如果没有组数据，创建默认组
      final defaultGroup = Group(id: 'default', name: '默认组');
      return [defaultGroup];
    }
    return GroupList.fromJson(groupsJson);
  }

  Future<void> saveGroups(List<Group> groups) async {
    final String groupsJson = GroupList.toJson(groups);
    await _prefs.setString(_groupsKey, groupsJson);
  }

  Future<void> addGroup(Group group) async {
    final List<Group> groups = await loadGroups();
    groups.add(group);
    await saveGroups(groups);
  }

  Future<void> updateGroup(Group group) async {
    final List<Group> groups = await loadGroups();
    final index = groups.indexWhere((element) => element.id == group.id);
    if (index != -1) {
      groups[index] = group;
      await saveGroups(groups);
    }
  }

  Future<void> deleteGroup(String id) async {
    // 不允许删除默认组
    if (id == 'default') {
      throw Exception('不能删除默认组');
    }
    
    final List<Group> groups = await loadGroups();
    groups.removeWhere((group) => group.id == id);
    await saveGroups(groups);
  }
}