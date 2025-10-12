import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'study_page.dart';
import 'review_page.dart';
import 'settings_page.dart';
import 'notes_page.dart';
import 'stats_page.dart';

// 添加自定义绘制类
class HeaderPainter extends CustomPainter {
  final Color color;

  HeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // 绘制装饰性波浪线
    path.moveTo(0, size.height * 0.85);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.95, size.width * 0.5, size.height * 0.85);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.75, size.width, size.height * 0.85);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // 绘制一些装饰性圆点
    final dotPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // 在不同位置绘制圆点
    canvas.drawCircle(
        Offset(size.width * 0.1, size.height * 0.3), size.width * 0.03, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.4), size.width * 0.02, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.9, size.height * 0.2), size.width * 0.025, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.3, size.height * 0.2), size.width * 0.015, dotPaint);
    canvas.drawCircle(
        Offset(size.width * 0.6, size.height * 0.3), size.width * 0.02, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
            useMaterial3: true, // 启用 Material Design 3
          )
        : ThemeData(
            brightness: Brightness.dark, // 使用暗色主题，让白色文字更清晰
            primarySwatch: Colors.blue,
            useMaterial3: true, // 启用 Material Design 3
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('学习助手'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 渐变背景
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                    ),
                  ),
                  // 装饰性图案
                  CustomPaint(
                    painter: HeaderPainter(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.1),
                    ),
                    size: const Size(double.infinity, double.infinity),
                  ),
                  // 中心装饰图标
                  Center(
                    child: Opacity(
                      opacity: 0.8,
                      child: Icon(
                        Icons.school,
                        size: 80,
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 学习卡片
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/study');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 120,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.school,
                              size: 36,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '学习',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '开始新的学习旅程',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // 复习卡片
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/review');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 120,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.refresh,
                              size: 36,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '复习',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '巩固已有知识点',
                                  style: TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 功能模块标题
                Text(
                  '功能模块',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 网格布局的功能按钮
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildFeatureCard(
                      context,
                      icon: Icons.note_alt_outlined,
                      title: '笔记',
                      subtitle: '管理学习笔记',
                      route: '/notes',
                      color: Colors.orange,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.bar_chart_outlined,
                      title: '统计',
                      subtitle: '查看学习数据',
                      route: '/stats',
                      color: Colors.green,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.settings_outlined,
                      title: '设置',
                      subtitle: '个性化配置',
                      route: '/settings',
                      color: Colors.purple,
                    ),
                    _buildFeatureCard(
                      context,
                      icon: Icons.help_outline,
                      title: '帮助',
                      subtitle: '使用指南',
                      route: '/help',
                      color: Colors.teal,
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          if (route == '/help') {
            // TODO: 实现帮助页面
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('帮助页面正在开发中')),
            );
          } else {
            Navigator.pushNamed(context, route);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
