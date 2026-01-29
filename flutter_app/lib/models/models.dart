// 统计数据模型
class Stats {
  final int chatsCount;
  final int messagesCount;
  final int pendingTasksCount;
  final int summariesCount;

  Stats({
    required this.chatsCount,
    required this.messagesCount,
    required this.pendingTasksCount,
    required this.summariesCount,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      chatsCount: json['chats_count'] ?? 0,
      messagesCount: json['messages_count'] ?? 0,
      pendingTasksCount: json['pending_tasks_count'] ?? 0,
      summariesCount: json['summaries_count'] ?? 0,
    );
  }
}

// 好友模型
class Friend {
  final String uin;
  final String uid;
  final String nick;
  final String? remark;
  final String? avatarUrl;

  Friend({
    required this.uin,
    required this.uid,
    required this.nick,
    this.remark,
    this.avatarUrl,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      uin: json['uin']?.toString() ?? '',
      uid: json['uid'] ?? '',
      nick: json['nick'] ?? '',
      remark: json['remark'],
      avatarUrl: json['avatar_url'],
    );
  }

  String get displayName => remark?.isNotEmpty == true ? remark! : nick;
}

// 群组模型
class Group {
  final String groupCode;
  final String groupName;
  final int memberCount;
  final String? avatarUrl;

  Group({
    required this.groupCode,
    required this.groupName,
    required this.memberCount,
    this.avatarUrl,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      groupCode: json['group_code']?.toString() ?? '',
      groupName: json['group_name'] ?? '',
      memberCount: json['member_count'] ?? 0,
      avatarUrl: json['avatar_url'],
    );
  }
}

// 监控聊天模型
class MonitoredChat {
  final int id;
  final int chatType;
  final String peerId;
  final String? peerUid;
  final String name;
  final bool enabled;
  final DateTime? lastFetchTime;
  final DateTime? createdAt;

  MonitoredChat({
    required this.id,
    required this.chatType,
    required this.peerId,
    this.peerUid,
    required this.name,
    required this.enabled,
    this.lastFetchTime,
    this.createdAt,
  });

