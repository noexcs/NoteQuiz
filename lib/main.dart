import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_page.dart';
import 'review_page.dart';
import 'settings_page.dart';
import 'notes_page.dart';
import 'stats_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _themeMode = 'dark';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = prefs.getString('app_theme') ?? 'dark';
    });
  }

  void _updateTheme(String theme) {
    setState(() {
      _themeMode = theme;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 隐藏右上角的Debug标签
      title: 'Flutter Demo',
      theme: _themeMode == 'light' 
        ? ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
          )
        : ThemeData(
            brightness: Brightness.dark, // 使用暗色主题，让白色文字更清晰
            primarySwatch: Colors.blue,
          ),
      home: const WelcomePage(),
      routes: {
        '/study': (context) => const StudyPage(),
        '/review': (context) => const ReviewPage(),
        '/settings': (context) => SettingsPage(onThemeChanged: _updateTheme),
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/study');
              },
              child: const Text('学习'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/review');
              },
              child: const Text('复习'),
            ),
            const SizedBox(height: 80),
            // 底部三个小按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                  child: const Text('设置'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/notes');
                  },
                  child: const Text('笔记'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/stats');
                  },
                  child: const Text('统计数据'),
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}