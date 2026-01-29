import 'package:dio/dio.dart';
import '../models/models.dart';

class ApiService {
  late Dio _dio;
  String _baseUrl = 'http://YOUR_SERVER_IP:5000';

  ApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  String get baseUrl => _baseUrl;

  // ==================== 统计 API ====================

  Future<Stats> getStats() async {
    final response = await _dio.get('$_baseUrl/api/stats');
    return Stats.fromJson(response.data);
  }

  // ==================== 聊天管理 API ====================

  Future<Map<String, dynamic>> getAvailableChats() async {
    final response = await _dio.get('$_baseUrl/api/available-chats');
    final data = response.data;

    // 检查 API 是否返回错误
    if (data['success'] == false) {
      throw Exception(data['error'] ?? '获取聊天列表失败');
    }

    return {
      'friends':
          (data['friends'] as List? ?? []).map((e) => Friend.fromJson(e)).toList(),
      'groups':
          (data['groups'] as List? ?? []).map((e) => Group.fromJson(e)).toList(),
    };
  }

  Future<List<MonitoredChat>> getMonitoredChats() async {
    final response = await _dio.get('$_baseUrl/api/monitored-chats');
    return (response.data['chats'] as List)
        .map((e) => MonitoredChat.fromJson(e))
        .toList();
  }

  Future<int> addMonitoredChat({
    required int chatType,
    required String peerId,
    String? peerUid,
    required String name,
  }) async {
    final response = await _dio.post('$_baseUrl/api/monitored-chats', data: {
      'chat_type': chatType,
      'peer_id': peerId,
      'peer_uid': peerUid,
      'name': name,
    });
    final data = response.data;
    if (data['success'] == false) {
      throw Exception(data['error'] ?? '添加监控失败');
    }
    return data['id'];
  }

  Future<void> removeMonitoredChat(int chatId) async {
    await _dio.delete('$_baseUrl/api/monitored-chats/$chatId');
  }

  Future<bool> toggleMonitoredChat(int chatId) async {
    final response =
        await _dio.post('$_baseUrl/api/monitored-chats/$chatId/toggle');
    return response.data['enabled'];
  }

  // ==================== 消息 API ====================

  Future<MessagesResponse> getMessages(
    int chatId, {
    int page = 1,
    int perPage = 50,
    String? keyword,
    String? date,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (keyword != null && keyword.isNotEmpty) {
      params['keyword'] = keyword;
    }
    if (date != null && date.isNotEmpty) {
      params['date'] = date;
    }
    final response = await _dio.get(
      '$_baseUrl/api/messages/$chatId',
      queryParameters: params,
    );
    return MessagesResponse.fromJson(response.data);
  }

  Future<MessageStats> getMessageStats(int chatId) async {
    final response = await _dio.get('$_baseUrl/api/messages/$chatId/stats');
    return MessageStats.fromJson(response.data);
  }

  Future<Map<String, dynamic>> fetchMessages() async {
    final response = await _dio.post('$_baseUrl/api/fetch-messages');
    return response.data;
  }

  // ==================== AI总结 API ====================

  Future<List<AISummary>> getSummaries({
    int? chatId,
    String? startDate,
    String? endDate,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (chatId != null) {
      params['chat_id'] = chatId;
    }
    if (startDate != null) {
      params['start_date'] = startDate;
    }
    if (endDate != null) {
      params['end_date'] = endDate;
    }
    final response = await _dio.get(
      '$_baseUrl/api/summaries',
      queryParameters: params,
    );
    return (response.data['summaries'] as List)
        .map((e) => AISummary.fromJson(e))
        .toList();
  }

  Future<String> generateSummary(
    int chatId, {
    int? days,
    String? startDate,
    String? endDate,
  }) async {
    final data = <String, dynamic>{'chat_id': chatId};
    if (startDate != null && endDate != null) {
      data['start_date'] = startDate;
      data['end_date'] = endDate;
    } else if (days != null) {
      data['days'] = days;
    } else {
      data['days'] = 7; // 默认7天
    }
    final response = await _dio.post('$_baseUrl/api/generate-summary', data: data);
    return response.data['summary'] ?? '';
  }

  Future<void> deleteSummary(int summaryId) async {
    await _dio.delete('$_baseUrl/api/summaries/$summaryId');
  }

  // ==================== 任务 API ====================

  Future<List<Task>> getTasks({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) {
      params['status'] = status;
    }
    final response = await _dio.get(
      '$_baseUrl/api/tasks',
      queryParameters: params,
    );
    return (response.data['tasks'] as List)
        .map((e) => Task.fromJson(e))
        .toList();
  }

  Future<void> updateTask(int taskId, Map<String, dynamic> updates) async {
    await _dio.put('$_baseUrl/api/tasks/$taskId', data: updates);
  }

  Future<void> deleteTask(int taskId) async {
    await _dio.delete('$_baseUrl/api/tasks/$taskId');
  }

  Future<Map<String, dynamic>> analyzeTasks(int chatId,
      {int days = 7, bool force = false}) async {
    final response = await _dio.post('$_baseUrl/api/analyze-tasks', data: {
      'chat_id': chatId,
      'days': days,
      'force': force,
    });
    return response.data;
  }

  // ==================== 日程 API ====================

  Future<List<CalendarEvent>> getScheduleEvents({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _dio.get(
      '$_baseUrl/api/schedule/events',
      queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      },
    );
    return (response.data as List)
        .map((e) => CalendarEvent.fromJson(e))
        .toList();
  }

  // ==================== 自动任务 API ====================

  Future<List<AutoJob>> getAutoJobs() async {
    final response = await _dio.get('$_baseUrl/api/auto-jobs');
    return (response.data['jobs'] as List)
        .map((e) => AutoJob.fromJson(e))
        .toList();
  }

  Future<int> createAutoJob(Map<String, dynamic> jobData) async {
    final response = await _dio.post('$_baseUrl/api/auto-jobs', data: jobData);
    return response.data['id'];
  }

  Future<void> updateAutoJob(int jobId, Map<String, dynamic> updates) async {
    await _dio.put('$_baseUrl/api/auto-jobs/$jobId', data: updates);
  }

  Future<void> deleteAutoJob(int jobId) async {
    await _dio.delete('$_baseUrl/api/auto-jobs/$jobId');
  }

  Future<bool> toggleAutoJob(int jobId) async {
    final response = await _dio.post('$_baseUrl/api/auto-jobs/$jobId/toggle');
    return response.data['enabled'];
  }

  Future<void> runAutoJob(int jobId) async {
    await _dio.post('$_baseUrl/api/auto-jobs/$jobId/run');
  }

  // ==================== 设置 API ====================

  Future<Settings> getSettings() async {
    final response = await _dio.get('$_baseUrl/api/settings');
    return Settings.fromJson(response.data);
  }

  Future<void> updateSettings(Settings settings) async {
    await _dio.post('$_baseUrl/api/settings', data: settings.toJson());
  }

  Future<Map<String, dynamic>> testAiConnection() async {
    final response = await _dio.post('$_baseUrl/api/settings/test-ai');
    return response.data;
  }

  Future<Map<String, dynamic>> testNapcatConnection() async {
    final response = await _dio.post('$_baseUrl/api/settings/test-napcat');
    return response.data;
  }

  Future<Map<String, dynamic>> getTokenStatus() async {
    final response = await _dio.get('$_baseUrl/api/settings/token-status');
    return response.data;
  }
}
