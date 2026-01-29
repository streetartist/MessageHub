from datetime import datetime, timedelta
from flask import request, jsonify
from . import api_bp
from models import db, Settings, ChatMessage, Task
from ai_service import AIService

@api_bp.route('/tasks', methods=['GET'])
def get_tasks():
    """获取任务列表"""
    status = request.args.get('status')
    query = Task.query

    if status:
        query = query.filter_by(status=status)

    tasks = query.order_by(Task.deadline.asc().nullslast(), Task.priority.asc()).all()

    return jsonify({
        'tasks': [{
            'id': t.id,
            'chat_id': t.chat_id,
            'title': t.title,
            'description': t.description,
            'priority': t.priority,
            'deadline': t.deadline.isoformat() if t.deadline else None,
            'status': t.status,
            'source_message': t.source_message,
            'ai_analysis': t.ai_analysis,
            'created_at': t.created_at.isoformat()
        } for t in tasks]
    })


@api_bp.route('/tasks/<int:task_id>', methods=['PUT'])
def update_task(task_id):
    """更新任务"""
    task = Task.query.get_or_404(task_id)
    data = request.json

    if 'status' in data:
        task.status = data['status']
    if 'priority' in data:
        task.priority = int(data['priority'])
    if 'deadline' in data:
        task.deadline = datetime.fromisoformat(data['deadline']) if data['deadline'] else None

    db.session.commit()
    return jsonify({'success': True})


@api_bp.route('/tasks/<int:task_id>', methods=['DELETE'])
def delete_task(task_id):
    """删除任务"""
    task = Task.query.get_or_404(task_id)
    db.session.delete(task)
    db.session.commit()
    return jsonify({'success': True})


@api_bp.route('/clear-analyzed-status', methods=['POST'])
def clear_analyzed_status():
    """清除所有消息的已分析状态"""
    data = request.json or {}
    chat_id = data.get('chat_id')  # 可选：只清除指定聊天的状态

    try:
        query = ChatMessage.query.filter(ChatMessage.ai_processed == True)

        if chat_id:
            query = query.filter_by(chat_id=chat_id)

        count = query.count()
        query.update({
            ChatMessage.ai_processed: False,
            ChatMessage.ai_processed_at: None
        }, synchronize_session=False)

        db.session.commit()

        return jsonify({
            'success': True,
            'cleared_count': count,
            'message': f'已清除 {count} 条消息的分析状态'
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)})


@api_bp.route('/analyze-tasks', methods=['POST'])
def analyze_tasks():
    """分析消息提取任务（只处理未处理过的消息）"""
    data = request.json or {}
    chat_id = data.get('chat_id')
    days = data.get('days', 7)
    force = data.get('force', False)  # 是否强制重新处理所有消息

    settings = Settings.get_settings()
    ai_service = AIService(settings)

    # 获取消息
    end_time = datetime.now()
    start_time = end_time - timedelta(days=days)

    query = ChatMessage.query.filter(
        ChatMessage.msg_time >= start_time,
        ChatMessage.msg_time <= end_time
    )

    # 如果不是强制模式，只获取未处理的消息
    if not force:
        query = query.filter(
            db.or_(
                ChatMessage.ai_processed == False,
                ChatMessage.ai_processed.is_(None)
            )
        )

    if chat_id:
        query = query.filter_by(chat_id=chat_id)

    messages = query.order_by(ChatMessage.msg_time.asc()).all()

    # 如果没找到未处理的消息
    if not messages:
        # 检查是否有已处理的消息
        processed_count = ChatMessage.query.filter(
            ChatMessage.ai_processed == True
        )
        if chat_id:
            processed_count = processed_count.filter_by(chat_id=chat_id)
        processed_count = processed_count.count()

        if processed_count > 0:
            return jsonify({
                'success': True,
                'tasks_count': 0,
                'message': f'没有新消息需要处理（已有 {processed_count} 条消息被处理过）'
            })
        else:
            return jsonify({'success': False, 'error': '没有找到消息'})

    # 获取已存在的任务标题，用于去重
    # existing_titles = set()
    # existing_tasks = Task.query.filter_by(chat_id=chat_id).all() if chat_id else Task.query.all()
    # for t in existing_tasks:
    #     existing_titles.add(t.title.strip().lower())

    try:
        tasks_data = ai_service.extract_tasks(messages)

        # 保存任务
        new_tasks = []
        skipped = 0
        for t in tasks_data:
            if not t.get('title'):
                continue
            title = t['title'].strip()
            # 检查是否已存在相似任务
            # if title.lower() in existing_titles:
            #     skipped += 1
            #     continue

            task = Task(
                chat_id=chat_id,
                title=title,
                description=t.get('description'),
                priority=t.get('priority', 3),
                deadline=datetime.fromisoformat(t['deadline']) if t.get('deadline') else None,
                source_message=t.get('source_message'),
                ai_analysis=t.get('analysis')
            )
            db.session.add(task)
            new_tasks.append(task)
            # existing_titles.add(title.lower())

        # 标记消息为已处理
        now = datetime.now()
        for msg in messages:
            msg.ai_processed = True
            msg.ai_processed_at = now

        db.session.commit()

        return jsonify({
            'success': True,
            'tasks_count': len(new_tasks),
            'skipped': skipped,
            'processed_messages': len(messages)
        })
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'error': str(e)})
