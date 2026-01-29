from datetime import datetime, timedelta
from flask import request, jsonify
from sqlalchemy import func
from . import api_bp
from models import db, Settings, MonitoredChat, ChatMessage
from chat_service import ChatService

@api_bp.route('/messages/<int:chat_id>', methods=['GET'])
def get_messages(chat_id):
    """获取聊天消息"""
    page = request.args.get('page', 1, type=int)
    per_page = request.args.get('per_page', 50, type=int)
    keyword = request.args.get('keyword', '')
    date_filter = request.args.get('date', '')

    query = ChatMessage.query.filter_by(chat_id=chat_id)

    # 关键词搜索
    if keyword:
        query = query.filter(
            db.or_(
                ChatMessage.content.contains(keyword),
                ChatMessage.sender_name.contains(keyword)
            )
        )

    # 日期筛选
    if date_filter:
        try:
            filter_date = datetime.strptime(date_filter, '%Y-%m-%d')
            next_day = filter_date + timedelta(days=1)
            query = query.filter(
                ChatMessage.msg_time >= filter_date,
                ChatMessage.msg_time < next_day
            )
        except ValueError:
            pass

    messages = query.order_by(ChatMessage.msg_time.desc())\
        .paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'messages': [{
            'id': m.id,
            'sender_name': m.sender_name,
            'content': m.content,
            'msg_time': m.msg_time.isoformat()
        } for m in messages.items],
        'total': messages.total,
        'pages': messages.pages,
        'current_page': page
    })


@api_bp.route('/messages/<int:chat_id>/stats', methods=['GET'])
def get_message_stats(chat_id):
    """获取聊天消息统计"""
    # 总消息数
    total = ChatMessage.query.filter_by(chat_id=chat_id).count()

    # 今日消息数
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_count = ChatMessage.query.filter(
        ChatMessage.chat_id == chat_id,
        ChatMessage.msg_time >= today
    ).count()

    # 发送者数量
    senders = db.session.query(func.count(func.distinct(ChatMessage.sender_name)))\
        .filter(ChatMessage.chat_id == chat_id).scalar() or 0

    # 记录天数
    first_msg = ChatMessage.query.filter_by(chat_id=chat_id)\
        .order_by(ChatMessage.msg_time.asc()).first()
    if first_msg:
        days = (datetime.now() - first_msg.msg_time).days + 1
    else:
        days = 0

    return jsonify({
        'total': total,
        'today': today_count,
        'senders': senders,
        'days': days
    })


@api_bp.route('/fetch-messages', methods=['POST'])
def fetch_messages_now():
    """立即获取消息（获取所有启用监控的聊天）"""
    try:
        settings = Settings.get_settings()
        chat_service = ChatService(settings)

        monitored_chats = MonitoredChat.query.filter_by(enabled=True).all()
        total_new = 0

        for chat in monitored_chats:
            try:
                messages = chat_service.fetch_messages(
                    chat_type=chat.chat_type,
                    peer_id=chat.peer_id,
                    peer_uid=chat.peer_uid,
                    days=settings.fetch_days
                )

                for msg_data in messages:
                    existing = ChatMessage.query.filter_by(
                        chat_id=chat.id,
                        msg_id=msg_data['msg_id']
                    ).first()

                    if not existing:
                        message = ChatMessage(
                            chat_id=chat.id,
                            msg_id=msg_data['msg_id'],
                            sender_name=msg_data['sender_name'],
                            sender_id=msg_data.get('sender_id'),
                            content=msg_data['content'],
                            msg_time=msg_data['msg_time']
                        )
                        db.session.add(message)
                        total_new += 1

                chat.last_fetch_time = datetime.now()
                db.session.commit()

            except Exception as e:
                print(f"获取 {chat.name} 消息失败: {e}")
                db.session.rollback()

        return jsonify({'success': True, 'message': f'获取完成，新增 {total_new} 条消息'})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})
