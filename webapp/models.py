"""
数据库模型
"""
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()


class Settings(db.Model):
    """用户设置"""
    __tablename__ = 'settings'

    id = db.Column(db.Integer, primary_key=True)
    # AI 配置
    ai_endpoint = db.Column(db.String(500), default='https://api.deepseek.com/v1/chat/completions')
    ai_api_key = db.Column(db.String(500), default='')
    ai_model = db.Column(db.String(100), default='deepseek-chat')

    # 默认参数
    fetch_days = db.Column(db.Integer, default=1)  # 获取最近几天的消息

    # NapCat 配置
    napcat_host = db.Column(db.String(100), default='localhost')
    napcat_port = db.Column(db.Integer, default=40653)

    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)

    @classmethod
    def get_settings(cls):
        """获取或创建设置"""
        settings = cls.query.first()
        if not settings:
            settings = cls()
            db.session.add(settings)
            db.session.commit()
        return settings


class MonitoredChat(db.Model):
    """监控的聊天（好友或群）"""
    __tablename__ = 'monitored_chats'

    id = db.Column(db.Integer, primary_key=True)
    chat_type = db.Column(db.Integer, nullable=False)  # 1=私聊, 2=群聊
    peer_id = db.Column(db.String(50), nullable=False)  # 好友QQ号或群号
    peer_uid = db.Column(db.String(50), nullable=True)  # UID（用于API调用）
    name = db.Column(db.String(200), nullable=False)  # 显示名称
    enabled = db.Column(db.Boolean, default=True)  # 是否启用监控
    last_fetch_time = db.Column(db.DateTime, nullable=True)  # 上次获取时间
    created_at = db.Column(db.DateTime, default=datetime.now)

    # 关联的消息
    messages = db.relationship('ChatMessage', backref='chat', lazy='dynamic',
                               cascade='all, delete-orphan')

    __table_args__ = (
        db.UniqueConstraint('chat_type', 'peer_id', name='unique_chat'),
    )


class ChatMessage(db.Model):
    """聊天消息"""
    __tablename__ = 'chat_messages'

    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('monitored_chats.id'), nullable=False)
    msg_id = db.Column(db.String(100), nullable=False)  # 消息ID
    sender_name = db.Column(db.String(200), nullable=False)  # 发送者名称
    sender_id = db.Column(db.String(50), nullable=True)  # 发送者ID
    content = db.Column(db.Text, nullable=True)  # 消息内容
    msg_time = db.Column(db.DateTime, nullable=False)  # 消息时间
    created_at = db.Column(db.DateTime, default=datetime.now)

    # AI 处理状态
    ai_processed = db.Column(db.Boolean, default=False)  # 是否已被 AI 处理
    ai_processed_at = db.Column(db.DateTime, nullable=True)  # AI 处理时间

    __table_args__ = (
        db.UniqueConstraint('chat_id', 'msg_id', name='unique_message'),
    )


class AISummary(db.Model):
    """AI 总结"""
    __tablename__ = 'ai_summaries'

    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('monitored_chats.id'), nullable=True)
    summary_type = db.Column(db.String(50), nullable=False)  # daily, weekly, custom
    date_range_start = db.Column(db.DateTime, nullable=False)
    date_range_end = db.Column(db.DateTime, nullable=False)
    summary_text = db.Column(db.Text, nullable=False)  # AI 总结内容
    created_at = db.Column(db.DateTime, default=datetime.now)


class Task(db.Model):
    """从聊天中提取的任务"""
    __tablename__ = 'tasks'

    id = db.Column(db.Integer, primary_key=True)
    chat_id = db.Column(db.Integer, db.ForeignKey('monitored_chats.id'), nullable=True)
    title = db.Column(db.String(500), nullable=False)  # 任务标题
    description = db.Column(db.Text, nullable=True)  # 任务描述
    priority = db.Column(db.Integer, default=3)  # 优先级 1-5，1最高
    deadline = db.Column(db.DateTime, nullable=True)  # 截止时间
    status = db.Column(db.String(20), default='pending')  # pending, in_progress, completed
    source_message = db.Column(db.Text, nullable=True)  # 来源消息
    ai_analysis = db.Column(db.Text, nullable=True)  # AI 分析说明
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)


class AutoJob(db.Model):
    """自动任务"""
    __tablename__ = 'auto_jobs'

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(200), nullable=False)  # 任务名称
    job_type = db.Column(db.String(50), nullable=False)  # 任务类型: fetch_messages, ai_summary, extract_tasks
    enabled = db.Column(db.Boolean, default=True)  # 是否启用

    # 调度配置
    schedule_type = db.Column(db.String(20), default='interval')  # interval(间隔) 或 cron(定时)
    interval_minutes = db.Column(db.Integer, default=60)  # 间隔分钟数（interval类型）
    cron_hour = db.Column(db.Integer, default=22)  # 小时（cron类型）
    cron_minute = db.Column(db.Integer, default=0)  # 分钟（cron类型）

    # 任务参数
    chat_id = db.Column(db.Integer, db.ForeignKey('monitored_chats.id'), nullable=True)  # 指定聊天，null表示全部
    days = db.Column(db.Integer, default=1)  # 处理最近几天的数据
    extract_tasks = db.Column(db.Boolean, default=True)  # AI总结时是否提取任务

    # 执行状态
    last_run_time = db.Column(db.DateTime, nullable=True)  # 上次执行时间
    last_run_status = db.Column(db.String(20), nullable=True)  # success, failed
    last_run_message = db.Column(db.Text, nullable=True)  # 执行结果消息
    
    created_at = db.Column(db.DateTime, default=datetime.now)
    updated_at = db.Column(db.DateTime, default=datetime.now, onupdate=datetime.now)
