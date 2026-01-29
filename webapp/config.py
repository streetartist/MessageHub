"""
应用配置
"""
import os

basedir = os.path.abspath(os.path.dirname(__file__))

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'change-me-in-production'

    # 数据库配置
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or \
        'sqlite:///' + os.path.join(basedir, 'data', 'app.db')
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # APScheduler 配置
    SCHEDULER_API_ENABLED = os.environ.get('SCHEDULER_API_ENABLED', 'true').lower() == 'true'
    SCHEDULER_TIMEZONE = os.environ.get('SCHEDULER_TIMEZONE', 'Asia/Shanghai')

    # 默认 AI 配置
    DEFAULT_AI_ENDPOINT = os.environ.get('AI_ENDPOINT', 'https://api.deepseek.com/v1/chat/completions')
    DEFAULT_AI_MODEL = os.environ.get('AI_MODEL', 'deepseek-chat')

    # 数据目录
    DATA_DIR = os.environ.get('DATA_DIR') or os.path.join(basedir, 'data')

    @staticmethod
    def init_app(app):
        # 确保数据目录存在
        os.makedirs(Config.DATA_DIR, exist_ok=True)
