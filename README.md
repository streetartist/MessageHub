# MessageHub

QQ 聊天记录 AI 助手 - 一个集成 AI 功能的 QQ 聊天记录导出、分析和管理系统。

## 功能特性

### 核心功能

- **聊天记录导出**: 支持导出好友和群组的聊天记录，支持 HTML、JSON、TXT、Excel 等多种格式
- **AI 智能总结**: 使用 AI 对聊天记录进行自动总结，快速了解聊天内容要点
- **任务提取**: 从聊天记录中自动识别和提取待办事项、任务和重要信息
- **定时任务**: 支持定时获取消息、生成总结、提取任务等自动化操作
- **聊天监控**: 监控指定的好友和群组，自动获取新消息

### 技术特性

- **多端支持**: 提供 Web 界面和 Flutter 移动应用
- **实时通信**: WebSocket 实时接收导出进度和事件通知
- **自动令牌管理**: 自动发现和管理 NapCat-QCE 访问令牌
- **批量操作**: 支持批量导出多个聊天记录
- **自动重连**: WebSocket 断线自动重连机制

## 系统架构

```
MessageHub/
├── napcat_qce/          # NapCat-QCE Python SDK
│   ├── client.py        # API 客户端
│   ├── websocket.py     # WebSocket 客户端
│   ├── launcher.py      # NapCat-QCE 启动器
│   ├── config.py        # 导出配置管理
│   ├── auto_token.py    # 自动令牌获取
│   └── types.py         # 数据类型定义
├── webapp/              # Flask Web 应用
│   ├── app.py           # 应用入口
│   ├── config.py        # 应用配置
│   ├── models.py        # 数据库模型
│   ├── routes.py        # 页面路由
│   ├── api/             # REST API
│   ├── chat_service.py  # 聊天服务
│   ├── ai_service.py    # AI 服务
│   └── scheduler.py     # 定时任务
└── flutter_app/         # Flutter 移动应用
```

## 环境要求

- Python 3.8+
- NapCat-QCE (QQ 聊天记录导出工具)
- QQ 客户端 (QQNT 版本)

### Python 依赖

```
Flask>=2.0
Flask-SQLAlchemy>=3.0
Flask-APScheduler>=1.12
requests>=2.28
websocket-client>=1.4
```

## 安装部署

### 1. 安装 NapCat-QCE

首先需要安装 NapCat-QCE 作为 QQ 聊天记录导出的后端服务。

1. 从 [shuakami/qq-chat-exporter](https://github.com/shuakami/qq-chat-exporter) 下载最新版本
2. 解压并重命名为 `NapCat-QCE-Windows-x64`，放置到以下位置之一：
   - 项目根目录下（推荐）
   - 用户目录下（`C:\Users\你的用户名\NapCat-QCE-Windows-x64`）
   - 或设置环境变量 `NAPCAT_QCE_PATH` 指向解压目录
3. 确保已安装 QQ 客户端 (QQNT 版本)

### 2. 克隆项目

```bash
git clone https://github.com/your-username/MessageHub.git
cd MessageHub
```

### 3. 安装 Python 依赖

```bash
cd webapp
pip install -r requirements.txt
```

### 4. 配置环境变量

```bash
# 复制环境变量示例文件
cp ../.env.example .env

# 编辑 .env 文件，配置必要的环境变量
```

### 5. 启动服务

```bash
# 启动 NapCat-QCE (在 NapCat-QCE 目录下)
./launcher-user.bat

# 启动 Web 应用
cd webapp
python app.py
```

### 6. 访问应用

打开浏览器访问 `http://localhost:5000`

## 配置说明

### 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `SECRET_KEY` | Flask 密钥 | `change-me-in-production` |
| `FLASK_HOST` | 服务器绑定地址 | `0.0.0.0` |
| `FLASK_PORT` | 服务器端口 | `5000` |
| `FLASK_DEBUG` | 调试模式 | `false` |
| `DATABASE_URL` | 数据库连接 URL | `sqlite:///data/app.db` |
| `AI_ENDPOINT` | AI API 端点 | `https://api.deepseek.com/v1/chat/completions` |
| `AI_MODEL` | AI 模型名称 | `deepseek-chat` |
| `SCHEDULER_TIMEZONE` | 调度器时区 | `Asia/Shanghai` |
| `NAPCAT_QCE_PATH` | NapCat-QCE 路径 | 自动查找 |

### AI 服务配置

本项目支持任何兼容 OpenAI API 格式的 AI 服务。在 Web 界面的「设置」页面中配置：

1. **API 端点**: AI 服务的 API 地址
2. **API 密钥**: 你的 API 密钥
3. **模型名称**: 使用的模型

支持的 AI 服务示例：
- DeepSeek: `https://api.deepseek.com/v1/chat/completions`
- OpenAI: `https://api.openai.com/v1/chat/completions`
- 其他兼容服务

## 使用说明

### Web 界面功能

1. **聊天列表**: 查看和管理监控的好友/群组
2. **消息浏览**: 查看聊天记录详情
3. **AI 总结**: 对选定时间范围的消息生成 AI 总结
4. **任务管理**: 查看从聊天中提取的任务
5. **定时任务**: 配置自动化任务
6. **设置**: 配置 AI 服务和其他选项

### Flutter 移动应用

#### 构建应用

```bash
cd flutter_app
flutter pub get
flutter build apk  # Android
flutter build ios  # iOS
```

#### 首次配置

1. 安装并打开应用
2. 进入「设置」页面
3. 配置**服务器地址**为你的 Web 服务地址
4. 点击「保存设置」

### 定时任务类型

- **fetch_messages**: 定时获取新消息
- **generate_summary**: 定时生成 AI 总结
- **extract_tasks**: 定时提取任务

## API 文档

详细的 REST API 文档请参阅 [webapp/API_DOCS.md](webapp/API_DOCS.md)。

## 开发

### 目录说明

- `napcat_qce/`: NapCat-QCE Python SDK，可独立使用
- `webapp/`: Flask Web 应用
- `flutter_app/`: Flutter 移动应用

## 许可证

GPL-3.0 License