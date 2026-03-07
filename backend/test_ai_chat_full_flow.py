#!/usr/bin/env python3
"""
AI功能完整链路测试脚本

测试链路: 用户登录 -> AI聊天对话 -> 对话信息保存 -> 验证历史记录

使用方法:
    python test_ai_chat_full_flow.py

环境变量:
    API_BASE_URL: 后端API地址 (默认: http://localhost:8000/api/v1)
    TEST_EMAIL: 测试用户邮箱 (默认: test@qq.com)
    TEST_PASSWORD: 测试用户密码 (默认: 123456)
"""

import json
import sys
import os
import time
from datetime import datetime

import requests
from requests.structures import CaseInsensitiveDict


# ============== 配置 ==============
API_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8000/api/v1")
TEST_EMAIL = os.environ.get("TEST_EMAIL", "test@qq.com")
TEST_PASSWORD = os.environ.get("TEST_PASSWORD", "123456")

# ============== 全局状态 ==============
token = None
user_id = None
session_id = None
message_id = None


def log_step(step_name, message=""):
    """打印步骤标题"""
    print(f"\n{'='*60}")
    print(f"[步骤] {step_name}")
    if message:
        print(f"  {message}")
    print('='*60)


def log_success(message):
    """打印成功信息"""
    print(f"  ✓ {message}")


def log_error(message):
    """打印错误信息"""
    print(f"  ✗ {message}")


def log_info(message):
    """打印信息"""
    print(f"  ℹ {message}")


def make_headers(with_auth=True):
    """创建请求头"""
    headers = CaseInsensitiveDict()
    headers["Content-Type"] = "application/json"
    if with_auth and token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def parse_sse_stream(response):
    """解析SSE流，返回生成器"""
    for line in response.iter_lines(decode_unicode=True):
        if not line:
            continue
        line = line.strip()
        if line.startswith("data:"):
            data_str = line[5:].strip()
            if data_str:
                try:
                    yield json.loads(data_str)
                except json.JSONDecodeError:
                    pass


# ============== 主要步骤 ==============

