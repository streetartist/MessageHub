"""
聊天服务 - 与 napcat-qce 交互
"""
import sys
import os
from datetime import datetime, timedelta

# 添加父目录到路径以导入 napcat_qce
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from napcat_qce import connect, MessageFilter
from napcat_qce.auto_token import auto_discover_token


class ChatService:
    """聊天服务类"""

    def __init__(self, settings):
        self.settings = settings
        self._client = None

    def get_client(self):
        """获取 NapCat 客户端（自动获取令牌）"""
        if self._client is None:
            # 使用 connect() 自动获取令牌
            # 确保 host 和 port 有有效值（数据库可能为空）
            host = self.settings.napcat_host if self.settings.napcat_host else 'localhost'
            port = self.settings.napcat_port if self.settings.napcat_port else 40653
            self._client = connect(
                host=host,
                port=port
            )
        return self._client

    @staticmethod
    def test_connection(host='localhost', port=40653):
        """测试 NapCat 连接并检查令牌"""
        try:
            token = auto_discover_token(host, port)
            if not token:
                return False, "未找到令牌。请确保 NapCat-QCE 服务正在运行。"

            client = connect(host=host, port=port)
            # 尝试获取系统信息来验证连接
            info = client.system.get_info()
            return True, f"连接成功！令牌已自动获取。"
        except Exception as e:
            return False, f"连接失败: {str(e)}"

    @staticmethod
    def get_token_status():
        """获取令牌状态"""
        token = auto_discover_token()
        if token:
            # 只显示前8位和后4位
            masked = token[:8] + '****' + token[-4:] if len(token) > 12 else '****'
            return True, masked
        return False, None

    def get_available_chats(self):
        """获取可用的好友和群列表"""
        client = self.get_client()

        # 获取好友列表
        friends_data = client.friends.get_all(page=1, limit=999)
        friends = [{
            'uin': f.uin,
            'uid': f.uid,
            'name': f.remark or f.nick,
            'nick': f.nick,
            'remark': f.remark,
            'is_online': f.is_online
        } for f in friends_data]

        # 获取群列表
        groups_data = client.groups.get_all(page=1, limit=999)
        groups = [{
            'group_code': g.group_code,
            'group_name': g.group_name,
            'member_count': g.member_count,
            'max_member': g.max_member
        } for g in groups_data]

        return friends, groups

    def fetch_messages(self, chat_type, peer_id, peer_uid, days=1):
        """获取聊天消息

        Args:
            chat_type: 1=私聊, 2=群聊
            peer_id: 好友QQ号或群号
            peer_uid: UID（用于API调用）
            days: 获取最近几天的消息

        Returns:
            消息列表
        """
        client = self.get_client()

        # 使用时间筛选器
        msg_filter = MessageFilter.last_days(days)

        # 确定使用哪个 ID
        target_id = peer_uid if peer_uid else peer_id

        messages = []
        try:
            result = client.messages.fetch(
                chat_type=chat_type,
                peer_uid=target_id,
                page=1,
                limit=500,
                filter=msg_filter
            )

            for msg in result.get('messages', []):
                # 提取消息内容
                content = self._extract_message_content(msg)

                messages.append({
                    'msg_id': msg.msg_id,
                    'sender_name': msg.sender_member_name or msg.sender_name,
                    'sender_id': getattr(msg, 'sender_uid', None),
                    'content': content,
                    'msg_time': self._parse_msg_time(msg)
                })

        except Exception as e:
            print(f"获取消息失败: {e}")
            raise

        return messages

    def _extract_message_content(self, msg):
        """提取消息内容"""
        # 如果有 raw_data，尝试从中提取
        if hasattr(msg, 'raw_data') and msg.raw_data:
            raw = msg.raw_data
            # 尝试直接获取 content 字段
            if 'content' in raw and raw['content']:
                return raw['content']
            # 尝试获取 text 字段
            if 'text' in raw and raw['text']:
                return raw['text']

            # 从 raw_data 的 elements 中提取
            if 'elements' in raw:
                texts = []
                for elem in raw['elements']:
                    text = self._extract_element_text(elem)
                    if text:
                        texts.append(text)
                if texts:
                    return ''.join(texts)

        # 如果有 elements，尝试拼接文本
        if hasattr(msg, 'elements') and msg.elements:
            texts = []
            for elem in msg.elements:
                # elem.content 是原始的 element 字典
                elem_data = elem.content if hasattr(elem, 'content') else {}
                if isinstance(elem_data, dict):
                    # 文本消息
                    if 'textElement' in elem_data:
                        text_elem = elem_data['textElement']
                        if isinstance(text_elem, dict) and 'content' in text_elem:
                            texts.append(text_elem['content'])
                    # 直接的 content 字段
                    elif 'content' in elem_data:
                        texts.append(str(elem_data['content']))
                    # 直接的 text 字段
                    elif 'text' in elem_data:
                        texts.append(str(elem_data['text']))
                    # 图片
                    elif 'picElement' in elem_data or elem.type == 'pic':
                        texts.append('[图片]')
                    # 表情
                    elif 'faceElement' in elem_data or elem.type == 'face':
                        texts.append('[表情]')
                    # 文件
                    elif 'fileElement' in elem_data or elem.type == 'file':
                        texts.append('[文件]')
                    # 语音
                    elif 'pttElement' in elem_data or elem.type == 'ptt':
                        texts.append('[语音]')
                    # 视频
                    elif 'videoElement' in elem_data or elem.type == 'video':
                        texts.append('[视频]')
                    # @某人
                    elif 'atElement' in elem_data:
                        at_elem = elem_data['atElement']
                        if isinstance(at_elem, dict):
                            at_name = at_elem.get('content', '') or at_elem.get('name', '')
                            texts.append(at_name if at_name else '[@某人]')
                    # 回复
                    elif 'replyElement' in elem_data:
                        texts.append('[回复]')
                    # 根据 elementType 判断
                    elif 'elementType' in elem_data:
                        elem_type = elem_data['elementType']
                        if elem_type == 1:  # 文本
                            if 'textElement' in elem_data:
                                texts.append(elem_data['textElement'].get('content', ''))
                        elif elem_type == 2:  # 图片
                            texts.append('[图片]')
                        elif elem_type == 6:  # 表情
                            texts.append('[表情]')
                        elif elem_type == 4:  # 语音
                            texts.append('[语音]')
                        elif elem_type == 5:  # 视频
                            texts.append('[视频]')
                        elif elem_type == 3:  # 文件
                            texts.append('[文件]')

            if texts:
                return ''.join(texts)

        return ''

    def _extract_element_text(self, elem):
        """从单个 element 字典中提取文本"""
        if not isinstance(elem, dict):
            return ''

        # 文本消息 - textElement
        if 'textElement' in elem:
            text_elem = elem['textElement']
            if isinstance(text_elem, dict):
                return text_elem.get('content', '')

        # 根据 elementType 判断
        elem_type = elem.get('elementType')
        if elem_type == 1:  # 文本
            if 'textElement' in elem:
                return elem['textElement'].get('content', '')
        elif elem_type == 2:  # 图片
            return '[图片]'
        elif elem_type == 3:  # 文件
            return '[文件]'
        elif elem_type == 4:  # 语音
            return '[语音]'
        elif elem_type == 5:  # 视频
            return '[视频]'
        elif elem_type == 6:  # 表情
            face_elem = elem.get('faceElement', {})
            face_text = face_elem.get('faceText', '')
            return f'[{face_text}]' if face_text else '[表情]'
        elif elem_type == 7:  # @
            at_elem = elem.get('atElement', {})
            at_content = at_elem.get('content', '')
            return at_content if at_content else '[@某人]'

        # 其他类型的直接字段
        if 'picElement' in elem:
            return '[图片]'
        if 'faceElement' in elem:
            face_elem = elem['faceElement']
            face_text = face_elem.get('faceText', '') if isinstance(face_elem, dict) else ''
            return f'[{face_text}]' if face_text else '[表情]'
        if 'fileElement' in elem:
            return '[文件]'
        if 'pttElement' in elem:
            return '[语音]'
        if 'videoElement' in elem:
            return '[视频]'
        if 'atElement' in elem:
            at_elem = elem['atElement']
            at_content = at_elem.get('content', '') if isinstance(at_elem, dict) else ''
            return at_content if at_content else '[@某人]'
        if 'replyElement' in elem:
            return ''  # 回复引用不显示内容
        if 'marketFaceElement' in elem:
            return '[表情包]'

        return ''

    def _parse_msg_time(self, msg):
        """解析消息时间"""
        if hasattr(msg, 'msg_time'):
            if isinstance(msg.msg_time, datetime):
                return msg.msg_time
            elif isinstance(msg.msg_time, (int, float)):
                return datetime.fromtimestamp(msg.msg_time)
            elif isinstance(msg.msg_time, str):
                try:
                    return datetime.fromisoformat(msg.msg_time)
                except:
                    pass

        return datetime.now()
