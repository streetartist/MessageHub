"""
Flask 路由
"""
import sys
import os
from flask import Blueprint, render_template

# 添加父目录到路径以导入 napcat_qce
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

main_bp = Blueprint('main', __name__)

# ==================== 页面路由 ====================

@main_bp.route('/')
def index():
    """首页 - 仪表盘"""
    return render_template('index.html')


@main_bp.route('/settings')
def settings_page():
    """设置页面"""
    return render_template('settings.html')


@main_bp.route('/chats')
def chats_page():
    """聊天监控管理页面"""
    return render_template('chats.html')


@main_bp.route('/summaries')
def summaries_page():
    """AI 总结页面"""
    return render_template('summaries.html')


@main_bp.route('/schedule')
def schedule_page():
    """时间表/日程页面"""
    return render_template('schedule.html')


@main_bp.route('/auto-jobs')
def auto_jobs_page():
    """自动任务管理页面"""
    return render_template('auto_jobs.html')


@main_bp.route('/messages')
def messages_page():
    """聊天记录浏览页面"""
    return render_template('messages.html')