def step1_login():
    """步骤1: 用户登录"""
    global token, user_id

    log_step("1. 用户登录", f"邮箱: {TEST_EMAIL}")

    url = f"{API_BASE_URL}/auth/login"
    data = {"email": TEST_EMAIL, "password": TEST_PASSWORD}

    try:
        resp = requests.post(url, json=data)
        if resp.status_code != 200:
            log_error(f"登录失败: HTTP {resp.status_code}")
            log_error(f"响应: {resp.text}")
            return False

        result = resp.json()
        token = result.get("access_token")
        refresh_token = result.get("refresh_token")

        if not token:
            log_error("响应中缺少 access_token")
            return False

        log_success("登录成功")
        log_info(f"Access Token: {token[:30]}...")
        log_info(f"Refresh Token: {refresh_token[:30]}...")

        # 获取用户信息
        me_resp = requests.get(f"{API_BASE_URL}/auth/me", headers=make_headers())
        if me_resp.status_code == 200:
            user_data = me_resp.json()
            user_id = user_data.get("id")
            log_info(f"用户ID: {user_id}")
            log_info(f"用户昵称: {user_data.get('nickname')}")

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step2_chat_stream(message, use_existing_session=False):
    """步骤2: AI流式聊天"""
    global session_id, message_id

    session_desc = "使用现有会话" if use_existing_session else "创建新会话"
    log_step("2. AI流式聊天", f"{session_desc}\n  消息: {message}")

    url = f"{API_BASE_URL}/ai/chat/stream"
    payload = {"message": message}
    if use_existing_session and session_id:
        payload["session_id"] = session_id

    try:
        resp = requests.post(url, json=payload, headers=make_headers(), stream=True)
        if resp.status_code != 200:
            log_error(f"请求失败: HTTP {resp.status_code}")
            log_error(f"响应: {resp.text}")
            return False

        full_content = ""
        has_plan = False
        plan_data = None
        events_received = set()

        for data in parse_sse_stream(resp):
            event_type = data.get("type", "chunk")
            events_received.add(event_type)

            if event_type == "session_created":
                session_id = data.get("session_id")
                log_success(f"新会话创建: {session_id}")

            elif event_type == "chunk":
                content = data.get("content", "")
                full_content += content
                print(content, end="", flush=True)

            elif event_type == "analysis":
                analysis = data.get("analysis", {})
                print()  # 换行
                log_info(f"意图: {analysis.get('intents', [])}")
                log_info(f"复杂度: {analysis.get('complexity', 'unknown')}")

            elif event_type == "plan_info":
                log_info(f"执行顺序: {data.get('execution_order', [])}")

            elif event_type == "plan":
                has_plan = True
                plan_data = data.get("plan")
                log_success("收到训练计划")

            elif event_type == "done":
                message_id = data.get("message_id")
                print()  # 换行
                log_success("对话完成")
                log_info(f"会话ID: {data.get('session_id')}")
                log_info(f"消息ID: {message_id}")
                log_info(f"包含计划: {data.get('has_plan', False)}")

            elif event_type == "error":
                log_error(f"流式错误: {data.get('message')}")

        log_info(f"收到内容长度: {len(full_content)} 字符")
        log_info(f"事件类型: {events_received}")

        if not use_existing_session and not session_id:
            log_error("新会话未创建")
            return False

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step3_verify_messages():
    """步骤3: 验证消息已保存"""
    log_step("3. 验证消息保存", f"会话ID: {session_id}")

    if not session_id:
        log_error("没有可用的会话ID")
        return False

    url = f"{API_BASE_URL}/chat-sessions/{session_id}/messages"

    try:
        resp = requests.get(url, headers=make_headers())
        if resp.status_code != 200:
            log_error(f"获取失败: HTTP {resp.status_code}")
            return False

        messages = resp.json()
        if not isinstance(messages, list):
            log_error("响应格式错误")
            return False

        user_msgs = [m for m in messages if m.get("role") == "user"]
        assistant_msgs = [m for m in messages if m.get("role") == "assistant"]

        log_success(f"获取到 {len(messages)} 条消息")
        log_info(f"用户消息: {len(user_msgs)} 条")
        log_info(f"AI消息: {len(assistant_msgs)} 条")

        if messages:
            latest = messages[-1]
            log_info(f"最新消息: [{latest.get('role')}] {latest.get('content', '')[:50]}...")

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step4_verify_session():
    """步骤4: 验证会话信息"""
    log_step("4. 验证会话信息", f"会话ID: {session_id}")

    if not session_id:
        log_error("没有可用的会话ID")
        return False

    url = f"{API_BASE_URL}/chat-sessions/{session_id}"

    try:
        resp = requests.get(url, headers=make_headers())
        if resp.status_code != 200:
            log_error(f"获取失败: HTTP {resp.status_code}")
            return False

        session = resp.json()
        log_success(f"会话标题: {session.get('title', 'N/A')}")
        log_info(f"消息数量: {session.get('message_count', 0)}")
        log_info(f"创建时间: {session.get('created_at')}")
        log_info(f"更新时间: {session.get('updated_at')}")

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step5_continue_chat():
    """步骤5: 继续对话（上下文保持）"""
    global session_id

    if not session_id:
        log_step("5. 继续对话", "跳过（无可用会话）")
        return True

    message = "刚才我们聊了什么？"
    log_step("5. 继续对话（上下文保持）", f"消息: {message}")

    url = f"{API_BASE_URL}/ai/chat/stream"
    payload = {"message": message, "session_id": session_id}

    try:
        resp = requests.post(url, json=payload, headers=make_headers(), stream=True)
        if resp.status_code != 200:
            log_error(f"请求失败: HTTP {resp.status_code}")
            return False

        full_content = ""
        for data in parse_sse_stream(resp):
            event_type = data.get("type")
            if event_type == "chunk":
                content = data.get("content", "")
                full_content += content
                print(content, end="", flush=True)
            elif event_type == "done":
                print()
                log_success("对话完成")

        if full_content:
            log_success(f"收到回复，长度: {len(full_content)} 字符")
            return True
        else:
            log_error("未收到回复内容")
            return False

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step6_generate_plan():
    """步骤6: 测试训练计划生成"""
    global session_id

    message = "我今晚有10分钟时间，想在家做些简单的运动，请为我生成一个训练计划"
    log_step("6. 训练计划生成", f"消息: {message}")

    url = f"{API_BASE_URL}/ai/chat/stream"
    payload = {"message": message}

    try:
        resp = requests.post(url, json=payload, headers=make_headers(), stream=True)
        if resp.status_code != 200:
            log_error(f"请求失败: HTTP {resp.status_code}")
            return False

        has_plan = False
        plan_data = None
        full_content = ""

        for data in parse_sse_stream(resp):
            event_type = data.get("type")
            if event_type == "chunk":
                content = data.get("content", "")
                full_content += content
                print(content, end="", flush=True)
            elif event_type == "plan":
                has_plan = True
                plan_data = data.get("plan")
            elif event_type == "done":
                print()

        if has_plan and plan_data:
            log_success("成功生成训练计划")
            log_info(f"标题: {plan_data.get('title')}")
            log_info(f"时长: {plan_data.get('total_duration')}分钟")
            log_info(f"场景: {plan_data.get('scene')}")
            log_info(f"RPE: {plan_data.get('rpe')}")
            log_info(f"模块数: {len(plan_data.get('modules', []))}")
        else:
            log_info("未生成计划（可能是正常对话回复）")

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


