from datetime import datetime
from flask import jsonify
from . import api_bp
from models import db, MonitoredChat, ChatMessage, Task, AISummary

@api_bp.route('/stats', methods=['GET'])
def get_dashboard_stats():
    """获取仪表盘统计数据"""
    
    # 监控聊天数
    chats_count = MonitoredChat.query.count()
    
    # 消息总数
    messages_count = ChatMessage.query.count()
    
    # 待办任务数
    pending_tasks_count = Task.query.filter_by(status='pending').count()
    
    # AI 总结数
    summaries_count = AISummary.query.count()
    
    return jsonify({
        'chats_count': chats_count,
        'messages_count': messages_count,
        'pending_tasks_count': pending_tasks_count,
        'summaries_count': summaries_count
    })
