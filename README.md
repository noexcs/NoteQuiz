> 本人暂不熟悉flutter相关技术，代码全部由AI编写，希望有熟悉flutter的开发人员可以优化代码，并提交PR。

# 学习助手 (NoteQuiz)

一款基于Flutter开发的智能学习助手应用，集笔记管理、间隔重复学习(SRS)、知识卡片复习等功能于一体。

## 功能特性

- **笔记管理**: 创建、编辑和组织学习笔记，支持目录分类
- **智能学习**: 基于SRS(间隔重复系统)算法安排复习计划
- **知识卡片**: 自动生成问题卡片帮助巩固知识点
- **学习统计**: 可视化展示学习进度和统计数据
- **个性化设置**: 支持深色/浅色主题切换和自定义主题色

## 核心技术

- Flutter框架跨平台开发
- Shared Preferences本地数据存储
- SRS(间隔重复系统)算法实现
- Material Design 3 UI设计

## 快速开始

### 环境要求

- Flutter 3.9.2或更高版本
- Dart SDK 3.9.2或更高版本

### 安装步骤

1. 克隆项目代码:
   ```bash
   git clone https://github.com/noexcs/NoteQuiz
   ```

2. 进入项目目录并获取依赖:
   ```bash
   cd NoteQuiz
   flutter pub get
   ```

3. 连接设备并运行:
   ```bash
   flutter run
   ```

## 应用架构

- `main.dart`: 应用入口和主界面
- `note.dart`: 笔记数据模型
- `note_service.dart`: 笔记数据服务
- `srs_service.dart`: 间隔重复算法服务
- `study_page.dart`: 学习页面
- `review_page.dart`: 复习页面
- `notes_page.dart`: 笔记管理页面
- `stats_page.dart`: 统计页面
- `settings_page.dart`: 设置页面
- `ai/`: AI生成问题相关功能

## 贡献

欢迎查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何为项目做贡献。

## 许可证

本项目仅供学习交流使用。