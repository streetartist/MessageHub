import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/summaries_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/auto_jobs_screen.dart';
import 'screens/settings_screen.dart';
import 'models/models.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'NapCat助手',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/messages') {
            final chat = settings.arguments as MonitoredChat;
            return MaterialPageRoute(
              builder: (context) => MessagesScreen(chat: chat),
            );
          }
          return null;
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 使用 GlobalKey 来访问各个页面的状态，以便刷新数据
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _chatsKey = GlobalKey<ChatsScreenState>();
  final _summariesKey = GlobalKey<SummariesScreenState>();
  final _tasksKey = GlobalKey<TasksScreenState>();
  final _scheduleKey = GlobalKey<ScheduleScreenState>();
  final _autoJobsKey = GlobalKey<AutoJobsScreenState>();
  final _settingsKey = GlobalKey<SettingsScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(key: _dashboardKey, onNavigate: _onPageChanged),
      ChatsScreen(key: _chatsKey),
      SummariesScreen(key: _summariesKey),
      TasksScreen(key: _tasksKey),
      ScheduleScreen(key: _scheduleKey),
      AutoJobsScreen(key: _autoJobsKey),
      SettingsScreen(key: _settingsKey),
    ];
  }

  /// 切换页面时刷新对应页面的数据
  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // 根据页面索引刷新对应数据
    switch (index) {
      case 0:
        _dashboardKey.currentState?.refresh();
        break;
      case 1:
        _chatsKey.currentState?.refresh();
        break;
      case 2:
        _summariesKey.currentState?.refresh();
        break;
      case 3:
        _tasksKey.currentState?.refresh();
        break;
      case 4:
        _scheduleKey.currentState?.refresh();
        break;
      case 5:
        _autoJobsKey.currentState?.refresh();
        break;
      case 6:
        _settingsKey.currentState?.refresh();
        break;
    }
  }

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: '仪表盘',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: '聊天',
    ),
    NavigationDestination(
      icon: Icon(Icons.summarize_outlined),
      selectedIcon: Icon(Icons.summarize),
      label: '总结',
    ),
    NavigationDestination(
      icon: Icon(Icons.task_alt_outlined),
      selectedIcon: Icon(Icons.task_alt),
      label: '任务',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: '日程',
    ),
    NavigationDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule),
      label: '自动',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // 根据屏幕宽度决定使用底部导航还是侧边导航
    final isWideScreen = MediaQuery.of(context).size.width > 600;

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onPageChanged,
              labelType: NavigationRailLabelType.all,
              destinations: _destinations.map((d) {
                return NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: Text(d.label),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onPageChanged,
        destinations: _destinations,
      ),
    );
  }
}
