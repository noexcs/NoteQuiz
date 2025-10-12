import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final Function(String)? onThemeChanged;
  
  const SettingsPage({super.key, this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late String _currentTheme;
  
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';
  static const String _defaultTheme = 'dark';
  
  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _currentTheme = _defaultTheme;
    _loadSettings();
  }
  
  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _baseUrlController.text = prefs.getString('api_base_url') ?? _defaultBaseUrl;
      _apiKeyController.text = prefs.getString('api_key') ?? '';
      _modelController.text = prefs.getString('api_model') ?? _defaultModel;
      _currentTheme = prefs.getString('app_theme') ?? _defaultTheme;
    });
  }
  
  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _baseUrlController.text);
      await prefs.setString('api_key', _apiKeyController.text);
      await prefs.setString('api_model', _modelController.text);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    }
  }
  
  Future<void> _saveTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', theme);
    setState(() {
      _currentTheme = theme;
    });
    
    // 通知主应用更新主题
    widget.onThemeChanged?.call(theme);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题已保存')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI API 设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: '例如: https://api.openai.com/v1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Base URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '请输入您的 API 密钥',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 API Key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: '例如: gpt-3.5-turbo',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                '主题设置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: const Text('浅色模式'),
                    selected: _currentTheme == 'light',
                    onSelected: (selected) {
                      if (selected) {
                        _saveTheme('light');
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('深色模式'),
                    selected: _currentTheme == 'dark',
                    onSelected: (selected) {
                      if (selected) {
                        _saveTheme('dark');
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Text('保存设置'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}