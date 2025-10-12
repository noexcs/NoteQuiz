import 'package:flutter/material.dart';
import 'dart:ui'; // 引入ImageFilter来实现高斯模糊
import 'study_page.dart';
import 'review_page.dart';
import 'settings_page.dart';
import 'notes_page.dart';
import 'stats_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏右上角的Debug标签
      title: 'Flutter Demo',
      theme: ThemeData(
        brightness: Brightness.dark, // 使用暗色主题，让白色文字更清晰
        primarySwatch: Colors.blue,
      ),
      home: const WelcomePage(), // 将首页设置为我们自定义的WelcomePage
      routes: {
        '/study': (context) => const StudyPage(),
        '/review': (context) => const ReviewPage(),
        '/settings': (context) => const SettingsPage(),
        '/notes': (context) => const NotesPage(),
        '/stats': (context) => const StatsPage(),
      },
    );
  }
}

// 新建一个欢迎页面
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand, // 让Stack的子控件填满整个屏幕
        children: <Widget>[
          // 1. 背景图片
          // 请确保在项目的 pubspec.yaml 中添加了 assets/background.jpg
          Image.asset(
            'assets/background.jpg', // 您的背景图片路径
            fit: BoxFit.cover, // 图片铺满屏幕
          ),
          // 2. 页面内容
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, // 将子控件对齐到底部
              children: <Widget>[
                // 两个大的圆角矩形按钮
                _buildFrostedGlassButton(
                  width: 300,
                  height: 60,
                  text: '学习',
                  onPressed: () {
                    // TODO: 跳转到学习页面
                    Navigator.pushNamed(context, '/study');
                  },
                ),
                const SizedBox(height: 20),
                _buildFrostedGlassButton(
                  width: 300,
                  height: 60,
                  text: '复习',
                  onPressed: () {
                    // TODO: 跳转到复习页面
                    Navigator.pushNamed(context, '/review');
                  },
                ),
                const SizedBox(height: 80), // 按钮之间的间距
                // 底部三个小按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _buildFrostedGlassButton(
                      width: 80,
                      height: 40,
                      text: '设置',
                      onPressed: () {
                        // TODO: 跳转到设置页面
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _buildFrostedGlassButton(
                      width: 80,
                      height: 40,
                      text: '笔记',
                      onPressed: () {
                        // TODO: 跳转到笔记页面
                        Navigator.pushNamed(context, '/notes');
                      },
                    ),
                    _buildFrostedGlassButton(
                      width: 80,
                      height: 40,
                      text: '统计数据',
                      onPressed: () {
                        // TODO: 跳转到统计数据页面
                        Navigator.pushNamed(context, '/stats');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 50), // 底部安全边距
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建一个带有高斯模糊效果的按钮
  Widget _buildFrostedGlassButton({
    required double width,
    required double height,
    required String text,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25.0), // 设置圆角
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), // 设置高斯模糊
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2), // 半透明背景色
            borderRadius: BorderRadius.circular(25.0),
            border: Border.all(color: Colors.white.withOpacity(0.3)), // 可选的边框
          ),
          child: TextButton(
            onPressed: onPressed,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}