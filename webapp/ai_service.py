"""
AI 服务 - 调用 AI API 进行总结和任务分析
"""
import json
import requests
from datetime import datetime


class AIService:
    """AI 服务类"""

    def __init__(self, settings):
        self.settings = settings
        self.endpoint = settings.ai_endpoint
        self.api_key = settings.ai_api_key
        self.model = settings.ai_model

    def _call_api(self, messages, temperature=0.7):
        """调用 AI API"""
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f'Bearer {self.api_key}'
        }

        data = {
            'model': self.model,
            'messages': messages,
            'temperature': temperature
        }

        response = requests.post(
            self.endpoint,
            headers=headers,
            json=data,
            timeout=60
        )

        if response.status_code != 200:
            raise Exception(f"AI API 调用失败: {response.status_code} - {response.text}")

        result = response.json()
        return result['choices'][0]['message']['content']

    def test_connection(self):
        """测试 AI 连接"""
        try:
            messages = [
                {'role': 'user', 'content': '请回复"连接成功"'}
            ]
            response = self._call_api(messages)
            return True, f"连接成功: {response[:50]}"
        except Exception as e:
            return False, str(e)

    def generate_summary(self, chat_messages):
        """生成聊天总结

        Args:
            chat_messages: ChatMessage 对象列表

        Returns:
            总结文本
        """
        # 格式化消息
        formatted_messages = self._format_messages(chat_messages)

        prompt = f"""请对以下聊天记录进行总结，包括：
1. 主要讨论的话题
2. 重要的信息和决定
3. 需要关注的事项

聊天记录：
{formatted_messages}

请用简洁的中文进行总结。"""

        messages = [
            {'role': 'system', 'content': '你是一个专业的聊天记录分析助手，擅长提取关键信息并进行总结。'},
            {'role': 'user', 'content': prompt}
        ]

        return self._call_api(messages)

    def extract_tasks(self, chat_messages):
        """从聊天记录中提取任务

        Args:
            chat_messages: ChatMessage 对象列表

        Returns:
            任务列表，每个任务包含 title, description, priority, deadline, source_message, analysis
        """
        formatted_messages = self._format_messages(chat_messages)
        today = datetime.now().strftime('%Y-%m-%d')

        prompt = f"""请分析以下聊天记录，提取所有可能需要"我"（聊天记录的阅读者）关注或行动的事项。

当前日期是：{today}

【重要原则】
宁可多提取，不要漏掉！如果不确定是否是任务，倾向于提取出来让用户自己判断。

【应该提取的任务类型】
1. **直接指派**：明确指派给我的任务（"@我"、"你去做"、"麻烦你"、"帮我"等）
2. **集体任务**：面向群体的任务我也可能需要参与（"大家注意"、"各位"、"所有人"、"记得..."）
3. **隐性请求**：
   - 提问形式："谁能帮忙？"、"有人知道吗？"、"这个怎么处理？"
   - 陈述问题："这个有bug"、"系统挂了"、"文档需要更新"
   - 暗示需求："这个还没做"、"deadline快到了"、"客户在催"
4. **提醒通知**：
   - 会议/活动提醒："明天开会"、"周五聚餐"、"记得参加"
   - 截止日期提醒："XX号之前要交"、"下周一截止"
5. **待确认事项**：需要我回复或确认的（"你看一下"、"确认下"、"回复我"）
6. **工作相关**：
   - 项目进度："这个功能要加上"、"需求变了"
   - 问题反馈："用户反馈..."、"测试发现..."

【仅排除以下情况】
- 明确是别人自己要做的事且与我完全无关（如"我自己去处理"）
- 纯粹的闲聊寒暄（"早上好"、"吃了吗"）
- 已经完成的事情（"我已经做完了"、"搞定了"）

【时间计算规则】
消息前的方括号包含发送时间。"明天"、"后天"、"下周"等相对时间要根据消息发送时间计算，不是当前日期。

【输出要求】
对每个任务提供：
1. title: 简短标题
2. description: 详细说明
3. priority: 1-5（1最紧急，有明确deadline或催促的设为1-2）
4. deadline: ISO格式时间或null
5. source_message: 原始消息
6. analysis: 为什么提取这个任务

聊天记录：
{formatted_messages}

JSON格式返回：
```json
[
  {{
    "title": "任务标题",
    "description": "任务描述",
    "priority": 3,
    "deadline": "2024-01-15T18:00:00",
    "source_message": "原始消息",
    "analysis": "分析说明"
  }}
]
```

只返回JSON，无任务则返回[]。"""

        messages = [
            {'role': 'system', 'content': '你是一个高灵敏度的任务提取助手。你的职责是从聊天记录中尽可能多地识别潜在任务和待办事项。宁可多提取让用户筛选，也不要漏掉重要任务。对于模糊的、隐含的任务请求也要识别出来。只返回JSON格式数据。'},
            {'role': 'user', 'content': prompt}
        ]

        response = self._call_api(messages, temperature=0.3)

        # 解析 JSON
        try:
            # 尝试提取 JSON 部分
            response = response.strip()
            if response.startswith('```json'):
                response = response[7:]
            if response.startswith('```'):
                response = response[3:]
            if response.endswith('```'):
                response = response[:-3]

            tasks = json.loads(response.strip())
            return tasks if isinstance(tasks, list) else []
        except json.JSONDecodeError as e:
            print(f"JSON 解析失败: {e}")
            print(f"原始响应: {response}")
            return []

    def _format_messages(self, chat_messages, max_length=8000):
        """格式化消息列表为文本

        Args:
            chat_messages: ChatMessage 对象列表
            max_length: 最大字符数

        Returns:
            格式化的文本
        """
        lines = []
        total_length = 0

        for msg in chat_messages:
            time_str = msg.msg_time.strftime('%Y-%m-%d %H:%M') if msg.msg_time else ''
            line = f"[{time_str}] {msg.sender_name}: {msg.content or ''}"

            if total_length + len(line) > max_length:
                lines.append("... (消息过多，已截断)")
                break

            lines.append(line)
            total_length += len(line) + 1

        return '\n'.join(lines)
