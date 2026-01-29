from datetime import datetime, timedelta
from flask import request, jsonify
from . import api_bp
from models import db, Settings, ChatMessage, AISummary
from ai_service import AIService

@api_bp.route('/summaries', methods=['GET'])
def get_summaries():
    """获取 AI 总结列表"""
    chat_id = request.args.get('chat_id', type=int)
    start_date = request.args.get('start_date')  # 格式: YYYY-MM-DD
    end_date = request.args.get('end_date')      # 格式: YYYY-MM-DD
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 20, type=int)

    query = AISummary.query
    if chat_id:
        query = query.filter_by(chat_id=chat_id)

    # 按创建时间筛选
    if start_date:
        start_time = datetime.strptime(start_date, '%Y-%m-%d')
        query = query.filter(AISummary.created_at >= start_time)
    if end_date:
        end_time = datetime.strptime(end_date, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
        query = query.filter(AISummary.created_at <= end_time)

    summaries = query.order_by(AISummary.created_at.desc())\
        .paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'summaries': [{
            'id': s.id,
            'chat_id': s.chat_id,
            'summary_type': s.summary_type,
            'date_range_start': s.date_range_start.isoformat(),
            'date_range_end': s.date_range_end.isoformat(),
            'summary_text': s.summary_text,
            'created_at': s.created_at.isoformat()
        } for s in summaries.items],
        'total': summaries.total,
        'pages': summaries.pages
    })


@api_bp.route('/generate-summary', methods=['POST'])
def generate_summary():
    """生成 AI 总结"""
    data = request.json
    chat_id = data.get('chat_id')
    days = data.get('days')
    start_date = data.get('start_date')  # 格式: YYYY-MM-DD
    end_date = data.get('end_date')      # 格式: YYYY-MM-DD

    settings = Settings.get_settings()
    ai_service = AIService(settings)

    # 确定时间范围
    if start_date and end_date:
        # 使用指定的日期范围
        start_time = datetime.strptime(start_date, '%Y-%m-%d')
        end_time = datetime.strptime(end_date, '%Y-%m-%d').replace(hour=23, minute=59, second=59)
    elif days:
        # 使用最近N天
        end_time = datetime.now()
        start_time = end_time - timedelta(days=int(days))
    else:
        # 默认最近1天
        end_time = datetime.now()
        start_time = end_time - timedelta(days=1)

    query = ChatMessage.query.filter(
        ChatMessage.msg_time >= start_time,
        ChatMessage.msg_time <= end_time
    )
    if chat_id:
        query = query.filter_by(chat_id=chat_id)

    messages = query.order_by(ChatMessage.msg_time.asc()).all()

    # 如果按时间没找到，尝试获取该聊天的所有消息
    if not messages and chat_id:
        messages = ChatMessage.query.filter_by(chat_id=chat_id)\
            .order_by(ChatMessage.msg_time.asc()).limit(500).all()

    if not messages:
        return jsonify({'success': False, 'error': '没有找到消息'})

    # 生成总结
    try:
        summary_text = ai_service.generate_summary(messages)

        summary = AISummary(
            chat_id=chat_id,
            summary_type='custom',
            date_range_start=start_time,
            date_range_end=end_time,
            summary_text=summary_text
        )
        db.session.add(summary)
        db.session.commit()

        return jsonify({'success': True, 'summary': summary_text})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@api_bp.route('/summaries/<int:summary_id>', methods=['DELETE'])
def delete_summary(summary_id):
    """删除 AI 总结"""
    summary = AISummary.query.get_or_404(summary_id)
    db.session.delete(summary)
    db.session.commit()
    return jsonify({'success': True})
