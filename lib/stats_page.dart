import 'package:flutter/material.dart';
import 'stats_service.dart'; // 添加统计服务导入
import 'note_service.dart';
import 'srs_service.dart';
import 'note.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final StatsService _statsService = StatsService();
  final NoteService _noteService = NoteService();
  final SRSService _srsService = SRSService();
  StatsData? _statsData;
  List<Note> _notes = [];
  SRSStats? _srsStats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await _statsService.init();
    await _noteService.init();
    final notes = await _noteService.loadNotes();
    final stats = _srsService.getStats(notes);
    
    setState(() {
      _statsData = _statsService.getStats();
      _notes = notes;
      _srsStats = stats;
    });
  }

  // 格式化学习时间显示
  String _formatStudyTime(int seconds) {
    final Duration duration = Duration(seconds: seconds);
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '$hours 小时 $minutes 分钟';
    } else if (minutes > 0) {
      return '$minutes 分钟';
    } else {
      return '$seconds 秒';
    }
  }

  // 计算正确率
  String _calculateAccuracy() {
    if (_statsData == null || _statsData!.totalQuestionsAnswered == 0) {
      return '0%';
    }
    
    final double accuracy = (_statsData!.totalCorrectAnswers / _statsData!.totalQuestionsAnswered) * 100;
    return '${accuracy.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('统计数据'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0,0.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                '学习统计',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),

              ),
              const SizedBox(height: 8),
              Text(
                '查看你的学习进度和成果',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              
              // 统计卡片
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildStatRow(context, '总学习时长', _statsData != null ? _formatStudyTime(_statsData!.totalStudyTime) : '--'),
                      const Divider(),
                      _buildStatRow(context, '已完成题目', _statsData != null ? '${_statsData!.totalQuestionsAnswered} 题' : '--'),
                      const Divider(),
                      _buildStatRow(context, '正确率', _statsData != null ? _calculateAccuracy() : '--'),
                      const Divider(),
                      _buildStatRow(context, '笔记数量', _statsData != null ? '${_statsData!.totalNotes} 篇' : '--'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 复习计划卡片
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '复习计划',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '根据艾宾浩斯遗忘曲线制定的复习计划',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildReviewCard(
                            context,
                            title: '今日复习',
                            count: _srsStats?.todayReviewCount ?? 0,
                            color: Colors.blue,
                            icon: Icons.today,
                          ),
                          _buildReviewCard(
                            context,
                            title: '本周复习',
                            count: _srsStats?.weekReviewCount ?? 0,
                            color: Colors.green,
                            icon: Icons.date_range,
                          ),
                          _buildReviewCard(
                            context,
                            title: '逾期复习',
                            count: _srsStats?.overdueCount ?? 0,
                            color: Colors.orange,
                            icon: Icons.warning,
                          ),
                          _buildReviewCard(
                            context,
                            title: '全部复习',
                            count: _notes.length,
                            color: Colors.purple,
                            icon: Icons.library_books,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 图表占位符
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '学习趋势图表',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '可视化展示你的学习进度（此功能即将上线）',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewCard(BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count 项',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}