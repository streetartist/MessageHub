from datetime import datetime
from flask import request, jsonify
from . import api_bp
from models import Task

@api_bp.route('/schedule/events', methods=['GET'])
def get_schedule_events():
    """获取日程事件（用于日历显示）"""
    start = request.args.get('start')
    end = request.args.get('end')

    query = Task.query.filter(Task.deadline.isnot(None))

    if start:
        query = query.filter(Task.deadline >= datetime.fromisoformat(start))
    if end:
        query = query.filter(Task.deadline <= datetime.fromisoformat(end))

    tasks = query.all()

    # 转换为 FullCalendar 事件格式
    events = []
    priority_colors = {
        1: '#dc3545',  # 红色 - 最高优先级
        2: '#fd7e14',  # 橙色
        3: '#ffc107',  # 黄色
        4: '#28a745',  # 绿色
        5: '#6c757d',  # 灰色 - 最低优先级
    }

    for t in tasks:
        events.append({
            'id': t.id,
            'title': t.title,
            'start': t.deadline.isoformat(),
            'backgroundColor': priority_colors.get(t.priority, '#007bff'),
            'borderColor': priority_colors.get(t.priority, '#007bff'),
            'extendedProps': {
                'priority': t.priority,
                'status': t.status,
                'description': t.description
            }
        })

    return jsonify(events)