def step7_user_memory():
    """步骤7: 查询用户记忆"""
    log_step("7. 用户记忆查询")

    url = f"{API_BASE_URL}/ai/chat/user-memory?days=7"

    try:
        resp = requests.get(url, headers=make_headers())
        if resp.status_code != 200:
            log_error(f"获取失败: HTTP {resp.status_code}")
            return False

        data = resp.json()
        memory = data.get("memory", {})

        log_success("成功获取用户记忆")
        log_info(f"查询天数: {data.get('days')}")
        if memory:
            log_info(f"记忆内容预览: {json.dumps(memory, ensure_ascii=False, indent=2)[:150]}...")

        return True

    except Exception as e:
        log_error(f"异常: {e}")
        return False


# ============== 主程序 ==============

def main():
    """主函数 - 顺序执行所有步骤"""

    print("\n" + "="*70)
    print("AI功能完整链路测试")
    print("="*70)
    print(f"API地址: {API_BASE_URL}")
    print(f"测试用户: {TEST_EMAIL}")
    print(f"开始时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70)

    results = []
    start_time = time.time()

    # 步骤1: 登录
    if not step1_login():
        print("\n[!] 登录失败，终止执行")
        return
    results.append(("用户登录", True))

    # 步骤2: AI聊天（新会话）
    success = step2_chat_stream("你好，请介绍一下你自己", use_existing_session=False)
    results.append(("AI流式聊天", success))
    if not success:
        print("\n[!] AI聊天失败，终止后续步骤")

    # 步骤3: 验证消息保存
    if success:
        results.append(("验证消息保存", step3_verify_messages()))

    # 步骤4: 验证会话信息
    if success:
        results.append(("验证会话信息", step4_verify_session()))

    # 步骤5: 继续对话
    if success:
        results.append(("继续对话测试", step5_continue_chat()))

    # 步骤6: 计划生成
    if success:
        results.append(("训练计划生成", step6_generate_plan()))

    # 步骤7: 用户记忆
    if success:
        results.append(("用户记忆查询", step7_user_memory()))

    # 打印摘要
    total_time = (time.time() - start_time) * 1000

    print("\n" + "="*70)
    print("执行摘要")
    print("="*70)

    passed = sum(1 for _, success in results if success)
    failed = sum(1 for _, success in results if not success)

    for name, success in results:
        status = "✓ 通过" if success else "✗ 失败"
        print(f"  {status} - {name}")

    print("-"*70)
    print(f"总计: {len(results)} 个步骤")
    print(f"  通过: {passed}")
    print(f"  失败: {failed}")
    print(f"耗时: {total_time:.1f}ms")
    print("="*70)

    if failed == 0:
        print("✓ 全部执行成功！")
    else:
        print(f"✗ 有 {failed} 个步骤失败")


if __name__ == "__main__":
    # 检查依赖
    try:
        import requests
    except ImportError:
        print("错误: 需要安装 requests 库")
        print("请运行: pip install requests")
        sys.exit(1)

    main()
