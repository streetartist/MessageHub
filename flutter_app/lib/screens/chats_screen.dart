import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => ChatsScreenState();
}

class ChatsScreenState extends State<ChatsScreen> {
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
    provider.loadMonitoredChats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('聊天监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppProvider>().loadMonitoredChats(),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.monitoredChats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.monitoredChats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('暂无监控聊天'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddChatDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加监控'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadMonitoredChats(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: provider.monitoredChats.length,
              itemBuilder: (context, index) {
                final chat = provider.monitoredChats[index];
                return _buildChatCard(context, chat, provider);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChatDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChatCard(
      BuildContext context, MonitoredChat chat, AppProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: chat.chatType == 1 ? Colors.blue : Colors.green,
          child: Icon(
            chat.chatType == 1 ? Icons.person : Icons.group,
            color: Colors.white,
          ),
        ),
        title: Text(chat.name),
        subtitle: Text(
          '${chat.chatTypeText} · ${chat.peerId}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: chat.enabled,
              onChanged: (value) => provider.toggleMonitoredChat(chat.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, chat, provider),
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(context, '/messages', arguments: chat);
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, MonitoredChat chat, AppProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要移除对 "${chat.name}" 的监控吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.removeMonitoredChat(chat.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showAddChatDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AddChatSheet(),
    );
  }
}

class AddChatSheet extends StatefulWidget {
  const AddChatSheet({super.key});

  @override
  State<AddChatSheet> createState() => _AddChatSheetState();
}

class _AddChatSheetState extends State<AddChatSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      await provider.ensureInitialized();
      provider.loadAvailableChats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Friend> _filterFriends(List<Friend> friends) {
    if (_searchQuery.isEmpty) return friends;
    final query = _searchQuery.toLowerCase();
    return friends.where((f) =>
      f.displayName.toLowerCase().contains(query) ||
      f.uin.contains(query) ||
      (f.remark?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  List<Group> _filterGroups(List<Group> groups) {
    if (_searchQuery.isEmpty) return groups;
    final query = _searchQuery.toLowerCase();
    return groups.where((g) =>
      g.groupName.toLowerCase().contains(query) ||
      g.groupCode.contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '添加监控',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索好友或群组...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '好友'),
                Tab(text: '群组'),
              ],
            ),
            Expanded(
              child: Consumer<AppProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading &&
                      provider.friends.isEmpty &&
                      provider.groups.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 显示错误信息
                  if (provider.error != null &&
                      provider.friends.isEmpty &&
                      provider.groups.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => provider.loadAvailableChats(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('重试'),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredFriends = _filterFriends(provider.friends);
                  final filteredGroups = _filterGroups(provider.groups);

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFriendsList(provider, filteredFriends),
                      _buildGroupsList(provider, filteredGroups),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFriendsList(AppProvider provider, List<Friend> friends) {
    if (provider.friends.isEmpty) {
      return const Center(child: Text('暂无好友'));
    }
    if (friends.isEmpty) {
      return const Center(child: Text('无匹配结果'));
    }

    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text(friend.displayName),
          subtitle: Text('QQ: ${friend.uin}'),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addChat(
                    provider,
                    chatType: 1,
                    peerId: friend.uin,
                    peerUid: friend.uid,
                    name: friend.displayName,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildGroupsList(AppProvider provider, List<Group> groups) {
    if (provider.groups.isEmpty) {
      return const Center(child: Text('暂无群组'));
    }
    if (groups.isEmpty) {
      return const Center(child: Text('无匹配结果'));
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.group, color: Colors.white),
          ),
          title: Text(group.groupName),
          subtitle: Text('群号: ${group.groupCode} · ${group.memberCount}人'),
          trailing: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _addChat(
                    provider,
                    chatType: 2,
                    peerId: group.groupCode,
                    name: group.groupName,
                  ),
                ),
        );
      },
    );
  }

  Future<void> _addChat(
    AppProvider provider, {
    required int chatType,
    required String peerId,
    String? peerUid,
    required String name,
  }) async {
    setState(() => _isLoading = true);
    final success = await provider.addMonitoredChat(
      chatType: chatType,
      peerId: peerId,
      peerUid: peerUid,
      name: name,
    );
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加 "$name" 到监控列表')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? '添加失败')),
        );
      }
    }
  }
}
