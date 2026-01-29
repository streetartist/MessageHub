from flask import Blueprint

api_bp = Blueprint('api', __name__)

from . import settings, chats, messages, summaries, tasks, auto_jobs, stats, schedule
