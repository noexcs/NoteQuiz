import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          '设置页面',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}