"""
QQ 聊天记录 AI 助手 - Flask 应用主入口
"""
import os
from flask import Flask
from flask_apscheduler import APScheduler

from config import Config
from models import db
from routes import main_bp
from api import api_bp
from scheduler import init_scheduler

def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    # 初始化数据库
    db.init_app(app)

    # 注册蓝图
    app.register_blueprint(main_bp)
    app.register_blueprint(api_bp, url_prefix='/api')

    # 初始化定时任务调度器
    scheduler = APScheduler()
    scheduler.init_app(app)

    # 将 scheduler 存储到 app 上，方便其他地方访问
    app.scheduler = scheduler

    with app.app_context():
        db.create_all()
        init_scheduler(scheduler, app)

    scheduler.start()

    return app

if __name__ == '__main__':
    app = create_app()
    host = os.environ.get('FLASK_HOST', '0.0.0.0')
    port = int(os.environ.get('FLASK_PORT', 5000))
    debug = os.environ.get('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(debug=debug, host=host, port=port)