  factory MonitoredChat.fromJson(Map<String, dynamic> json) {
    return MonitoredChat(
      id: json['id'],
      chatType: json['chat_type'],
      peerId: json['peer_id']?.toString() ?? '',
      peerUid: json['peer_uid'],
      name: json['name'] ?? '',
      enabled: json['enabled'] ?? true,
      lastFetchTime: json['last_fetch_time'] != null
          ? DateTime.parse(json['last_fetch_time'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  String get chatTypeText => chatType == 1 ? '私聊' : '群聊';
}

// 聊天消息模型
class ChatMessage {
  final int id;
  final int chatId;
  final String? msgId;
  final String senderName;
  final String? senderId;
  final String content;
  final DateTime msgTime;
  final bool aiProcessed;

  ChatMessage({
    required this.id,
    required this.chatId,
    this.msgId,
    required this.senderName,
    this.senderId,
    required this.content,
    required this.msgTime,
    required this.aiProcessed,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      chatId: json['chat_id'] ?? 0,
      msgId: json['msg_id'],
      senderName: json['sender_name'] ?? '',
      senderId: json['sender_id'],
      content: json['content'] ?? '',
      msgTime: DateTime.parse(json['msg_time']),
      aiProcessed: json['ai_processed'] ?? false,
    );
  }
}

// 消息分页响应
class MessagesResponse {
  final List<ChatMessage> messages;
  final int total;
  final int pages;
  final int currentPage;

  MessagesResponse({
    required this.messages,
    required this.total,
    required this.pages,
    required this.currentPage,
  });

  factory MessagesResponse.fromJson(Map<String, dynamic> json) {
    return MessagesResponse(
      messages: (json['messages'] as List)
          .map((e) => ChatMessage.fromJson(e))
          .toList(),
      total: json['total'] ?? 0,
      pages: json['pages'] ?? 0,
      currentPage: json['current_page'] ?? 1,
    );
  }
}

// 消息统计
class MessageStats {
  final int total;
  final int today;
  final int senders;
  final int days;

  MessageStats({
    required this.total,
    required this.today,
    required this.senders,
    required this.days,
  });

  factory MessageStats.fromJson(Map<String, dynamic> json) {
    return MessageStats(
      total: json['total'] ?? 0,
      today: json['today'] ?? 0,
      senders: json['senders'] ?? 0,
      days: json['days'] ?? 0,
    );
  }
}

// AI总结模型
class AISummary {
  final int id;
  final int? chatId;
  final String? chatName;
  final String summaryType;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final String summaryText;
  final DateTime createdAt;

  AISummary({
    required this.id,
    this.chatId,
    this.chatName,
    required this.summaryType,
    this.dateRangeStart,
    this.dateRangeEnd,
    required this.summaryText,
    required this.createdAt,
  });

  factory AISummary.fromJson(Map<String, dynamic> json) {
    return AISummary(
      id: json['id'],
      chatId: json['chat_id'],
      chatName: json['chat_name'],
      summaryType: json['summary_type'] ?? 'custom',
      dateRangeStart: json['date_range_start'] != null
          ? DateTime.parse(json['date_range_start'])
          : null,
      dateRangeEnd: json['date_range_end'] != null
          ? DateTime.parse(json['date_range_end'])
          : null,
      summaryText: json['summary_text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

// 任务模型
class Task {
  final int id;
  final int chatId;
  final String? chatName;
  final String title;
  final String? description;
  final int priority;
  final DateTime? deadline;
  final String status;
  final String? sourceMessage;
  final String? aiAnalysis;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.chatId,
    this.chatName,
    required this.title,
    this.description,
    required this.priority,
    this.deadline,
    required this.status,
    this.sourceMessage,
    this.aiAnalysis,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      chatId: json['chat_id'] ?? 0,
      chatName: json['chat_name'],
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 3,
      deadline:
          json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      status: json['status'] ?? 'pending',
      sourceMessage: json['source_message'],
      aiAnalysis: json['ai_analysis'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'title': title,
      'description': description,
      'priority': priority,
      'deadline': deadline?.toIso8601String(),
      'status': status,
    };
  }
}

// 自动任务模型
class AutoJob {
  final int id;
  final String name;
  final String jobType;
  final bool enabled;
  final String scheduleType;
  final int? intervalMinutes;
  final int? cronHour;
  final int? cronMinute;
  final int? chatId;
  final int days;
  final bool extractTasks;
  final DateTime? lastRunTime;
  final String? lastRunStatus;
  final String? lastRunMessage;

  AutoJob({
    required this.id,
    required this.name,
    required this.jobType,
    required this.enabled,
    required this.scheduleType,
    this.intervalMinutes,
    this.cronHour,
    this.cronMinute,
    this.chatId,
    required this.days,
    required this.extractTasks,
    this.lastRunTime,
    this.lastRunStatus,
    this.lastRunMessage,
  });

  factory AutoJob.fromJson(Map<String, dynamic> json) {
    return AutoJob(
      id: json['id'],
      name: json['name'] ?? '',
      jobType: json['job_type'] ?? '',
      enabled: json['enabled'] ?? false,
      scheduleType: json['schedule_type'] ?? 'interval',
      intervalMinutes: json['interval_minutes'],
      cronHour: json['cron_hour'],
      cronMinute: json['cron_minute'],
      chatId: json['chat_id'],
      days: json['days'] ?? 1,
      extractTasks: json['extract_tasks'] ?? false,
      lastRunTime: json['last_run_time'] != null
          ? DateTime.parse(json['last_run_time'])
          : null,
      lastRunStatus: json['last_run_status'],
      lastRunMessage: json['last_run_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'job_type': jobType,
      'enabled': enabled,
      'schedule_type': scheduleType,
      'interval_minutes': intervalMinutes,
      'cron_hour': cronHour,
      'cron_minute': cronMinute,
      'chat_id': chatId,
      'days': days,
      'extract_tasks': extractTasks,
    };
  }

  String get jobTypeText {
    switch (jobType) {
      case 'fetch_messages':
        return '获取消息';
      case 'ai_summary':
        return 'AI总结';
      case 'extract_tasks':
        return '提取任务';
      default:
        return jobType;
    }
  }

  String get scheduleText {
    if (scheduleType == 'interval') {
      return '每 $intervalMinutes 分钟';
    } else {
      return '每天 ${cronHour?.toString().padLeft(2, '0')}:${cronMinute?.toString().padLeft(2, '0')}';
    }
  }
}

// 设置模型
class Settings {
  final String aiEndpoint;
  final String aiApiKey;
  final String aiModel;
  final int fetchDays;
  final String napcatHost;
  final int napcatPort;

  Settings({
    required this.aiEndpoint,
    required this.aiApiKey,
    required this.aiModel,
    required this.fetchDays,
    required this.napcatHost,
    required this.napcatPort,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    // 处理空字符串的情况，使用默认值
    final host = json['napcat_host'];
    final endpoint = json['ai_endpoint'];
    final model = json['ai_model'];

    return Settings(
      aiEndpoint: (endpoint != null && endpoint.toString().isNotEmpty)
          ? endpoint : 'https://api.deepseek.com/v1/chat/completions',
      aiApiKey: json['ai_api_key'] ?? '',
      aiModel: (model != null && model.toString().isNotEmpty)
          ? model : 'deepseek-chat',
      fetchDays: json['fetch_days'] ?? 1,
      napcatHost: (host != null && host.toString().isNotEmpty)
          ? host : 'localhost',
      napcatPort: json['napcat_port'] ?? 40653,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ai_endpoint': aiEndpoint,
      'ai_api_key': aiApiKey,
      'ai_model': aiModel,
      'fetch_days': fetchDays,
      'napcat_host': napcatHost,
      'napcat_port': napcatPort,
    };
  }
}

// 日历事件模型
class CalendarEvent {
  final int id;
  final String title;
  final DateTime start;
  final int priority;
  final String status;
  final String? description;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.priority,
    required this.status,
    this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'],
      title: json['title'] ?? '',
      start: DateTime.parse(json['start']),
      priority: json['extendedProps']?['priority'] ?? 3,
      status: json['extendedProps']?['status'] ?? 'pending',
      description: json['extendedProps']?['description'],
    );
  }
}
