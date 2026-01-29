import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _aiEndpointController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _napcatHostController = TextEditingController();
  final _napcatPortController = TextEditingController();
  final _fetchDaysController = TextEditingController();

  bool _isLoading = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  /// 公开的刷新方法，供外部调用
  void refresh() => _loadSettings();

  @override
  void dispose() {
    _serverUrlController.dispose();
    _aiEndpointController.dispose();
    _aiApiKeyController.dispose();
    _aiModelController.dispose();
    _napcatHostController.dispose();
    _napcatPortController.dispose();
    _fetchDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final provider = context.read<AppProvider>();
    await provider.ensureInitialized();
    _serverUrlController.text = provider.serverUrl;

    // 先从本地缓存加载设置（如果有的话）
    _applySettings(provider.settings);

    // 尝试从服务器获取最新设置，失败时不阻塞界面
    try {
      await provider.loadSettings();
      // 应用服务器返回的设置
      _applySettings(provider.settings);
    } catch (e) {
      // 服务器连接失败，使用默认值，用户可以手动配置
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法连接服务器，请先配置服务器地址')),
        );
      }
    }
  }

  void _applySettings(Settings? settings) {
    if (settings != null) {
      _aiEndpointController.text = settings.aiEndpoint;
      // 不要用服务器返回的 *** 覆盖本地缓存的真实 API key
      if (settings.aiApiKey.isNotEmpty && settings.aiApiKey != '***') {
        _aiApiKeyController.text = settings.aiApiKey;
      }
      _aiModelController.text = settings.aiModel;
      _napcatHostController.text = settings.napcatHost;
      _napcatPortController.text = settings.napcatPort.toString();
      _fetchDaysController.text = settings.fetchDays.toString();
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppProvider>();

    // 保存服务器URL
    await provider.setServerUrl(_serverUrlController.text);

    // 保存其他设置
    final settings = Settings(
      aiEndpoint: _aiEndpointController.text,
      aiApiKey: _aiApiKeyController.text,
      aiModel: _aiModelController.text,
      napcatHost: _napcatHostController.text,
      napcatPort: int.tryParse(_napcatPortController.text) ?? 40653,
      fetchDays: int.tryParse(_fetchDaysController.text) ?? 1,
    );

    final success = await provider.updateSettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '设置已保存' : '保存失败')),
      );
    }
  }

  Future<void> _testAiConnection() async {
    setState(() => _isLoading = true);
    final result = await context.read<AppProvider>().testAiConnection();
    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] == true ? '连接成功' : '连接失败'),
          content: Text(result['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _testNapcatConnection() async {
    setState(() => _isLoading = true);
    final result = await context.read<AppProvider>().testNapcatConnection();
    setState(() => _isLoading = false);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] == true ? '连接成功' : '连接失败'),
          content: Text(result['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 服务器设置
                  _buildSectionHeader('服务器设置'),
                  TextFormField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      labelText: '服务器地址',
                      hintText: 'http://localhost:5000',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入服务器地址';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // AI设置
                  _buildSectionHeader('AI设置'),
                  TextFormField(
                    controller: _aiEndpointController,
                    decoration: const InputDecoration(
                      labelText: 'AI API端点',
                      hintText: 'https://api.deepseek.com/v1/chat/completions',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aiApiKeyController,
                    obscureText: _obscureApiKey,
                    decoration: InputDecoration(
                      labelText: 'API密钥',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscureApiKey = !_obscureApiKey);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aiModelController,
                    decoration: const InputDecoration(
                      labelText: '模型名称',
                      hintText: 'deepseek-chat',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testAiConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('测试AI连接'),
                  ),
                  const SizedBox(height: 24),

                  // NapCat设置
                  _buildSectionHeader('NapCat设置'),
                  TextFormField(
                    controller: _napcatHostController,
                    decoration: const InputDecoration(
                      labelText: '主机地址',
                      hintText: 'localhost',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _napcatPortController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '端口',
                      hintText: '40653',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _testNapcatConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('测试NapCat连接'),
                  ),
                  const SizedBox(height: 24),

                  // 其他设置
                  _buildSectionHeader('其他设置'),
                  TextFormField(
                    controller: _fetchDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '默认获取天数',
                      hintText: '1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('保存设置'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
