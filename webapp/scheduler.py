"""
定时任务调度器
"""
from datetime import datetime, timedelta
from models import db, Settings, MonitoredChat, ChatMessage, AISummary, Task, AutoJob
from chat_service import ChatService


def init_scheduler(scheduler, app):
    """初始化定时任务 - 加载所有启用的自动任务"""
    with app.app_context():
        # 加载所有启用的自动任务
        jobs = AutoJob.query.filter_by(enabled=True).all()
        for job in jobs:
            _add_job_to_scheduler(scheduler, app, job)
            print(f"已加载自动任务: {job.name}")

        print(f"定时任务调度器已启动，共加载 {len(jobs)} 个自动任务")


def _add_job_to_scheduler(scheduler, app, job):
    """添加任务到调度器"""
    job_id = f'auto_job_{job.id}'

    # 先移除可能存在的旧任务
    if scheduler.get_job(job_id):
        scheduler.remove_job(job_id)

    if job.schedule_type == 'interval':
        scheduler.add_job(
            id=job_id,
            func=execute_auto_job,
            args=[app, job.id],
            trigger='interval',
            minutes=job.interval_minutes,
            replace_existing=True
        )
    else:  # cron
        scheduler.add_job(
            id=job_id,
            func=execute_auto_job,
            args=[app, job.id],
            trigger='cron',
            hour=job.cron_hour,
            minute=job.cron_minute,
            replace_existing=True
        )


def execute_auto_job(app, job_id):
    """执行自动任务"""
    with app.app_context():
        job = AutoJob.query.get(job_id)
        if not job:
            return "任务不存在"

        print(f"开始执行自动任务: {job.name} (类型: {job.job_type})")

        try:
            if job.job_type == 'fetch_messages':
                result = _execute_fetch_messages(job)
            elif job.job_type == 'ai_summary':
                result = _execute_ai_summary(job)
            elif job.job_type == 'extract_tasks':
                result = _execute_extract_tasks(job)
            else:
                result = f"未知任务类型: {job.job_type}"

            # 更新执行状态
            job.last_run_time = datetime.now()
            job.last_run_status = 'success'
            job.last_run_message = result
            db.session.commit()

            print(f"自动任务完成: {job.name} - {result}")
            return result

        except Exception as e:
            job.last_run_time = datetime.now()
            job.last_run_status = 'failed'
            job.last_run_message = str(e)
            db.session.commit()

            print(f"自动任务失败: {job.name} - {e}")
            raise


def _execute_fetch_messages(job):
    """执行获取消息任务"""
    settings = Settings.get_settings()
    chat_service = ChatService(settings)

    # 确定要获取的聊天
    if job.chat_id:
        chats = [MonitoredChat.query.get(job.chat_id)]
    else:
        chats = MonitoredChat.query.filter_by(enabled=True).all()

    total_new = 0
    for chat in chats:
        if not chat:
            continue

        try:
            messages = chat_service.fetch_messages(
                chat_type=chat.chat_type,
                peer_id=chat.peer_id,
                peer_uid=chat.peer_uid,
                days=job.days
            )

            new_count = 0
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
                    new_count += 1

            chat.last_fetch_time = datetime.now()
            db.session.commit()
            total_new += new_count
            print(f"  {chat.name}: 新增 {new_count} 条消息")

        except Exception as e:
            print(f"  {chat.name}: 获取失败 - {e}")
            db.session.rollback()

    return f"获取完成，共新增 {total_new} 条消息"


def _execute_ai_summary(job):
    """执行 AI 总结任务"""
    from ai_service import AIService

    settings = Settings.get_settings()
    if not settings.ai_api_key:
        return "未配置 AI API Key"

    ai_service = AIService(settings)

    end_time = datetime.now()
    start_time = end_time - timedelta(days=job.days)

    # 确定要总结的聊天
    if job.chat_id:
        chats = [MonitoredChat.query.get(job.chat_id)]
    else:
        chats = MonitoredChat.query.filter_by(enabled=True).all()

    summary_count = 0
    task_count = 0

    for chat in chats:
        if not chat:
            continue

        messages = ChatMessage.query.filter(
            ChatMessage.chat_id == chat.id,
            ChatMessage.msg_time >= start_time,
            ChatMessage.msg_time <= end_time
        ).order_by(ChatMessage.msg_time.asc()).all()

        if not messages:
            print(f"  {chat.name}: 没有消息，跳过")
            continue

        try:
            # 生成总结
            summary_text = ai_service.generate_summary(messages)
            summary = AISummary(
                chat_id=chat.id,
                summary_type='auto',
                date_range_start=start_time,
                date_range_end=end_time,
                summary_text=summary_text
            )
            db.session.add(summary)
            summary_count += 1

            # 如果启用了任务提取
            if job.extract_tasks:
                # 筛选未处理的消息用于提取任务
                unprocessed_messages = [
                    m for m in messages 
                    if not m.ai_processed
                ]
                
                if unprocessed_messages:
                    tasks_data = ai_service.extract_tasks(unprocessed_messages)
                    
                    new_tasks_count = 0
                    for t in tasks_data:
                        if not t.get('title'):
                            continue
                        title = t['title'].strip()

                        task = Task(
                            chat_id=chat.id,
                            title=title,
                            description=t.get('description'),
                            priority=t.get('priority', 3),
                            deadline=datetime.fromisoformat(t['deadline']) if t.get('deadline') else None,
                            source_message=t.get('source_message'),
                            ai_analysis=t.get('analysis')
                        )
                        db.session.add(task)
                        new_tasks_count += 1
                        task_count += 1
                    
                    # 标记消息为已处理
                    now = datetime.now()
                    for msg in unprocessed_messages:
                        msg.ai_processed = True
                        msg.ai_processed_at = now
                    
                    print(f"  {chat.name}: 提取 {new_tasks_count} 个新任务")

            db.session.commit()
            print(f"  {chat.name}: 总结完成")

        except Exception as e:
            print(f"  {chat.name}: 总结失败 - {e}")
            db.session.rollback()

    return f"生成 {summary_count} 个总结，提取 {task_count} 个任务"


