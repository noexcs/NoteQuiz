import 'note.dart';

class SRSService {
  /// 默认参数
  static const double defaultDifficultyFactor = 0.3;
  static const double defaultInterval = 1.0; // 1天
  static const double easyBonus = 1.3;
  static const double hardFactor = 1.2;
  
  /// 根据用户评分更新笔记的SRS参数
  /// [quality] 评分等级: 0=再次学习, 1=困难, 2=良好, 3=简单
  Note updateNoteSRS(Note note, int quality) {
    // 确保评分在有效范围内
    quality = quality.clamp(0, 3);
    
    // 新的复习次数
    int newReviewCount = note.reviewCount + 1;
    
    // 计算新的难度因子
    double newDifficultyFactor = _calculateDifficultyFactor(note.difficultyFactor, quality);
    
    // 计算新的间隔
    double newInterval = _calculateNewInterval(note.interval, note.difficultyFactor, note.reviewCount, quality);
    
    // 计算下次复习日期
    DateTime newNextReviewDate = DateTime.now().add(Duration(days: newInterval.round()));
    
    // 返回更新后的笔记
    return note.copyWith(
      nextReviewDate: newNextReviewDate,
      interval: newInterval,
      difficultyFactor: newDifficultyFactor,
      reviewCount: newReviewCount,
    );
  }
  
  /// 计算新的难度因子
  double _calculateDifficultyFactor(double currentDifficulty, int quality) {
    // SM-2算法的简化版本
    double newDifficulty = currentDifficulty + (0.1 - (quality - 2) * 0.05);
    // 限制难度因子在0-1范围内
    return newDifficulty.clamp(0.0, 1.0);
  }
  
  /// 计算新的间隔
  double _calculateNewInterval(double currentInterval, double difficultyFactor, int reviewCount, int quality) {
    if (quality < 2) {
      // 如果评分是"困难"或"再次学习"，重置间隔为1天
      return defaultInterval;
    }
    
    if (reviewCount == 0) {
      // 第一次复习，间隔为1天
      return defaultInterval;
    } else if (reviewCount == 1) {
      // 第二次复习，间隔为6天
      return 6.0;
    } else {
      // 后续复习，基于难度因子和当前间隔计算
      double newInterval = currentInterval * (hardFactor - difficultyFactor);
      
      // 如果评分是"简单"，增加额外奖励
      if (quality == 3) {
        newInterval *= easyBonus;
      }
      
      return newInterval;
    }
  }
  
  /// 获取今天需要复习的笔记
  List<Note> getTodayReviewNotes(List<Note> allNotes) {
    DateTime now = DateTime.now();
    return allNotes.where((note) {
      // 如果没有设置下次复习日期，则不需要复习
      if (note.nextReviewDate == null) {
        return false;
      }
      
      // 检查是否今天或之前需要复习
      return note.nextReviewDate!.isAtSameMomentAs(now) || 
             note.nextReviewDate!.isBefore(now);
    }).toList();
  }
  
  /// 获取未来7天需要复习的笔记
  List<Note> getWeekReviewNotes(List<Note> allNotes) {
    DateTime now = DateTime.now();
    DateTime oneWeekLater = now.add(const Duration(days: 7));
    
    return allNotes.where((note) {
      if (note.nextReviewDate == null) {
        return false;
      }
      
      return (note.nextReviewDate!.isAtSameMomentAs(now) || 
              note.nextReviewDate!.isAfter(now)) &&
             note.nextReviewDate!.isBefore(oneWeekLater);
    }).toList();
  }
  
  /// 获取所有待复习的笔记
  List<Note> getAllPendingNotes(List<Note> allNotes) {
    DateTime now = DateTime.now();
    return allNotes.where((note) {
      if (note.nextReviewDate == null) {
        return false;
      }
      
      return note.nextReviewDate!.isAtSameMomentAs(now) || 
             note.nextReviewDate!.isBefore(now);
    }).toList();
  }
  
  /// 获取统计信息
  SRSStats getStats(List<Note> allNotes) {
    DateTime now = DateTime.now();
    DateTime oneWeekLater = now.add(const Duration(days: 7));
    
    int todayCount = getTodayReviewNotes(allNotes).length;
    int weekCount = getWeekReviewNotes(allNotes).length;
    
    int overdueCount = allNotes.where((note) {
      if (note.nextReviewDate == null) {
        return false;
      }
      
      return note.nextReviewDate!.isBefore(now);
    }).length;
    
    return SRSStats(
      todayReviewCount: todayCount,
      weekReviewCount: weekCount,
      overdueCount: overdueCount,
    );
  }
}

class SRSStats {
  final int todayReviewCount;
  final int weekReviewCount;
  final int overdueCount;
  
  SRSStats({
    required this.todayReviewCount,
    required this.weekReviewCount,
    required this.overdueCount,
  });
}