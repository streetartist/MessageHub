# QQ 聊天 AI 助手

基于 napcat-qce 的 Flask 网站应用，提供聊天记录自动获取、AI 总结和任务提取功能。

## 功能特性

- **聊天监控**: 选择需要监控的好友和群聊
- **定时获取**: 自动定期获取聊天记录
- **AI 总结**: 使用 AI 自动总结聊天内容
- **任务提取**: AI 分析聊天中的任务、截止时间和优先级
- **时间表视图**: 日历形式展示任务和截止时间

## 快速开始

### 1. 启动 NapCat-QCE 服务

确保 NapCat-QCE 服务已启动并运行在 `localhost:40653`。

### 2. 启动 Web 应用

**Windows:**
```bash
双击 run.bat
```

**Linux/Mac:**
```bash
chmod +x run.sh
./run.sh
```

**手动启动:**
```bash
cd webapp
pip install -r requirements.txt
python app.py
```

### 3. 访问应用

打开浏览器访问: http://localhost:5000

## 配置说明

### AI 配置

支持 OpenAI 兼容的 API 端点，默认使用 DeepSeek：

| 服务商 | API 端点 | 模型 |
|--------|----------|------|
| DeepSeek | https://api.deepseek.com/v1/chat/completions | deepseek-chat |
| OpenAI | https://api.openai.com/v1/chat/completions | gpt-4 |
| Moonshot | https://api.moonshot.cn/v1/chat/completions | moonshot-v1-8k |
| 智谱 AI | https://open.bigmodel.cn/api/paas/v4/chat/completions | glm-4 |

### NapCat 配置

- 主机: localhost (默认)
- 端口: 40653 (默认)
- **令牌**: 自动从 NapCat-QCE 配置文件获取，无需手动配置

令牌获取优先级：
1. 环境变量 `NAPCAT_QCE_TOKEN`
2. 本地配置文件 `~/.qq-chat-exporter/security.json`

### 定时任务配置

- 获取间隔: 60 分钟 (默认)
- 获取天数: 1 天 (默认)

## 项目结构

```
webapp/
├── app.py              # Flask 应用入口
├── config.py           # 配置文件
├── models.py           # 数据库模型
├── routes.py           # 路由和 API
├── ai_service.py       # AI 服务
├── chat_service.py     # 聊天服务
├── scheduler.py        # 定时任务
├── requirements.txt    # 依赖
├── run.bat             # Windows 启动脚本
├── run.sh              # Linux/Mac 启动脚本
├── data/               # 数据目录
│   └── app.db          # SQLite 数据库
└── templates/          # HTML 模板
    ├── base.html       # 基础模板
    ├── index.html      # 仪表盘
    ├── settings.html   # 设置页面
    ├── chats.html      # 聊天监控
    ├── summaries.html  # AI 总结
    └── schedule.html   # 时间表
```

## 使用流程

1. **配置设置**: 进入设置页面，配置 AI API Key 和 NapCat 连接信息
2. **添加监控**: 在聊天监控页面，加载好友/群列表并添加需要监控的聊天
3. **获取消息**: 系统会定时自动获取消息，也可手动点击"立即获取"
4. **生成总结**: 在 AI 总结页面生成聊天总结
5. **提取任务**: 在聊天监控页面点击"提取任务"，AI 会分析并提取任务
6. **查看时间表**: 在时间表页面查看所有任务和截止时间

## 技术栈

- **后端**: Flask, Flask-SQLAlchemy, Flask-APScheduler
- **前端**: Bootstrap 5, FullCalendar
- **数据库**: SQLite
- **AI**: OpenAI 兼容 API
