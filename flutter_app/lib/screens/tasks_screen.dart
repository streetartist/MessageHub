import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refresh();
    });
  }

  /// 公开的刷新方法，供外部调用
  void refresh() async {
    final provider = context.read<AppProvider>();
    await provider.ensureInitialized();
    provider.loadTasks(status: _statusFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管理'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _statusFilter = value);
              context.read<AppProvider>().loadTasks(status: value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('全部')),
              const PopupMenuItem(value: 'pending', child: Text('待处理')),
              const PopupMenuItem(value: 'in_progress', child: Text('进行中')),
              const PopupMenuItem(value: 'completed', child: Text('已完成')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<AppProvider>().loadTasks(status: _statusFilter),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.tasks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.task_alt_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无任务'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAnalyzeDialog(context, provider),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('从消息提取任务'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadTasks(status: _statusFilter),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.tasks.length,
              itemBuilder: (context, index) {
                final task = provider.tasks[index];
                return _buildTaskCard(context, task, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showAnalyzeDialog(context, context.read<AppProvider>()),
        child: const Icon(Icons.auto_awesome),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, AppProvider provider) {
    final priorityColors = {
      1: Colors.red,
      2: Colors.orange,
      3: Colors.yellow.shade700,
      4: Colors.blue,
      5: Colors.grey,
    };

    final statusIcons = {
      'pending': Icons.radio_button_unchecked,
      'in_progress': Icons.timelapse,
      'completed': Icons.check_circle,
    };

    final statusColors = {
      'pending': Colors.grey,
      'in_progress': Colors.blue,
      'completed': Colors.green,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        onTap: () => _showTaskDetail(context, task, provider),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    statusIcons[task.status] ?? Icons.help_outline,
                    color: statusColors[task.status] ?? Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: task.status == 'completed'
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                ],
              ),
              if (task.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
              if (task.deadline != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(task.deadline!),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetail(BuildContext context, Task task, AppProvider provider) {
    final priorityColors = {
      1: Colors.red,
      2: Colors.orange,
      3: Colors.yellow.shade700,
      4: Colors.blue,
      5: Colors.grey,
    };

    final priorityLabels = {
      1: '紧急',
      2: '高',
      3: '中',
      4: '低',
      5: '最低',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题栏
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: priorityColors[task.priority]?.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'P${task.priority} ${priorityLabels[task.priority]}',
                        style: TextStyle(
                          color: priorityColors[task.priority],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // 基本信息卡片
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.folder_outlined,
                          '来源聊天',
                          task.chatName ?? '未知',
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          Icons.schedule_outlined,
                          '截止时间',
                          task.deadline != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(task.deadline!)
                              : '无截止时间',
                        ),
                        const Divider(height: 16),
                        _buildInfoRow(
                          Icons.access_time_outlined,
                          '创建时间',
                          DateFormat('yyyy-MM-dd HH:mm').format(task.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 描述
                if (task.description != null && task.description!.isNotEmpty) ...[
                  _buildSectionTitle('任务描述'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      task.description!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI 分析
                if (task.aiAnalysis != null && task.aiAnalysis!.isNotEmpty) ...[
                  _buildSectionTitle('AI 分析'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.blue[400], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.aiAnalysis!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[800],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 来源消息
                if (task.sourceMessage != null && task.sourceMessage!.isNotEmpty) ...[
                  _buildSectionTitle('来源消息'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.sourceMessage!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 状态选择
                _buildSectionTitle('修改状态'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildStatusChip(context, task, provider, 'pending', '待处理'),
                    _buildStatusChip(context, task, provider, 'in_progress', '进行中'),
                    _buildStatusChip(context, task, provider, 'completed', '已完成'),
                  ],
                ),
                const SizedBox(height: 16),

                // 优先级选择
                _buildSectionTitle('修改优先级'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(5, (index) {
                    final priority = index + 1;
                    return ChoiceChip(
                      label: Text('P$priority ${priorityLabels[priority]}'),
                      selected: task.priority == priority,
                      selectedColor: priorityColors[priority]?.withValues(alpha: 0.3),
                      onSelected: (selected) {
                        if (selected) {
                          provider.updateTask(task.id, {'priority': priority});
                          Navigator.pop(context);
                        }
                      },
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // 删除按钮
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDelete(context, task, provider);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除任务'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, Task task, AppProvider provider,
      String status, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: task.status == status,
      onSelected: (selected) {
        if (selected) {
          provider.updateTask(task.id, {'status': status});
          Navigator.pop(context);
        }
      },
    );
  }

  void _confirmDelete(BuildContext context, Task task, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除任务 "${task.title}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteTask(task.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAnalyzeDialog(BuildContext context, AppProvider provider) {
    int? selectedChatId;
    int days = 7;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('从消息提取任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: '选择聊天',
                  border: OutlineInputBorder(),
                ),
                items: provider.monitoredChats.map((chat) {
                  return DropdownMenuItem(
                    value: chat.id,
                    child: Text(chat.name),
                  );
                }).toList(),
                onChanged: (value) => setState(() => selectedChatId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: '时间范围',
                  border: OutlineInputBorder(),
                ),
                initialValue: days,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('最近1天')),
                  DropdownMenuItem(value: 3, child: Text('最近3天')),
                  DropdownMenuItem(value: 7, child: Text('最近7天')),
                  DropdownMenuItem(value: 14, child: Text('最近14天')),
                ],
                onChanged: (value) => setState(() => days = value ?? 7),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: selectedChatId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final result = await provider.analyzeTasks(
                        selectedChatId!,
                        days: days,
                      );
                      if (context.mounted && result != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('提取了 ${result['tasks_count'] ?? 0} 个任务'),
                          ),
                        );
                      }
                    },
              child: const Text('提取'),
            ),
          ],
        ),
      ),
    );
  }
}
