# QQ 聊天 AI 助手 API 文档

本文档描述了 WebApp 提供的 API 接口，用于手机 APP 或其他客户端调用。

## 基本信息

- **Base URL**: `/api`
- **响应格式**: JSON
- **日期时间格式**: ISO 8601 (例如 `2023-12-13T10:00:00`)

## 接口列表

### 1. 设置 (Settings)

#### 获取设置
- **URL**: `/settings`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "ai_endpoint": "https://api.deepseek.com/v1/chat/completions",
    "ai_api_key": "***",
    "ai_model": "deepseek-chat",
    "fetch_days": 1,
    "napcat_host": "localhost",
    "napcat_port": 40653
  }
  ```

#### 更新设置
- **URL**: `/settings`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "ai_endpoint": "...",
    "ai_api_key": "sk-...",
    "ai_model": "...",
    "fetch_days": 1,
    "napcat_host": "...",
    "napcat_port": ...
  }
  ```
- **Response**: `{"success": true}`

#### 测试 AI 连接
- **URL**: `/settings/test-ai`
- **Method**: `POST`
- **Response**: `{"success": true, "message": "连接成功..."}`

#### 测试 NapCat 连接
- **URL**: `/settings/test-napcat`
- **Method**: `POST`
- **Response**: `{"success": true, "message": "连接成功..."}`

#### 获取 Token 状态
- **URL**: `/settings/token-status`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "has_token": true,
    "token": "abcd****efgh"
  }
  ```

#### 更新调度器
- **URL**: `/settings/update-scheduler`
- **Method**: `POST`
- **Response**: `{"success": true, "message": "..."}`

---

### 2. 聊天监控 (Chats)

#### 获取可用聊天列表 (从 NapCat)
- **URL**: `/available-chats`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "success": true,
    "friends": [{"uin": 123, "name": "Nick", ...}],
    "groups": [{"group_code": 456, "group_name": "Group", ...}]
  }
  ```

#### 获取已监控聊天列表
- **URL**: `/monitored-chats`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "chats": [
      {
        "id": 1,
        "chat_type": 1, // 1=私聊, 2=群聊
        "peer_id": "123456",
        "name": "Friend Name",
        "enabled": true,
        "last_fetch_time": "2023-..."
      }
    ]
  }
  ```

#### 添加监控聊天
- **URL**: `/monitored-chats`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "chat_type": 1,
    "peer_id": "123456",
    "peer_uid": "optional_uid",
    "name": "Chat Name"
  }
  ```
- **Response**: `{"success": true, "id": 1}`

#### 移除监控聊天
- **URL**: `/monitored-chats/<chat_id>`
- **Method**: `DELETE`
- **Response**: `{"success": true}`

#### 切换监控状态
- **URL**: `/monitored-chats/<chat_id>/toggle`
- **Method**: `POST`
- **Response**: `{"success": true, "enabled": false}`

---

### 3. 消息 (Messages)

#### 获取聊天消息
- **URL**: `/messages/<chat_id>`
- **Method**: `GET`
- **Query Params**:
  - `page`: 页码 (默认 1)
  - `per_page`: 每页数量 (默认 50)
  - `keyword`: 搜索关键词
  - `date`: 日期筛选 (YYYY-MM-DD)
- **Response**:
  ```json
  {
    "messages": [
      {
        "id": 1,
        "sender_name": "Sender",
        "content": "Hello",
        "msg_time": "2023-..."
      }
    ],
    "total": 100,
    "pages": 5,
    "current_page": 1
  }
  ```

#### 获取消息统计
- **URL**: `/messages/<chat_id>/stats`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "total": 1000,
    "today": 50,
    "senders": 10,
    "days": 30
  }
  ```

#### 立即获取消息
- **URL**: `/fetch-messages`
- **Method**: `POST`
- **Response**: `{"success": true, "message": "获取完成..."}`

---

### 4. AI 总结 (Summaries)

#### 获取总结列表
- **URL**: `/summaries`
- **Method**: `GET`
- **Query Params**:
  - `chat_id`: 筛选特定聊天
  - `start_date`: 开始日期 (YYYY-MM-DD)
  - `end_date`: 结束日期 (YYYY-MM-DD)
  - `page`: 页码
  - `per_page`: 每页数量
- **Response**:
  ```json
  {
    "summaries": [
      {
        "id": 1,
        "chat_id": 1,
        "summary_type": "custom",
        "date_range_start": "2023-12-01T00:00:00",
        "date_range_end": "2023-12-13T23:59:59",
        "summary_text": "...",
        "created_at": "..."
      }
    ],
    "total": 10,
    "pages": 1
  }
  ```

#### 生成总结
- **URL**: `/generate-summary`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "chat_id": 1,        // 可选
    "days": 1,           // 可选，最近N天
    "start_date": "2023-12-01",  // 可选，开始日期 (YYYY-MM-DD)
    "end_date": "2023-12-13"     // 可选，结束日期 (YYYY-MM-DD)
  }
  ```
