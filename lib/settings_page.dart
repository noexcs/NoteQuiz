import 'dart:convert';
import 'package:bd4/ai/ai_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  String name;
  String baseUrl;
  String apiKey;
  String model;

  ApiConfig({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'model': model,
    };
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      name: json['name'] ?? '默认配置',
      baseUrl: json['baseUrl'] ?? 'https://api.deepseek.com',
      apiKey: json['apiKey'] ?? '',
      model: json['model'] ?? 'deepseek-chat',
    );
  }
}

class SettingsPage extends StatefulWidget {
  final Function(String, [MaterialColor?]) onThemeChanged;
  final MaterialColor currentSwatch;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
    required this.currentSwatch,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();

  // Theme state
  String _currentThemeMode = 'dark';

  // API Settings Controllers
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _modelController;
  late TextEditingController _configNameController;

  // Multi-API configs
  List<ApiConfig> _apiConfigs = [];
  int _currentConfigIndex = 0;

  // Prompt Settings Controllers
  late TextEditingController _questionSystemPromptController;
  late TextEditingController _questionUserPromptController;
  late TextEditingController _contentSystemPromptController;
  late TextEditingController _contentUserPromptController;

  final List<MaterialColor> _colorOptions = [
    Colors.blue, Colors.indigo, Colors.purple, Colors.teal, 
    Colors.green, Colors.amber, Colors.deepOrange, Colors.red, Colors.pink,
    Colors.cyan, Colors.lime, Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _configNameController = TextEditingController();
    _questionSystemPromptController = TextEditingController();
    _questionUserPromptController = TextEditingController();
    _contentSystemPromptController = TextEditingController();
    _contentUserPromptController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _configNameController.dispose();
    _questionSystemPromptController.dispose();
    _questionUserPromptController.dispose();
    _contentSystemPromptController.dispose();
    _contentUserPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentThemeMode = prefs.getString('app_theme') ?? 'light';

      // Load API configs
      final configsString = prefs.getString('api_configs');
      if (configsString != null) {
        final List<dynamic> configsJson = jsonDecode(configsString);
        _apiConfigs = configsJson
            .map((config) => ApiConfig.fromJson(config as Map<String, dynamic>))
            .toList();
      } else {
        // Load default config if no configs exist
        _apiConfigs = [
          ApiConfig(
            name: '默认配置',
            baseUrl: prefs.getString('api_base_url') ?? 'https://api.deepseek.com',
            apiKey: prefs.getString('api_key') ?? '',
            model: prefs.getString('api_model') ?? 'deepseek-chat',
          )
        ];
      }

      // Get current config index
      _currentConfigIndex = prefs.getInt('current_api_config_index') ?? 0;
      if (_currentConfigIndex >= _apiConfigs.length) {
        _currentConfigIndex = 0;
      }

      // Load current config into controllers
      final currentConfig = _apiConfigs[_currentConfigIndex];
      _configNameController.text = currentConfig.name;
      _baseUrlController.text = currentConfig.baseUrl;
      _apiKeyController.text = currentConfig.apiKey;
      _modelController.text = currentConfig.model;

      _questionSystemPromptController.text = prefs.getString('question_system_prompt') ?? '';
      _questionUserPromptController.text = prefs.getString('question_user_prompt') ?? '';
      _contentSystemPromptController.text = prefs.getString('content_system_prompt') ?? '';
      _contentUserPromptController.text = prefs.getString('content_user_prompt') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      
      // Update current config with form values
      _apiConfigs[_currentConfigIndex] = ApiConfig(
        name: _configNameController.text,
        baseUrl: _baseUrlController.text,
        apiKey: _apiKeyController.text,
        model: _modelController.text,
      );

      // Save API configs
      final configsJson = _apiConfigs.map((config) => config.toJson()).toList();
      await prefs.setString('api_configs', jsonEncode(configsJson));
      await prefs.setInt('current_api_config_index', _currentConfigIndex);

      await prefs.setString('question_system_prompt', _questionSystemPromptController.text);
      await prefs.setString('question_user_prompt', _questionUserPromptController.text);
      await prefs.setString('content_system_prompt', _contentSystemPromptController.text);
      await prefs.setString('content_user_prompt', _contentUserPromptController.text);

      // Invalidate the cached settings in AIService
      await AIService().initialize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置已保存')),
        );
      }
    }
  }

  void _addNewConfig() {
    setState(() {
      _apiConfigs.add(ApiConfig(
        name: '新配置 ${_apiConfigs.length + 1}',
        baseUrl: 'https://api.deepseek.com',
        apiKey: '',
        model: 'deepseek-chat',
      ));
      _currentConfigIndex = _apiConfigs.length - 1;
      _updateConfigFormFields();
    });
  }

  void _deleteCurrentConfig() {
    if (_apiConfigs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('至少需要保留一个配置')),
      );
      return;
    }

    setState(() {
      _apiConfigs.removeAt(_currentConfigIndex);
      if (_currentConfigIndex >= _apiConfigs.length) {
        _currentConfigIndex = _apiConfigs.length - 1;
      }
      _updateConfigFormFields();
    });
  }

  void _switchToConfig(int index) {
    if (index != _currentConfigIndex) {
      setState(() {
        _currentConfigIndex = index;
        _updateConfigFormFields();
      });
    }
  }

  void _updateConfigFormFields() {
    final currentConfig = _apiConfigs[_currentConfigIndex];
    _configNameController.text = currentConfig.name;
    _baseUrlController.text = currentConfig.baseUrl;
    _apiKeyController.text = currentConfig.apiKey;
    _modelController.text = currentConfig.model;
  }

  Future<void> _updateThemeMode(String themeMode) async {
    if (themeMode == _currentThemeMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', themeMode);
    widget.onThemeChanged(themeMode);
    setState(() {
      _currentThemeMode = themeMode;
    });
  }

  Future<void> _updateSwatch(MaterialColor color) async {
    if (color.value == widget.currentSwatch.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('primary_swatch', color.value);
    widget.onThemeChanged(_currentThemeMode, color);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: '保存设置',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('AI API 设置', Icons.cloud_queue_outlined, colorScheme),
              const SizedBox(height: 16),
              _buildConfigSelector(),
              const SizedBox(height: 16),
              _buildTextFormField(_configNameController, '配置名称', '例如: 默认配置'),
              const SizedBox(height: 16),
              _buildTextFormField(_baseUrlController, 'Base URL', '例如: https://api.deepseek.com'),
              const SizedBox(height: 16),
              _buildTextFormField(_apiKeyController, 'API Key', '请输入您的 API 密钥', obscureText: true),
              const SizedBox(height: 16),
              _buildTextFormField(_modelController, 'Model', '例如: deepseek-chat'),
              const SizedBox(height: 16),
              _buildConfigManagementButtons(),
              const SizedBox(height: 24),
              _buildSectionHeader('AI 提示词设置', Icons.edit_note_outlined, colorScheme),
              const SizedBox(height: 16),
              _buildPromptExpansionTile('生成题目', _questionSystemPromptController, _questionUserPromptController, 'You are a professional education assistant...', 'Additional instructions...'),
              const SizedBox(height: 12),
              _buildPromptExpansionTile('生成笔记内容', _contentSystemPromptController, _contentUserPromptController, 'You are a professional note-taking assistant...', 'Additional instructions...'),
              const SizedBox(height: 24),
              _buildSectionHeader('主题设置', Icons.palette_outlined, colorScheme),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('应用主题'),
                trailing: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'light', label: Text('浅色'), icon: Icon(Icons.light_mode_outlined)),
                    ButtonSegment<String>(value: 'dark', label: Text('深色'), icon: Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {_currentThemeMode},
                  onSelectionChanged: (newSelection) => _updateThemeMode(newSelection.first),
                ),
              ),
              const SizedBox(height: 16),
              const ListTile(
                title: Text('主题颜色'),
              ),
              const SizedBox(height: 8),
              _buildColorPicker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.primary)),
      ],
    );
  }
  
  Widget _buildTextFormField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscureText = false,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        alignLabelWithHint: true,
      ),
      obscureText: obscureText,
      validator: (value) {
        if (['API Key', 'Model', 'Base URL'].contains(label)) {
           if (value == null || value.isEmpty) return '请输入 $label';
        }
        return null;
      },
    );
  }

  Widget _buildPromptExpansionTile(
    String title,
    TextEditingController systemController,
    TextEditingController userController,
    String systemHint,
    String userHint,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('系统提示词 (System Prompt)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildTextFormField(
            systemController,
            'System Prompt',
            systemHint,
            minLines: 3,
            maxLines: 8,
          ),
          const SizedBox(height: 16),
          Text('用户附加提示词 (User Prompt)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildTextFormField(
            userController,
            'User Prompt',
            userHint,
            minLines: 3,
            maxLines: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: _colorOptions.map((color) {
          final isSelected = widget.currentSwatch.value == color.value;
          return GestureDetector(
            onTap: () => _updateSwatch(color),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfigSelector() {
    return FormField<int>(
      builder: (FormFieldState<int> state) {
        return InputDecorator(
          decoration: InputDecoration(
            labelText: '当前配置',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _currentConfigIndex,
              isDense: true,
              onChanged: (int? newValue) {
                if (newValue != null) {
                  _switchToConfig(newValue);
                }
              },
              items: _apiConfigs.asMap().entries.map((entry) {
                int idx = entry.key;
                ApiConfig config = entry.value;
                return DropdownMenuItem<int>(
                  value: idx,
                  child: Text(config.name),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfigManagementButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: _addNewConfig,
          icon: const Icon(Icons.add),
          label: const Text('添加配置'),
        ),
        ElevatedButton.icon(
          onPressed: _deleteCurrentConfig,
          icon: const Icon(Icons.delete),
          label: const Text('删除配置'),
        ),
      ],
    );
  }
}
