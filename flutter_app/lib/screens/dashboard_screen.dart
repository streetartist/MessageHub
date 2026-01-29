import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  /// 公开的刷新方法，供外部调用
  void refresh() => _loadAllData();

  Future<void> _loadAllData() async {
    final provider = context.read<AppProvider>();
    // 等待初始化完成（服务器地址加载完成）
    await provider.ensureInitialized();
    await Future.wait([
      provider.loadStats(),
      provider.loadMonitoredChats(),
      provider.loadTasks(status: 'pending'),
      provider.loadSummaries(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('仪表盘'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.stats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = provider.stats;
          if (stats == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(provider.error ?? '无法加载数据'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadStats(),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAllData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 统计卡片行
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        context,
                        icon: Icons.chat_bubble_outline,
                        title: '监控聊天',
                        value: stats.chatsCount.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniStatCard(
                        context,
                        icon: Icons.message_outlined,
                        title: '消息总数',
                        value: stats.messagesCount.toString(),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStatCard(
                        context,
                        icon: Icons.task_alt_outlined,
                        title: '待办任务',
                        value: stats.pendingTasksCount.toString(),
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMiniStatCard(
                        context,
                        icon: Icons.summarize_outlined,
                        title: 'AI总结',
                        value: stats.summariesCount.toString(),
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildQuickActions(context, provider),
                const SizedBox(height: 20),
                _buildPendingTasksSection(context, provider),
                const SizedBox(height: 20),
                _buildRecentSummariesSection(context, provider),
                const SizedBox(height: 20),
                _buildMonitoredChatsSection(context, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '快捷操作',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.download,
                  label: '获取消息',
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('正在获取消息...')),
                    );
                    final result = await provider.fetchMessages();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      final message = result['success'] == true
                          ? result['message'] ?? '获取完成'
                          : result['error'] ?? '获取失败';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                      _loadAllData();
                    }
                  },
                ),
                _buildActionButton(
                  context,
                  icon: Icons.auto_awesome,
                  label: 'AI提取任务',
                  color: Colors.green,
                  onPressed: () => _analyzeAllTasks(context, provider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyzeAllTasks(BuildContext context, AppProvider provider) async {
    final enabledChats = provider.monitoredChats.where((c) => c.enabled).toList();
    if (enabledChats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有启用的监控聊天')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在分析 ${enabledChats.length} 个聊天的任务...')),
    );

    int totalTasks = 0;
    for (final chat in enabledChats) {
      final result = await provider.analyzeTasks(chat.id, days: 7);
      if (result != null) {
        totalTasks += (result['tasks_count'] ?? 0) as int;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(totalTasks > 0
              ? '分析完成！从 ${enabledChats.length} 个聊天中提取了 $totalTasks 个任务'
              : '分析完成，未发现新任务'),
        ),
      );
      _loadAllData();
    }
  }

  Widget _buildPendingTasksSection(BuildContext context, AppProvider provider) {
    final tasks = provider.tasks.take(5).toList();
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '待办任务',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call(3),
                  child: const Text('查看全部'),
                ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无待办任务', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskItem(task);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    final priorityColors = {
      1: Colors.red,
      2: Colors.orange,
      3: Colors.yellow.shade700,
      4: Colors.blue,
      5: Colors.grey,
    };
    return ListTile(
      dense: true,
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        task.deadline != null
            ? '截止: ${DateFormat('MM-dd HH:mm').format(task.deadline!)}'
            : '无截止时间',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: priorityColors[task.priority]?.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'P${task.priority}',
          style: TextStyle(
            color: priorityColors[task.priority],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSummariesSection(BuildContext context, AppProvider provider) {
    final summaries = provider.summaries.take(3).toList();
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近总结',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call(2),
                  child: const Text('查看全部'),
                ),
              ],
            ),
          ),
          if (summaries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无AI总结', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summaries.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final summary = summaries[index];
                return _buildSummaryItem(summary);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(AISummary summary) {
    return ListTile(
      dense: true,
      title: Text(
        summary.summaryText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('yyyy-MM-dd HH:mm').format(summary.createdAt),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          summary.summaryType,
          style: const TextStyle(
            color: Colors.purple,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildMonitoredChatsSection(BuildContext context, AppProvider provider) {
    final chats = provider.monitoredChats;
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '监控的聊天',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call(1),
                  child: const Text('管理'),
                ),
              ],
            ),
          ),
          if (chats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无监控的聊天', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: chats.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _buildChatItem(chat);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChatItem(MonitoredChat chat) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: chat.chatType == 1 ? Colors.blue : Colors.green,
        child: Icon(
          chat.chatType == 1 ? Icons.person : Icons.group,
          color: Colors.white,
          size: 16,
        ),
      ),
      title: Text(chat.name),
      subtitle: Text(
        chat.lastFetchTime != null
            ? '更新: ${DateFormat('MM-dd HH:mm').format(chat.lastFetchTime!)}'
            : '未获取',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: chat.enabled
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          chat.enabled ? '启用' : '禁用',
          style: TextStyle(
            color: chat.enabled ? Colors.green : Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
      ),
    );
  }
}
