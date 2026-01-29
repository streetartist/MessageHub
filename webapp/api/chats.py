from flask import request, jsonify
from . import api_bp
from models import db, Settings, MonitoredChat
from chat_service import ChatService

@api_bp.route('/available-chats', methods=['GET'])
def get_available_chats():
    """获取可用的好友和群列表"""
    settings = Settings.get_settings()
    chat_service = ChatService(settings)

    try:
        friends, groups = chat_service.get_available_chats()
        return jsonify({
            'success': True,
            'friends': friends,
            'groups': groups
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


@api_bp.route('/monitored-chats', methods=['GET'])
def get_monitored_chats():
    """获取已监控的聊天列表"""
    chats = MonitoredChat.query.all()
    return jsonify({
        'chats': [{
            'id': c.id,
            'chat_type': c.chat_type,
            'peer_id': c.peer_id,
            'name': c.name,
            'enabled': c.enabled,
            'last_fetch_time': c.last_fetch_time.isoformat() if c.last_fetch_time else None
        } for c in chats]
    })


@api_bp.route('/monitored-chats', methods=['POST'])
def add_monitored_chat():
    """添加监控聊天"""
    data = request.json
    chat_type = int(data['chat_type'])
    peer_id = data['peer_id']
    peer_uid = data.get('peer_uid')
    name = data['name']

    # 检查是否已存在
    existing = MonitoredChat.query.filter_by(chat_type=chat_type, peer_id=peer_id).first()
    if existing:
        return jsonify({'success': False, 'error': '该聊天已在监控列表中'})

    chat = MonitoredChat(
        chat_type=chat_type,
        peer_id=peer_id,
        peer_uid=peer_uid,
        name=name,
        enabled=True
    )
    db.session.add(chat)
    db.session.commit()

    return jsonify({'success': True, 'id': chat.id})


@api_bp.route('/monitored-chats/<int:chat_id>', methods=['DELETE'])
def remove_monitored_chat(chat_id):
    """移除监控聊天"""
    chat = MonitoredChat.query.get_or_404(chat_id)
    db.session.delete(chat)
    db.session.commit()
    return jsonify({'success': True})


@api_bp.route('/monitored-chats/<int:chat_id>/toggle', methods=['POST'])
def toggle_monitored_chat(chat_id):
    """切换监控状态"""
    chat = MonitoredChat.query.get_or_404(chat_id)
    chat.enabled = not chat.enabled
    db.session.commit()
    return jsonify({'success': True, 'enabled': chat.enabled})