- **说明**: `start_date`/`end_date` 和 `days` 二选一，优先使用日期范围
- **Response**: `{"success": true, "summary": "..."}`

#### 删除总结
- **URL**: `/summaries/<summary_id>`
- **Method**: `DELETE`
- **Response**: `{"success": true}`

---

### 5. 任务 (Tasks)

#### 获取任务列表
- **URL**: `/tasks`
- **Method**: `GET`
- **Query Params**:
  - `status`: 筛选状态 (pending, in_progress, completed)
- **Response**:
  ```json
  {
    "tasks": [
      {
        "id": 1,
        "title": "Task Title",
        "priority": 3,
        "deadline": "2023-...",
        "status": "pending"
      }
    ]
  }
  ```

#### 更新任务
- **URL**: `/tasks/<task_id>`
- **Method**: `PUT`
- **Body**:
  ```json
  {
    "status": "completed",
    "priority": 1,
    "deadline": "2023-..."
  }
  ```
- **Response**: `{"success": true}`

#### 删除任务
- **URL**: `/tasks/<task_id>`
- **Method**: `DELETE`
- **Response**: `{"success": true}`

#### 分析并提取任务
- **URL**: `/analyze-tasks`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "chat_id": 1, // 可选
    "days": 7,
    "force": false // 是否强制重新分析
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "tasks_count": 2,
    "skipped": 0,
    "processed_messages": 50
  }
  ```

#### 清除消息分析状态
- **URL**: `/clear-analyzed-status`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "chat_id": 1  // 可选，只清除指定聊天的状态
  }
  ```
- **Response**:
  ```json
  {
    "success": true,
    "cleared_count": 100,
    "message": "已清除 100 条消息的分析状态"
  }
  ```

---

### 6. 日程 (Schedule)

#### 获取日程事件
- **URL**: `/schedule/events`
- **Method**: `GET`
- **Query Params**:
  - `start`: 开始时间 (ISO)
  - `end`: 结束时间 (ISO)
- **Response**: (FullCalendar 格式数组)
  ```json
  [
    {
      "id": 1,
      "title": "Task",
      "start": "2023-...",
      "backgroundColor": "#..."
    }
  ]
  ```

---

### 7. 自动任务 (Auto Jobs)

#### 获取自动任务列表
- **URL**: `/auto-jobs`
- **Method**: `GET`
- **Response**: `{"jobs": [...]}`

#### 创建自动任务
- **URL**: `/auto-jobs`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "name": "Daily Fetch",
    "job_type": "fetch_messages", // fetch_messages, ai_summary, extract_tasks
    "schedule_type": "interval", // interval, cron
    "interval_minutes": 60,
    "cron_hour": 22,
    "cron_minute": 0,
    "chat_id": null,
    "days": 1,
    "extract_tasks": true
  }
  ```
- **Response**: `{"success": true, "id": 1}`

#### 更新自动任务
- **URL**: `/auto-jobs/<job_id>`
- **Method**: `PUT`
- **Body**: (同创建，可选字段)
- **Response**: `{"success": true}`

#### 删除自动任务
- **URL**: `/auto-jobs/<job_id>`
- **Method**: `DELETE`
- **Response**: `{"success": true}`

#### 切换任务启用状态
- **URL**: `/auto-jobs/<job_id>/toggle`
- **Method**: `POST`
- **Response**: `{"success": true, "enabled": ...}`

#### 立即运行任务
- **URL**: `/auto-jobs/<job_id>/run`
- **Method**: `POST`
- **Response**: `{"success": true, "message": "..."}`

---

### 8. 统计 (Stats)

#### 获取仪表盘统计
- **URL**: `/stats`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "chats_count": 5,
    "messages_count": 1000,
    "pending_tasks_count": 3,
    "summaries_count": 10
  }
  ```
