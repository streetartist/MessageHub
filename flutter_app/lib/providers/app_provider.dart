import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // 本地存储键名
  static const String _keyServerUrl = 'server_url';
  static const String _keySettingsCache = 'settings_cache';

  // 状态
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  Stats? _stats;
  List<MonitoredChat> _monitoredChats = [];
  List<Friend> _friends = [];
  List<Group> _groups = [];
  List<AISummary> _summaries = [];
  List<Task> _tasks = [];
  List<AutoJob> _autoJobs = [];
  Settings? _settings;

  // 初始化完成的 Future
  late final Future<void> _initFuture;

  // Getters
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  Stats? get stats => _stats;
  List<MonitoredChat> get monitoredChats => _monitoredChats;
  List<Friend> get friends => _friends;
  List<Group> get groups => _groups;
  List<AISummary> get summaries => _summaries;
  List<Task> get tasks => _tasks;
  List<AutoJob> get autoJobs => _autoJobs;
  Settings? get settings => _settings;
  ApiService get api => _api;

  AppProvider() {
    _initFuture = _loadLocalData();
  }

  /// 等待初始化完成
  Future<void> ensureInitialized() => _initFuture;

  /// 加载本地缓存的数据（服务器地址和设置）
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载服务器地址
    final url = prefs.getString(_keyServerUrl) ?? 'http://localhost:5000';
    _api.setBaseUrl(url);

    // 加载本地缓存的设置
    final settingsJson = prefs.getString(_keySettingsCache);
    if (settingsJson != null) {
      try {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = Settings.fromJson(settingsMap);
      } catch (e) {
        // 解析失败，忽略缓存
        debugPrint('加载本地设置缓存失败: $e');
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// 保存设置到本地缓存
  Future<void> _saveSettingsToLocal(Settings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = jsonEncode(settings.toJson());
    await prefs.setString(_keySettingsCache, settingsJson);
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
    _api.setBaseUrl(url);
    notifyListeners();
  }

  String get serverUrl => _api.baseUrl;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== 统计 ====================

  Future<void> loadStats() async {
    try {
      _setLoading(true);
      _stats = await _api.getStats();
      _setError(null);
    } catch (e) {
      _setError('加载统计失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ==================== 聊天管理 ====================

  Future<void> loadMonitoredChats() async {
    try {
      _setLoading(true);
      _monitoredChats = await _api.getMonitoredChats();
      _setError(null);
    } catch (e) {
      _setError('加载监控聊天失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAvailableChats() async {
    try {
      _setLoading(true);
      final data = await _api.getAvailableChats();
      _friends = data['friends'] as List<Friend>;
      _groups = data['groups'] as List<Group>;
      _setError(null);
    } catch (e) {
      _setError('加载可用聊天失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addMonitoredChat({
    required int chatType,
    required String peerId,
    String? peerUid,
    required String name,
  }) async {
    try {
      _setLoading(true);
      await _api.addMonitoredChat(
        chatType: chatType,
        peerId: peerId,
        peerUid: peerUid,
        name: name,
      );
      await loadMonitoredChats();
      return true;
    } catch (e) {
      _setError('添加监控失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> removeMonitoredChat(int chatId) async {
    try {
      await _api.removeMonitoredChat(chatId);
      _monitoredChats.removeWhere((c) => c.id == chatId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('移除监控失败: $e');
      return false;
    }
  }

  Future<bool> toggleMonitoredChat(int chatId) async {
    try {
      final enabled = await _api.toggleMonitoredChat(chatId);
      final index = _monitoredChats.indexWhere((c) => c.id == chatId);
      if (index != -1) {
        await loadMonitoredChats();
      }
      return enabled;
    } catch (e) {
      _setError('切换状态失败: $e');
      return false;
    }
  }

  // ==================== AI总结 ====================

  Future<void> loadSummaries({
    int? chatId,
    String? startDate,
    String? endDate,
  }) async {
    try {
      _setLoading(true);
      _summaries = await _api.getSummaries(
        chatId: chatId,
        startDate: startDate,
        endDate: endDate,
      );
      _setError(null);
    } catch (e) {
      _setError('加载总结失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> generateSummary(
    int chatId, {
    int? days,
    String? startDate,
    String? endDate,
  }) async {
    try {
      _setLoading(true);
      final summary = await _api.generateSummary(
        chatId,
        days: days,
        startDate: startDate,
        endDate: endDate,
      );
      await loadSummaries();
      return summary;
    } catch (e) {
      _setError('生成总结失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteSummary(int summaryId) async {
    try {
      await _api.deleteSummary(summaryId);
      _summaries.removeWhere((s) => s.id == summaryId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除总结失败: $e');
      return false;
    }
  }

  // ==================== 任务 ====================

  Future<void> loadTasks({String? status}) async {
    try {
      _setLoading(true);
      _tasks = await _api.getTasks(status: status);
      _setError(null);
    } catch (e) {
      _setError('加载任务失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateTask(int taskId, Map<String, dynamic> updates) async {
    try {
      await _api.updateTask(taskId, updates);
      await loadTasks();
      return true;
    } catch (e) {
      _setError('更新任务失败: $e');
      return false;
    }
  }

  Future<bool> deleteTask(int taskId) async {
    try {
      await _api.deleteTask(taskId);
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除任务失败: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> analyzeTasks(int chatId,
      {int days = 7, bool force = false}) async {
    try {
      _setLoading(true);
      final result = await _api.analyzeTasks(chatId, days: days, force: force);
      await loadTasks();
      return result;
    } catch (e) {
      _setError('分析任务失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== 自动任务 ====================

  Future<void> loadAutoJobs() async {
    try {
      _setLoading(true);
      _autoJobs = await _api.getAutoJobs();
      _setError(null);
    } catch (e) {
      _setError('加载自动任务失败: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createAutoJob(Map<String, dynamic> jobData) async {
    try {
      _setLoading(true);
      await _api.createAutoJob(jobData);
      await loadAutoJobs();
      return true;
    } catch (e) {
      _setError('创建自动任务失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateAutoJob(int jobId, Map<String, dynamic> updates) async {
    try {
      await _api.updateAutoJob(jobId, updates);
      await loadAutoJobs();
      return true;
    } catch (e) {
      _setError('更新自动任务失败: $e');
      return false;
    }
  }

  Future<bool> deleteAutoJob(int jobId) async {
    try {
      await _api.deleteAutoJob(jobId);
      _autoJobs.removeWhere((j) => j.id == jobId);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('删除自动任务失败: $e');
      return false;
    }
  }

  Future<bool> toggleAutoJob(int jobId) async {
    try {
      await _api.toggleAutoJob(jobId);
      await loadAutoJobs();
      return true;
    } catch (e) {
      _setError('切换状态失败: $e');
      return false;
    }
  }

  Future<bool> runAutoJob(int jobId) async {
    try {
      _setLoading(true);
      await _api.runAutoJob(jobId);
      await loadAutoJobs();
      return true;
    } catch (e) {
      _setError('执行任务失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ==================== 设置 ====================

  Future<void> loadSettings() async {
    try {
      _setLoading(true);
      final serverSettings = await _api.getSettings();

      // 如果服务器返回的 API key 是 ***，保留本地缓存的真实值
      Settings finalSettings = serverSettings;
      if (serverSettings.aiApiKey == '***' && _settings != null && _settings!.aiApiKey != '***') {
        finalSettings = Settings(
          aiEndpoint: serverSettings.aiEndpoint,
          aiApiKey: _settings!.aiApiKey, // 保留本地缓存的真实 API key
          aiModel: serverSettings.aiModel,
          fetchDays: serverSettings.fetchDays,
          napcatHost: serverSettings.napcatHost,
          napcatPort: serverSettings.napcatPort,
        );
      }

      _settings = finalSettings;
      // 成功从服务器加载后，更新本地缓存（保留真实的 API key）
      await _saveSettingsToLocal(finalSettings);
      _setError(null);
    } catch (e) {
      // 服务器加载失败时，如果本地有缓存则使用本地缓存
      if (_settings != null) {
        _setError(null); // 有本地缓存，不显示错误
      } else {
        _setError('加载设置失败: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateSettings(Settings settings) async {
    try {
      _setLoading(true);
      await _api.updateSettings(settings);
      _settings = settings;
      // 同时保存到本地缓存，确保跨版本更新不丢失
      await _saveSettingsToLocal(settings);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('保存设置失败: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> testAiConnection() async {
    try {
      return await _api.testAiConnection();
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> testNapcatConnection() async {
    try {
      return await _api.testNapcatConnection();
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> fetchMessages() async {
    try {
      _setLoading(true);
      final result = await _api.fetchMessages();
      _setError(null);
      return result;
    } catch (e) {
      _setError('获取消息失败: $e');
      return {'success': false, 'error': e.toString()};
    } finally {
      _setLoading(false);
    }
  }
}
