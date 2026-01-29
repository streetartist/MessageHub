import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class MessagesScreen extends StatefulWidget {
  final MonitoredChat chat;

  const MessagesScreen({super.key, required this.chat});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final AppProvider _provider;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  MessageStats? _stats;
  bool _isLoading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String? _selectedDate;
  String? _keyword;

  @override
  void initState() {
    super.initState();
    _provider = context.read<AppProvider>();
    _loadMessages();
    _loadStats();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _currentPage < _totalPages) {
        _loadMoreMessages();
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await _provider.api.getMessages(
        widget.chat.id,
        page: 1,
        keyword: _keyword,
        date: _selectedDate,
      );
      setState(() {
        _messages = response.messages;
        _currentPage = response.currentPage;
        _totalPages = response.pages;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final response = await _provider.api.getMessages(
        widget.chat.id,
        page: _currentPage + 1,
        keyword: _keyword,
        date: _selectedDate,
      );
      setState(() {
        _messages.addAll(response.messages);
        _currentPage = response.currentPage;
        _totalPages = response.pages;
      });
    } catch (e) {
      // Ignore
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _provider.api.getMessageStats(widget.chat.id);
      setState(() => _stats = stats);
    } catch (e) {
      // Ignore
    }
  }

  void _search() {
    _keyword = _searchController.text.isEmpty ? null : _searchController.text;
    _loadMessages();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(date);
      });
      _loadMessages();
    }
  }

  void _clearFilters() {
    setState(() {
      _keyword = null;
      _selectedDate = null;
      _searchController.clear();
    });
    _loadMessages();
  }

  Future<void> _generateSummary() async {
    final days = await _showDaysDialog('生成总结');
    if (days == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在生成总结...')),
    );

    final summary = await _provider.generateSummary(widget.chat.id, days: days);
    if (mounted) {
      if (summary != null) {
        _showSummaryResult(summary);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(_provider.error ?? '生成失败')),
        );
      }
    }
  }

  Future<void> _extractTasks() async {
    final days = await _showDaysDialog('提取任务');
    if (days == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在提取任务...')),
    );

    final result = await _provider.analyzeTasks(widget.chat.id, days: days);
    if (mounted) {
      if (result != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('提取了 ${result['tasks_count'] ?? 0} 个任务')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(_provider.error ?? '提取失败')),
        );
      }
    }
  }

  Future<int?> _showDaysDialog(String title) async {
    int days = 1;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<int>(
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
            onChanged: (value) => setState(() => days = value ?? 1),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, days),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummaryResult(String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 总结'),
        content: SingleChildScrollView(
          child: Text(summary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chat.name),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'summary':
                  _generateSummary();
                  break;
                case 'tasks':
                  _extractTasks();
                  break;
                case 'date':
                  _selectDate();
                  break;
                case 'clear':
                  _clearFilters();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'summary',
                child: Row(
                  children: [
                    Icon(Icons.summarize, size: 20),
                    SizedBox(width: 8),
                    Text('生成总结'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tasks',
                child: Row(
                  children: [
                    Icon(Icons.task_alt, size: 20),
                    SizedBox(width: 8),
                    Text('提取任务'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 20),
                    SizedBox(width: 8),
                    Text('按日期筛选'),
                  ],
                ),
              ),
              if (_keyword != null || _selectedDate != null)
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.clear, size: 20),
                      SizedBox(width: 8),
                      Text('清除筛选'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 统计信息
          if (_stats != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('总消息', _stats!.total.toString()),
                  _buildStatItem('今日', _stats!.today.toString()),
                  _buildStatItem('发送者', _stats!.senders.toString()),
                  _buildStatItem('天数', _stats!.days.toString()),
                ],
              ),
            ),
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索消息...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _search,
                  child: const Text('搜索'),
                ),
              ],
            ),
          ),
          // 筛选标签
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Chip(
                label: Text('日期: $_selectedDate'),
                onDeleted: () {
                  setState(() => _selectedDate = null);
                  _loadMessages();
                },
              ),
            ),
          // 消息列表
          Expanded(
            child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('暂无消息'))
                    : RefreshIndicator(
                        onRefresh: _loadMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length + (_isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _messages.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildMessageCard(_messages[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMessageCard(ChatMessage message) {
    final timeStr = DateFormat('MM-dd HH:mm').format(message.msgTime);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message.senderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildHighlightedText(message.content),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text) {
    if (_keyword == null || _keyword!.isEmpty) {
      return Text(text);
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerKeyword = _keyword!.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + _keyword!.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFF3CD),
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + _keyword!.length;
    }

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
