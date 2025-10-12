import 'package:flutter/material.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计数据'),
      ),
      body: const Center(
        child: Text(
          '统计数据页面',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}