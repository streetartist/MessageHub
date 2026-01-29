from flask import request, jsonify, current_app
from . import api_bp
from models import db, AutoJob
from scheduler import execute_auto_job

@api_bp.route('/auto-jobs', methods=['GET'])
def get_auto_jobs():
    """获取所有自动任务"""
    jobs = AutoJob.query.order_by(AutoJob.created_at.desc()).all()
    return jsonify({
        'jobs': [{
            'id': j.id,
            'name': j.name,
            'job_type': j.job_type,
            'enabled': j.enabled,
            'schedule_type': j.schedule_type,
            'interval_minutes': j.interval_minutes,
            'cron_hour': j.cron_hour,
            'cron_minute': j.cron_minute,
            'chat_id': j.chat_id,
            'days': j.days,
            'extract_tasks': j.extract_tasks,
            'last_run_time': j.last_run_time.isoformat() if j.last_run_time else None,
            'last_run_status': j.last_run_status,
            'last_run_message': j.last_run_message,
            'created_at': j.created_at.isoformat()
        } for j in jobs]
    })


@api_bp.route('/auto-jobs', methods=['POST'])
def create_auto_job():
    """创建自动任务"""
    data = request.json

    job = AutoJob(
        name=data['name'],
        job_type=data['job_type'],
        enabled=data.get('enabled', True),
        schedule_type=data.get('schedule_type', 'interval'),
        interval_minutes=data.get('interval_minutes', 60),
        cron_hour=data.get('cron_hour', 22),
        cron_minute=data.get('cron_minute', 0),
        chat_id=data.get('chat_id'),
        days=data.get('days', 1),
        extract_tasks=data.get('extract_tasks', True)
    )
    db.session.add(job)
    db.session.commit()

    # 如果启用，添加到调度器
    if job.enabled:
        _add_job_to_scheduler(job)

    return jsonify({'success': True, 'id': job.id})


@api_bp.route('/auto-jobs/<int:job_id>', methods=['PUT'])
def update_auto_job(job_id):
    """更新自动任务"""
    job = AutoJob.query.get_or_404(job_id)
    data = request.json

    # 先从调度器移除旧任务
    _remove_job_from_scheduler(job)

    if 'name' in data:
        job.name = data['name']
    if 'job_type' in data:
        job.job_type = data['job_type']
    if 'enabled' in data:
        job.enabled = data['enabled']
    if 'schedule_type' in data:
        job.schedule_type = data['schedule_type']
    if 'interval_minutes' in data:
        job.interval_minutes = data['interval_minutes']
    if 'cron_hour' in data:
        job.cron_hour = data['cron_hour']
    if 'cron_minute' in data:
        job.cron_minute = data['cron_minute']
    if 'chat_id' in data:
        job.chat_id = data['chat_id']
    if 'days' in data:
        job.days = data['days']
    if 'extract_tasks' in data:
        job.extract_tasks = data['extract_tasks']

    db.session.commit()

    # 如果启用，重新添加到调度器
    if job.enabled:
        _add_job_to_scheduler(job)

    return jsonify({'success': True})


@api_bp.route('/auto-jobs/<int:job_id>', methods=['DELETE'])
def delete_auto_job(job_id):
    """删除自动任务"""
    job = AutoJob.query.get_or_404(job_id)

    # 从调度器移除
    _remove_job_from_scheduler(job)

    db.session.delete(job)
    db.session.commit()
    return jsonify({'success': True})


@api_bp.route('/auto-jobs/<int:job_id>/toggle', methods=['POST'])
def toggle_auto_job(job_id):
    """切换自动任务启用状态"""
    job = AutoJob.query.get_or_404(job_id)
    job.enabled = not job.enabled
    db.session.commit()

    if job.enabled:
        _add_job_to_scheduler(job)
    else:
        _remove_job_from_scheduler(job)

    return jsonify({'success': True, 'enabled': job.enabled})


@api_bp.route('/auto-jobs/<int:job_id>/run', methods=['POST'])
def run_auto_job_now(job_id):
    """立即执行自动任务"""
    job = AutoJob.query.get_or_404(job_id)

    try:
        result = execute_auto_job(current_app._get_current_object(), job.id)
        return jsonify({'success': True, 'message': result})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})


def _add_job_to_scheduler(job):
    """添加任务到调度器"""
    scheduler = getattr(current_app, 'scheduler', None)
    if not scheduler:
        return

    job_id = f'auto_job_{job.id}'

    # 先移除可能存在的旧任务
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)

    if job.schedule_type == 'interval':
        scheduler.add_job(
            id=job_id,
            func=execute_auto_job,
            args=[current_app._get_current_object(), job.id],
            trigger='interval',
            minutes=job.interval_minutes,
            replace_existing=True
        )
    else:  # cron
        scheduler.add_job(
            id=job_id,
            func=execute_auto_job,
            args=[current_app._get_current_object(), job.id],
            trigger='cron',
            hour=job.cron_hour,
            minute=job.cron_minute,
            replace_existing=True
        )


def _remove_job_from_scheduler(job):
    """从调度器移除任务"""
    scheduler = getattr(current_app, 'scheduler', None)
    if not scheduler:
        return

    job_id = f'auto_job_{job.id}'
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)
