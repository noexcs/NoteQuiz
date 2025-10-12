import 'dart:convert';
import 'note.dart';

class Group {
  final String id;
  final String name;
  
  Group({
    required this.id,
    required this.name,
  });

  Group copyWith({
    String? id,
    String? name,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Group &&
        other.id == id &&
        other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

class GroupList {
  static List<Group> fromJson(String jsonString) {
    if (jsonString.isEmpty) return [];
    final List<dynamic> jsonData = json.decode(jsonString);
    return jsonData.map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String toJson(List<Group> groups) {
    final List<Map<String, dynamic>> jsonData = groups.map((e) => e.toJson()).toList();
    return json.encode(jsonData);
  }
}