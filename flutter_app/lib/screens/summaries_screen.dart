import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class SummariesScreen extends StatefulWidget {
  const SummariesScreen({super.key});

  @override
  State<SummariesScreen> createState() => SummariesScreenState();
}

class SummariesScreenState extends State<SummariesScreen> {
  int? _filterChatId;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

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
    _loadWithFilters(provider);
    provider.loadMonitoredChats();
  }

  void _loadWithFilters(AppProvider provider) {
    provider.loadSummaries(
      chatId: _filterChatId,
      startDate: _filterStartDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterStartDate!)
          : null,
      endDate: _filterEndDate != null
          ? DateFormat('yyyy-MM-dd').format(_filterEndDate!)
          : null,
    );
  }

  void _clearFilters() {
    setState(() {
      _filterChatId = null;
      _filterStartDate = null;
      _filterEndDate = null;
    });
    _loadWithFilters(context.read<AppProvider>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI总结'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadWithFilters(context.read<AppProvider>()),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 筛选区域
              _buildFilterSection(provider),
              // 列表区域
              Expanded(
                child: _buildSummariesList(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showGenerateDialog(context, context.read<AppProvider>()),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterSection(AppProvider provider) {
    final hasFilters = _filterChatId != null ||
        _filterStartDate != null ||
        _filterEndDate != null;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 聊天筛选
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(
                labelText: '选择聊天',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              value: _filterChatId,
              items: [
                const DropdownMenuItem(value: null, child: Text('全部聊天')),
                ...provider.monitoredChats.map((chat) {
                  return DropdownMenuItem(value: chat.id, child: Text(chat.name));
                }),
              ],
              onChanged: (value) {
                setState(() => _filterChatId = value);
                _loadWithFilters(provider);
              },
            ),
            const SizedBox(height: 12),
            // 日期筛选
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true, provider),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '开始日期',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        _filterStartDate != null
                            ? DateFormat('yyyy-MM-dd').format(_filterStartDate!)
                            : '不限',
                        style: TextStyle(
                          color: _filterStartDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false, provider),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '结束日期',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(
                        _filterEndDate != null
                            ? DateFormat('yyyy-MM-dd').format(_filterEndDate!)
                            : '不限',
                        style: TextStyle(
                          color: _filterEndDate != null ? null : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hasFilters) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清除筛选'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart, AppProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_filterStartDate ?? DateTime.now().subtract(const Duration(days: 30)))
          : (_filterEndDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _filterStartDate = picked;
        } else {
          _filterEndDate = picked;
        }
      });
      _loadWithFilters(provider);
    }
  }

  Widget _buildSummariesList(AppProvider provider) {
    if (provider.isLoading && provider.summaries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.summarize_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无AI总结'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showGenerateDialog(context, provider),
              icon: const Icon(Icons.add),
              label: const Text('生成总结'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadWithFilters(provider),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: provider.summaries.length,
        itemBuilder: (context, index) {
          final summary = provider.summaries[index];
          return _buildSummaryCard(context, summary, provider);
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AISummary summary, AppProvider provider) {
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(summary.createdAt);
    // 优先使用 chatName，否则从 monitoredChats 中查找名称
    String chatTitle;
    if (summary.chatName != null && summary.chatName!.isNotEmpty) {
      chatTitle = summary.chatName!;
    } else if (summary.chatId != null) {
      final chat = provider.monitoredChats.where((c) => c.id == summary.chatId).firstOrNull;
      chatTitle = chat?.name ?? '聊天 #${summary.chatId}';
    } else {
      chatTitle = '全部聊天';
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ExpansionTile(
        title: Text(chatTitle),
        subtitle: Text(
          dateStr,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        leading: const CircleAvatar(
          backgroundColor: Colors.purple,
          child: Icon(Icons.summarize, color: Colors.white),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context, summary, provider),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(summary.summaryText),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AISummary summary, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条总结吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.deleteSummary(summary.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? '总结已删除' : (provider.error ?? '删除失败')),
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showGenerateDialog(BuildContext context, AppProvider provider) {
    int? selectedChatId;
    int days = 7;
    bool useCustomRange = false;
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('生成AI总结'),
          content: SingleChildScrollView(
            child: Column(
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
                // 时间筛选方式切换
                SwitchListTile(
                  title: const Text('指定日期范围'),
                  subtitle: Text(useCustomRange ? '选择开始和结束日期' : '使用最近N天'),
                  value: useCustomRange,
                  onChanged: (value) => setState(() {
                    useCustomRange = value;
                    if (value && startDate == null) {
                      endDate = DateTime.now();
                      startDate = endDate!.subtract(const Duration(days: 7));
                    }
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                if (!useCustomRange)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: '时间范围',
                      border: OutlineInputBorder(),
                    ),
                    value: days,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('最近1天')),
                      DropdownMenuItem(value: 3, child: Text('最近3天')),
                      DropdownMenuItem(value: 7, child: Text('最近7天')),
                      DropdownMenuItem(value: 14, child: Text('最近14天')),
                      DropdownMenuItem(value: 30, child: Text('最近30天')),
                    ],
                    onChanged: (value) => setState(() => days = value ?? 7),
                  )
                else ...[
                  // 开始日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('开始日期'),
                    subtitle: Text(startDate != null
                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                        : '未选择'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now().subtract(const Duration(days: 7)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),
                  // 结束日期
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('结束日期'),
                    subtitle: Text(endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : '未选择'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => endDate = picked);
                      }
                    },
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
              onPressed: selectedChatId == null
                  ? null
                  : () async {
                      Navigator.pop(context);
                      String? summary;
                      if (useCustomRange && startDate != null && endDate != null) {
                        summary = await provider.generateSummary(
                          selectedChatId!,
                          startDate: DateFormat('yyyy-MM-dd').format(startDate!),
                          endDate: DateFormat('yyyy-MM-dd').format(endDate!),
                        );
                      } else {
                        summary = await provider.generateSummary(
                          selectedChatId!,
                          days: days,
                        );
                      }
                      if (context.mounted) {
                        if (summary != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('总结生成成功')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.error ?? '生成失败')),
                          );
                        }
                      }
                    },
              child: const Text('生成'),
            ),
          ],
        ),
      ),
    );
  }
}
