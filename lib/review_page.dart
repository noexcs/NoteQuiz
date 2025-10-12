import 'package:flutter/material.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('复习'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text(
          '复习页面',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}