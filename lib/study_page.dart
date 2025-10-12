import 'package:flutter/material.dart';

class StudyPage extends StatelessWidget {
  const StudyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习'),
      ),
      body: const Center(
        child: Text(
          '学习页面',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}