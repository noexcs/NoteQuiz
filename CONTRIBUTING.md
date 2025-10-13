# 贡献指南

感谢您对学习助手项目的关注！我们欢迎任何形式的贡献，无论大小。

## 技术栈要求

要为此项目做贡献，您需要熟悉以下技术：

- [Flutter框架](https://flutter.dev/)
- [Dart语言](https://dart.dev/)
- 移动应用开发基础知识
- Git 版本控制

## 项目结构

```
lib/
├── ai/                 # AI相关功能
├── main.dart           # 应用入口
├── note.dart           # 笔记数据模型
├── note_service.dart   # 笔记服务
├── srs_service.dart    # 间隔重复算法服务
├── study_page.dart     # 学习页面
├── review_page.dart    # 复习页面
├── notes_page.dart     # 笔记管理页面
├── stats_page.dart     # 统计页面
├── settings_page.dart  # 设置页面
└── ...
```

## 如何贡献

### 提交 Issue

如果您发现了 bug 或有功能建议，请查看已有的 issue，如果没有类似的 issue，欢迎提交新 issue。

### 提交 Pull Request

1. Fork 此仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 开发环境搭建

1. 安装 Flutter SDK
2. Fork 并克隆项目
3. 运行 `flutter pub get` 安装依赖
4. 运行 `flutter run` 启动应用

## 编码规范

- 遵循 Flutter 官方编码规范
- 使用有意义的变量和函数命名
- 添加必要的注释说明复杂逻辑
- 保持代码整洁和一致性

## 需要帮助的领域

我们特别需要在以下领域的帮助：

- **AI功能增强**：优化AI生成问题的质量和多样性
- **UI/UX改进**：提升用户体验和界面美观度
- **SRS算法优化**：改进间隔重复算法的效果
- **数据可视化**：丰富统计页面的图表展示
- **性能优化**：提高应用响应速度和流畅度
- **测试覆盖**：增加单元测试和集成测试

## 社区和沟通

如有任何疑问，请通过以下方式联系我们：

- 在 GitHub Issues 中提问
- 发送邮件至项目维护者邮箱

再次感谢您的关注和潜在贡献！