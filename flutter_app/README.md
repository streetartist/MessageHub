# NapCat助手 Flutter App

基于 NapCat-QCE-Python webapp API 的移动端应用，使用 Flutter 开发，支持 Android 和 iOS。

## 功能特性

- **仪表盘**: 查看监控聊天数、消息总数、待办任务数、AI总结数
- **聊天监控**: 添加/移除好友和群组的监控，切换监控状态
- **消息浏览**: 分页查看聊天消息，支持关键词搜索和日期筛选
- **AI总结**: 生成和查看聊天记录的AI总结
- **任务管理**: 查看、更新、删除任务，从消息中自动提取任务
- **日程管理**: 日历视图显示任务截止时间
- **自动任务**: 创建和管理定时任务（获取消息、AI总结、提取任务）
- **设置**: 配置服务器地址、AI API、NapCat连接

## 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode (用于构建)

## 安装依赖

```bash
cd flutter_app
flutter pub get
```

## 运行应用

### 开发模式

```bash
# 运行在连接的设备或模拟器上
flutter run

# 指定设备运行
flutter run -d <device_id>
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## 配置说明

首次运行应用时，需要在设置页面配置：

1. **服务器地址**: webapp 后端服务的地址（默认 http://localhost:5000）
2. **AI设置**:
   - API端点
   - API密钥
   - 模型名称
3. **NapCat设置**:
   - 主机地址
   - 端口号

## 项目结构

```
flutter_app/
├── lib/
│   ├── main.dart              # 应用入口
│   ├── models/
│   │   └── models.dart        # 数据模型
│   ├── services/
│   │   └── api_service.dart   # API服务
│   ├── providers/
│   │   └── app_provider.dart  # 状态管理
│   ├── screens/
│   │   ├── dashboard_screen.dart   # 仪表盘
│   │   ├── chats_screen.dart       # 聊天监控
│   │   ├── messages_screen.dart    # 消息浏览
│   │   ├── summaries_screen.dart   # AI总结
│   │   ├── tasks_screen.dart       # 任务管理
│   │   ├── schedule_screen.dart    # 日程管理
│   │   ├── auto_jobs_screen.dart   # 自动任务
│   │   └── settings_screen.dart    # 设置
│   ├── widgets/
│   │   └── loading_overlay.dart    # 通用组件
│   └── utils/
│       └── constants.dart          # 常量定义
├── android/                   # Android 平台配置
├── ios/                       # iOS 平台配置
├── pubspec.yaml              # 依赖配置
└── README.md
```

## API 端点

应用调用以下 webapp API：

| 端点 | 功能 |
|------|------|
| GET /api/stats | 获取统计数据 |
| GET /api/available-chats | 获取可用聊天列表 |
| GET /api/monitored-chats | 获取监控聊天列表 |
| POST /api/monitored-chats | 添加监控聊天 |
| DELETE /api/monitored-chats/:id | 移除监控聊天 |
| POST /api/monitored-chats/:id/toggle | 切换监控状态 |
| GET /api/messages/:id | 获取聊天消息 |
| GET /api/messages/:id/stats | 获取消息统计 |
| POST /api/fetch-messages | 立即获取消息 |
| GET /api/summaries | 获取AI总结列表 |
| POST /api/generate-summary | 生成AI总结 |
| GET /api/tasks | 获取任务列表 |
| PUT /api/tasks/:id | 更新任务 |
| DELETE /api/tasks/:id | 删除任务 |
| POST /api/analyze-tasks | 分析提取任务 |
| GET /api/schedule/events | 获取日程事件 |
| GET /api/auto-jobs | 获取自动任务列表 |
| POST /api/auto-jobs | 创建自动任务 |
| PUT /api/auto-jobs/:id | 更新自动任务 |
| DELETE /api/auto-jobs/:id | 删除自动任务 |
| POST /api/auto-jobs/:id/toggle | 切换自动任务状态 |
| POST /api/auto-jobs/:id/run | 立即执行自动任务 |
| GET /api/settings | 获取设置 |
| POST /api/settings | 更新设置 |
| POST /api/settings/test-ai | 测试AI连接 |
| POST /api/settings/test-napcat | 测试NapCat连接 |

## 注意事项

1. 确保 webapp 后端服务已启动
2. 手机和服务器需要在同一网络，或服务器可被手机访问
3. 如果使用 HTTP（非 HTTPS），Android 需要配置 `usesCleartextTraffic`（已配置）
4. iOS 需要配置 `NSAppTransportSecurity`（已配置）

## 许可证

MIT License
