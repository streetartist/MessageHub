class AppConstants {
  static const String appName = 'NapCat助手';

  // 默认服务器地址，用户可在设置中修改
  static const String defaultServerUrl = 'http://YOUR_SERVER_IP:5000';

  // 任务状态
  static const Map<String, String> taskStatusLabels = {
    'pending': '待处理',
    'in_progress': '进行中',
    'completed': '已完成',
  };

  // 任务类型
  static const Map<String, String> jobTypeLabels = {
    'fetch_messages': '获取消息',
    'ai_summary': 'AI总结',
    'extract_tasks': '提取任务',
  };

  // 优先级颜色
  static const Map<int, int> priorityColors = {
    1: 0xFFF44336, // Red
    2: 0xFFFF9800, // Orange
    3: 0xFFFFC107, // Yellow
    4: 0xFF2196F3, // Blue
    5: 0xFF9E9E9E, // Grey
  };
}
