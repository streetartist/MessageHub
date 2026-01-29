import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class AutoJobsScreen extends StatefulWidget {
  const AutoJobsScreen({super.key});

  @override
  State<AutoJobsScreen> createState() => AutoJobsScreenState();
}

class AutoJobsScreenState extends State<AutoJobsScreen> {
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
    provider.loadAutoJobs();
    provider.loadMonitoredChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自动任务'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppProvider>().loadAutoJobs(),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.autoJobs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.autoJobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无自动任务'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateDialog(context, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('创建任务'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadAutoJobs(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.autoJobs.length,
              itemBuilder: (context, index) {
                final job = provider.autoJobs[index];
                return _buildJobCard(context, job, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showCreateDialog(context, context.read<AppProvider>()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildJobCard(
      BuildContext context, AutoJob job, AppProvider provider) {
    final jobTypeIcons = {
      'fetch_messages': Icons.download,
      'ai_summary': Icons.summarize,
      'extract_tasks': Icons.task_alt,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: job.enabled ? Colors.green : Colors.grey,
              child: Icon(
                jobTypeIcons[job.jobType] ?? Icons.schedule,
                color: Colors.white,
              ),
            ),
            title: Text(job.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${job.jobTypeText} · ${job.scheduleText}'),
                if (job.lastRunTime != null)
                  Text(
                    '上次执行: ${DateFormat('MM-dd HH:mm').format(job.lastRunTime!)}',
                    style: TextStyle(
                      color: job.lastRunStatus == 'success'
                          ? Colors.green
                          : Colors.red,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            trailing: Switch(
              value: job.enabled,
              onChanged: (value) => provider.toggleAutoJob(job.id),
            ),
            onTap: () => _showJobDetail(context, job, provider),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final success = await provider.runAutoJob(job.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '任务已执行' : '执行失败'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('立即执行'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, job, provider),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  label: const Text('删除', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showJobDetail(BuildContext context, AutoJob job, AppProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('任务类型', job.jobTypeText),
            _buildDetailRow('调度方式', job.scheduleText),
            _buildDetailRow('处理天数', '${job.days}天'),
            _buildDetailRow('状态', job.enabled ? '已启用' : '已禁用'),
            if (job.lastRunTime != null)
              _buildDetailRow(
                '上次执行',
                DateFormat('yyyy-MM-dd HH:mm').format(job.lastRunTime!),
              ),
            if (job.lastRunMessage != null)
              _buildDetailRow('执行结果', job.lastRunMessage!),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AutoJob job, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除自动任务 "${job.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.deleteAutoJob(job.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, AppProvider provider) {
    final nameController = TextEditingController();
    String jobType = 'fetch_messages';
    String scheduleType = 'interval';
    int intervalMinutes = 60;
    int cronHour = 8;
    int cronMinute = 0;
    int? chatId;
    int days = 1;
    bool extractTasks = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('创建自动任务'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '任务类型',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: jobType,
                  items: const [
                    DropdownMenuItem(
                        value: 'fetch_messages', child: Text('获取消息')),
                    DropdownMenuItem(value: 'ai_summary', child: Text('AI总结')),
                    DropdownMenuItem(
                        value: 'extract_tasks', child: Text('提取任务')),
                  ],
                  onChanged: (value) =>
                      setState(() => jobType = value ?? 'fetch_messages'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: '调度方式',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: scheduleType,
                  items: const [
                    DropdownMenuItem(value: 'interval', child: Text('间隔执行')),
                    DropdownMenuItem(value: 'cron', child: Text('定时执行')),
                  ],
                  onChanged: (value) =>
                      setState(() => scheduleType = value ?? 'interval'),
                ),
                const SizedBox(height: 16),
                if (scheduleType == 'interval')
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: '执行间隔',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: intervalMinutes,
                    items: const [
                      DropdownMenuItem(value: 30, child: Text('每30分钟')),
                      DropdownMenuItem(value: 60, child: Text('每1小时')),
                      DropdownMenuItem(value: 120, child: Text('每2小时')),
                      DropdownMenuItem(value: 360, child: Text('每6小时')),
                      DropdownMenuItem(value: 720, child: Text('每12小时')),
                    ],
                    onChanged: (value) =>
                        setState(() => intervalMinutes = value ?? 60),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: '小时',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: cronHour,
                          items: List.generate(24, (i) {
                            return DropdownMenuItem(
                              value: i,
                              child: Text(i.toString().padLeft(2, '0')),
                            );
                          }),
                          onChanged: (value) =>
                              setState(() => cronHour = value ?? 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: '分钟',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: cronMinute,
                          items: [0, 15, 30, 45].map((i) {
                            return DropdownMenuItem(
                              value: i,
                              child: Text(i.toString().padLeft(2, '0')),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => cronMinute = value ?? 0),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(
                    labelText: '指定聊天 (可选)',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: chatId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部聊天')),
                    ...provider.monitoredChats.map((chat) {
                      return DropdownMenuItem(
                        value: chat.id,
                        child: Text(chat.name),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(() => chatId = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: '处理天数',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: days,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1天')),
                    DropdownMenuItem(value: 3, child: Text('3天')),
                    DropdownMenuItem(value: 7, child: Text('7天')),
                  ],
                  onChanged: (value) => setState(() => days = value ?? 1),
                ),
                if (jobType == 'ai_summary') ...[
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('同时提取任务'),
                    value: extractTasks,
                    onChanged: (value) => setState(() => extractTasks = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: nameController.text.isEmpty
                  ? null
                  : () async {
                      Navigator.pop(context);
                      final success = await provider.createAutoJob({
                        'name': nameController.text,
                        'job_type': jobType,
                        'enabled': true,
                        'schedule_type': scheduleType,
                        'interval_minutes':
                            scheduleType == 'interval' ? intervalMinutes : null,
                        'cron_hour': scheduleType == 'cron' ? cronHour : null,
                        'cron_minute':
                            scheduleType == 'cron' ? cronMinute : null,
                        'chat_id': chatId,
                        'days': days,
                        'extract_tasks': extractTasks,
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? '创建成功' : '创建失败'),
                          ),
                        );
                      }
                    },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );
  }
}
