import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

class SettingsPage extends StatefulWidget {
  final Function(String, [MaterialColor])? onThemeChanged;
  final MaterialColor? currentSwatch;
  
  const SettingsPage({super.key, this.onThemeChanged, this.currentSwatch});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late String _currentTheme;
  late MaterialColor _currentSwatch;
  
  static const String _defaultBaseUrl = 'https://api.deepseek.com';
  static const String _defaultModel = 'deepseek-chat';
  static const String _defaultTheme = 'dark';
  
  // 预定义的颜色选项
  static final List<MaterialColor> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _currentTheme = _defaultTheme;
    _currentSwatch = widget.currentSwatch ?? Colors.blue;
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
      
      // 加载自定义主题色
      final primarySwatchValue = prefs.getInt('primary_swatch') ?? Colors.blue.value;
      _currentSwatch = MaterialColor(primarySwatchValue, _buildColorSwatch(primarySwatchValue));
    });
  }
  
  // 构建颜色色阶
  Map<int, Color> _buildColorSwatch(int color) {
    final colors = <int, Color>{};
    final baseColor = Color(color);
    
    for (int i = 50; i <= 900; i += 100) {
      colors[i] = baseColor.withOpacity(1 - (i / 1000));
    }
    colors[500] = baseColor; // 主色
    
    return colors;
  }
  
  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('api_base_url', _baseUrlController.text);
      await prefs.setString('api_key', _apiKeyController.text);
      await prefs.setString('api_model', _modelController.text);
      await prefs.setString('app_theme', _currentTheme);
      await prefs.setInt('primary_swatch', _currentSwatch.value);
      
      // 通知主应用更新主题
      widget.onThemeChanged?.call(_currentTheme, _currentSwatch);
      
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
    await prefs.setInt('primary_swatch', _currentSwatch.value);
    setState(() {
      _currentTheme = theme;
    });
    
    // 通知主应用更新主题
    widget.onThemeChanged?.call(theme, _currentSwatch);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('主题已保存')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section with decorative elements
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.settings,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '系统设置',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '配置应用程序的各项参数',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // AI API Settings Section
              Text(
                'AI API 设置',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Base URL Field
              TextFormField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: '例如: https://api.openai.com/v1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Base URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // API Key Field
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: '请输入您的 API 密钥',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
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
              
              // Model Field
              TextFormField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model',
                  hintText: '例如: gpt-3.5-turbo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 Model';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Theme Settings Section
              Text(
                '主题设置',
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Theme Selection Cards
              Row(
                children: [
                  Expanded(
                    child: Card(
                      color: _currentTheme == 'light' 
                        ? colorScheme.primaryContainer 
                        : colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => _saveTheme('light'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.light_mode,
                                size: 32,
                                color: _currentTheme == 'light' 
                                  ? colorScheme.onPrimaryContainer 
                                  : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '浅色模式',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _currentTheme == 'light' 
                                    ? colorScheme.onPrimaryContainer 
                                    : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      color: _currentTheme == 'dark' 
                        ? colorScheme.primaryContainer 
                        : colorScheme.surfaceVariant,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => _saveTheme('dark'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.dark_mode,
                                size: 32,
                                color: _currentTheme == 'dark' 
                                  ? colorScheme.onPrimaryContainer 
                                  : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '深色模式',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _currentTheme == 'dark' 
                                    ? colorScheme.onPrimaryContainer 
                                    : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Color Selection Section
              Text(
                '主题颜色',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Color Selection Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 10,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _colorOptions.length,
                itemBuilder: (context, index) {
                  final color = _colorOptions[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentSwatch = color;
                      });
                      // 立即应用颜色变化
                      widget.onThemeChanged?.call(_currentTheme, _currentSwatch);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: _currentSwatch == color
                            ? Border.all(
                                color: colorScheme.onSurface,
                                width: 2,
                              )
                            : null,
                      ),
                      child: _currentSwatch == color
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveSettings,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '保存设置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}