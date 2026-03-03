#!/usr/bin/env python3
"""
Chat Stream 调试脚本

用于本地调试 /chat/stream 接口，支持交互式输入和流式响应解析

使用方法:
    python chat_stream_debug.py
"""

import json
import sys
import requests
from requests.structures import CaseInsensitiveDict


def parse_sse(response):
    """简单解析 SSE 流"""
    buffer = ""
    for chunk in response.iter_content(chunk_size=None, decode_unicode=True):
        if chunk:
            buffer += chunk
            while '\n' in buffer:
                line, buffer = buffer.split('\n', 1)
                line = line.strip()
                if not line:
                    continue
                if line.startswith('data:'):
                    yield line[5:].strip()

# ============== 配置 ==============
API_BASE_URL = "http://localhost:8000/api/v1"
EMAIL = "test@example.com"  # 替换为测试用户邮箱
PASSWORD = "123456"  # 替换为测试用户密码

# ============== 全局变量 ==============
token = None
session_id = None


def login(email: str, password: str) -> str:
    """登录获取 token"""
    url = f"{API_BASE_URL}/auth/login"
    data = {
        "email": email,
        "password": password
    }

    print(f"正在登录: {email}...")
    response = requests.post(url, json=data)

    if response.status_code != 200:
        print(f"登录失败: {response.status_code}")
        print(f"响应内容: {response.text}")
        sys.exit(1)

    result = response.json()
    access_token = result.get("access_token")
    print(f"登录成功! Token: {access_token[:20]}...")
    return access_token


def send_chat_stream(message: str):
    """发送聊天消息并接收流式响应"""
    url = f"{API_BASE_URL}/ai/chat/stream"

    headers = CaseInsensitiveDict()
    headers["Authorization"] = f"Bearer {token}"
    headers["Content-Type"] = "application/json"

    payload = {
        "message": message
    }
    if session_id:
        payload["session_id"] = session_id

    print(f"\n发送消息: {message}")
    if session_id:
        print(f"会话ID: {session_id}")
    print("-" * 50)

    response = requests.post(url, json=payload, headers=headers, stream=True)

    if response.status_code != 200:
        print(f"请求失败: {response.status_code}")
        print(f"响应内容: {response.text}")
        return None

    # 解析 SSE 流
    full_content = ""
    plan_data = None

    for raw_data in parse_sse(response):
        if not raw_data:
            continue

        try:
            data = json.loads(raw_data)
            event_type = data.get("type", "chunk")

            if event_type == "session_created":
                global session_id
                session_id = data.get("session_id")
                print(f"[会话] 新会话创建: {session_id}")

            elif event_type == "analysis":
                analysis = data.get("analysis", {})
                print(f"[分析] 意图: {analysis.get('intents')}")
                print(f"[分析] 复杂度: {analysis.get('complexity')}")
                print(f"[分析] 所需工具: {analysis.get('required_tools')}")

            elif event_type == "plan_info":
                print(f"[计划] 执行顺序: {data.get('execution_order')}")
                print(f"[计划] 并行组: {data.get('parallel_groups')}")

            elif event_type == "metadata":
                print(f"[元数据] 意图: {data.get('intent')}, 置信度: {data.get('confidence')}")

            elif event_type == "chunk":
                content = data.get("content", "")
                full_content += content
                # 实时打印内容
                print(content, end="", flush=True)

            elif event_type == "plan":
                plan_data = data.get("plan")
                print(f"\n\n[计划] 收到训练计划!")
                print(f"  标题: {plan_data.get('title')}")
                print(f"  副标题: {plan_data.get('subtitle')}")
                print(f"  时长: {plan_data.get('total_duration')} 分钟")
                print(f"  场景: {plan_data.get('scene')}")
                print(f"  RPE: {plan_data.get('rpe')}")
                print(f"  模块数量: {len(plan_data.get('modules', []))}")

                # 打印模块详情
                for i, module in enumerate(plan_data.get("modules", [])):
                    print(f"\n  模块 {i+1}: {module.get('name')}")
                    for j, exercise in enumerate(module.get("exercises", [])):
                        print(f"    - {exercise.get('name')}: {exercise.get('duration')}秒 x {exercise.get('sets')}组")

            elif event_type == "done":
                print(f"\n\n[完成] 会话ID: {data.get('session_id')}")
                print(f"[完成] 包含计划: {data.get('has_plan')}")
                return session_id

            elif event_type == "error":
                print(f"\n[错误] {data.get('message')}")

            else:
                print(f"\n[未知事件] {event_type}: {data}")

        except json.JSONDecodeError as e:
            print(f"\n[JSON解析错误] {e}, 数据: {raw_data}")

    return session_id


def interactive_mode():
    """交互式聊天模式"""
    global session_id

    print("\n" + "=" * 50)
    print("Chat Stream 交互式调试模式")
    print("=" * 50)
    print(f"API地址: {API_BASE_URL}")
    print(f"登录邮箱: {EMAIL}")
    print("-" * 50)
    print("命令说明:")
    print("  - 直接输入消息发送")
    print("  - :new - 创建新会话")
    print("  - :quit 或 :exit - 退出程序")
    print("  - :help - 显示帮助")
    print("=" * 50 + "\n")

    while True:
        try:
            user_input = input("\n请输入消息: ").strip()

            if not user_input:
                continue

            if user_input in [":quit", ":exit", "q"]:
                print("退出程序")
                break

            elif user_input == ":new":
                session_id = None
                print("已创建新会话")

            elif user_input == ":help":
                print("命令说明:")
                print("  - 直接输入消息发送")
                print("  - :new - 创建新会话")
                print("  - :quit 或 :exit - 退出程序")
                print("  - :help - 显示帮助")

            else:
                session_id = send_chat_stream(user_input)

        except KeyboardInterrupt:
            print("\n\n退出程序")
            break
        except Exception as e:
            print(f"\n错误: {e}")


def main():
    global token, session_id

    print("=" * 50)
    print("Chat Stream 接口调试工具")
    print("=" * 50)

    # 登录获取 token
    token = login(EMAIL, PASSWORD)

    # 进入交互模式
    interactive_mode()


if __name__ == "__main__":
    main()
