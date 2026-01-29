from flask import request, jsonify, current_app
from . import api_bp
from models import db, Settings
from ai_service import AIService
from chat_service import ChatService
from scheduler import fetch_all_messages, generate_daily_summary

@api_bp.route('/settings', methods=['GET'])
def get_settings():
    """获取设置"""
    settings = Settings.get_settings()
    return jsonify({
        'ai_endpoint': settings.ai_endpoint,
        'ai_api_key': '***' if settings.ai_api_key else '',  # 不返回完整密钥
        'ai_model': settings.ai_model,
        'fetch_days': settings.fetch_days,
        'napcat_host': settings.napcat_host,
        'napcat_port': settings.napcat_port,
    })


@api_bp.route('/settings', methods=['POST'])
def update_settings():
    """更新设置"""
    data = request.json
    settings = Settings.get_settings()

    if 'ai_endpoint' in data:
        settings.ai_endpoint = data['ai_endpoint']
    if 'ai_api_key' in data and data['ai_api_key'] != '***':
        settings.ai_api_key = data['ai_api_key']
    if 'ai_model' in data:
        settings.ai_model = data['ai_model']
    if 'fetch_days' in data:
        settings.fetch_days = int(data['fetch_days'])
    if 'napcat_host' in data:
        settings.napcat_host = data['napcat_host']
    if 'napcat_port' in data:
        settings.napcat_port = int(data['napcat_port'])

    db.session.commit()
    return jsonify({'success': True})


@api_bp.route('/settings/test-ai', methods=['POST'])
def test_ai_connection():
    """测试 AI 连接"""
    settings = Settings.get_settings()
    ai_service = AIService(settings)
    success, message = ai_service.test_connection()
    return jsonify({'success': success, 'message': message})


@api_bp.route('/settings/test-napcat', methods=['POST'])
def test_napcat_connection():
    """测试 NapCat 连接"""
    settings = Settings.get_settings()
    success, message = ChatService.test_connection(
        host=settings.napcat_host,
        port=settings.napcat_port
    )
    return jsonify({'success': success, 'message': message})


@api_bp.route('/settings/token-status', methods=['GET'])
def get_token_status():
    """获取令牌状态"""
    has_token, masked_token = ChatService.get_token_status()
    return jsonify({
        'has_token': has_token,
        'token': masked_token
    })


@api_bp.route('/settings/update-scheduler', methods=['POST'])
def update_scheduler_interval():
    """更新调度器间隔"""
    settings = Settings.get_settings()

    # 从 app 上获取 scheduler
    scheduler = getattr(current_app, 'scheduler', None)

    if scheduler:
        try:
            # 更新消息获取任务
            if scheduler.get_job('fetch_messages'):
                scheduler.remove_job('fetch_messages')

            scheduler.add_job(
                id='fetch_messages',
                func=fetch_all_messages,
                args=[current_app._get_current_object()],
                trigger='interval',
                minutes=settings.fetch_interval_minutes,
                replace_existing=True
            )

            # 更新每日总结任务
            if scheduler.get_job('daily_summary'):
                scheduler.remove_job('daily_summary')

            summary_msg = ""
            if settings.auto_summary_enabled:
                hour, minute = settings.auto_summary_time.split(':')
                scheduler.add_job(
                    id='daily_summary',
                    func=generate_daily_summary,
                    args=[current_app._get_current_object()],
                    trigger='cron',
                    hour=int(hour),
                    minute=int(minute),
                    replace_existing=True
                )
                summary_msg = f"，每日 {settings.auto_summary_time} 自动总结"

            return jsonify({
                'success': True,
                'message': f'定时任务已更新：每 {settings.fetch_interval_minutes} 分钟获取消息{summary_msg}'
            })
        except Exception as e:
            return jsonify({'success': False, 'error': str(e)})

    return jsonify({'success': False, 'error': '调度器未初始化'})