def _execute_extract_tasks(job):
    """执行任务提取"""
    from ai_service import AIService

    settings = Settings.get_settings()
    if not settings.ai_api_key:
        return "未配置 AI API Key"

    ai_service = AIService(settings)

    end_time = datetime.now()
    start_time = end_time - timedelta(days=job.days)

    # 确定要处理的聊天
    if job.chat_id:
        chats = [MonitoredChat.query.get(job.chat_id)]
    else:
        chats = MonitoredChat.query.filter_by(enabled=True).all()

    task_count = 0

    for chat in chats:
        if not chat:
            continue

        messages = ChatMessage.query.filter(
            ChatMessage.chat_id == chat.id,
            ChatMessage.msg_time >= start_time,
            ChatMessage.msg_time <= end_time,
            db.or_(
                ChatMessage.ai_processed == False,
                ChatMessage.ai_processed.is_(None)
            )
        ).order_by(ChatMessage.msg_time.asc()).all()

        if not messages:
            continue

        try:
            tasks_data = ai_service.extract_tasks(messages)
            
            chat_new_count = 0
            for t in tasks_data:
                if not t.get('title'):
                    continue
                title = t['title'].strip()

                task = Task(
                    chat_id=chat.id,
                    title=title,
                    description=t.get('description'),
                    priority=t.get('priority', 3),
                    deadline=datetime.fromisoformat(t['deadline']) if t.get('deadline') else None,
                    source_message=t.get('source_message'),
                    ai_analysis=t.get('analysis')
                )
                db.session.add(task)
                task_count += 1
                chat_new_count += 1
            
            # 标记消息为已处理
            now = datetime.now()
            for msg in messages:
                msg.ai_processed = True
                msg.ai_processed_at = now

            db.session.commit()
            print(f"  {chat.name}: 提取 {chat_new_count} 个新任务 (AI返回 {len(tasks_data)} 个)")

        except Exception as e:
            print(f"  {chat.name}: 提取失败 - {e}")
            db.session.rollback()

    return f"共提取 {task_count} 个任务"


# ==================== Legacy Scheduler Helpers ====================

def fetch_all_messages(app):
    """
    获取所有消息任务 (用于 legacy scheduler 接口)
    """
    with app.app_context():
        settings = Settings.get_settings()
        chat_service = ChatService(settings)

        chats = MonitoredChat.query.filter_by(enabled=True).all()
        total_new = 0
        
        print(f"开始执行 fetch_all_messages, 聊天数: {len(chats)}")

        for chat in chats:
            try:
                messages = chat_service.fetch_messages(
                    chat_type=chat.chat_type,
                    peer_id=chat.peer_id,
                    peer_uid=chat.peer_uid,
                    days=settings.fetch_days
                )

                new_count = 0
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
                        new_count += 1

                chat.last_fetch_time = datetime.now()
                db.session.commit()
                total_new += new_count
                print(f"  {chat.name}: 新增 {new_count} 条消息")

            except Exception as e:
                print(f"  {chat.name}: 获取失败 - {e}")
                db.session.rollback()

        return f"获取完成，共新增 {total_new} 条消息"


def generate_daily_summary(app):
    """
    生成每日总结 (用于 legacy scheduler 接口)
    """
    with app.app_context():
        from ai_service import AIService
        settings = Settings.get_settings()
        
        if not settings.ai_api_key:
            print("未配置 AI API Key，跳过自动总结")
            return

        ai_service = AIService(settings)
        
        # 总结过去 24 小时
        end_time = datetime.now()
        start_time = end_time - timedelta(days=1)
        
        chats = MonitoredChat.query.filter_by(enabled=True).all()
        summary_count = 0
        
        print(f"开始执行 generate_daily_summary, 聊天数: {len(chats)}")

        for chat in chats:
            messages = ChatMessage.query.filter(
                ChatMessage.chat_id == chat.id,
                ChatMessage.msg_time >= start_time,
                ChatMessage.msg_time <= end_time
            ).order_by(ChatMessage.msg_time.asc()).all()

            if not messages:
                continue

            try:
                summary_text = ai_service.generate_summary(messages)
                summary = AISummary(
                    chat_id=chat.id,
                    summary_type='auto',
                    date_range_start=start_time,
                    date_range_end=end_time,
                    summary_text=summary_text
                )
                db.session.add(summary)
                db.session.commit()
                summary_count += 1
                print(f"  {chat.name}: 总结完成")

            except Exception as e:
                print(f"  {chat.name}: 总结失败 - {e}")
                db.session.rollback()
                
        return f"生成 {summary_count} 个总结"
