#!/usr/bin/env python3
"""
PlannerAgent 调试脚本

直接调用 Agent 逻辑进行调试，不通过 API 接口

使用方法:
    cd backend
    conda activate python3.12
    python debug_agent.py
"""

import asyncio
import json
import sys
import os

# 确保可以导入 app 模块
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 加载环境变量
from dotenv import load_dotenv
load_dotenv()


# ============== 测试数据 ==============

# 测试用户画像
TEST_USER_PROFILE = {
    "user_id": "test-user-001",
    "nickname": "测试用户",
    "fitness_level": "intermediate",  # beginner/intermediate/advanced
    "goal": "减脂",  # 减脂/增肌/塑形/提高体能
    "scene": "办公室",  # 办公室/居家/健身房/户外
    "time_budget": 15,  # 分钟
    "limitations": ["腰不太好限制"],  # 条件
    "equipment": ["徒手", "弹力带"],  # 可用器材
    "weekly_days": 3,  # 每周训练天数
}

# 测试历史消息
TEST_HISTORY = [
    {"role": "user", "content": "你好，我想开始训练"},
    {"role": "assistant", "content": "你好！很高兴帮助你开始训练。我看到你是初级水平，时间预算15分钟。让我们开始吧！"},
]


async def run_agent_test(user_message: str):
    """运行 Agent 测试"""
    from app.agents.planner_agent import PlannerAgent

    # 创建 Agent 实例
    agent = PlannerAgent()

    # 运行 Agent
    full_content = ""
    plan_data = None

    async for chunk in agent.process(
        user_id=TEST_USER_PROFILE["user_id"],
        session_id="test-session-001",
        user_message=user_message,
        user_profile=TEST_USER_PROFILE,
        history=TEST_HISTORY,
        context_summary="这是一个测试会话",
        recent_memories=[]
    ):
        event_type = chunk.get("type", "chunk")

        if event_type == "analysis":
            analysis = chunk.get("analysis", {})
            print("\n" + "─" * 50)
            print("📊 [分析结果]")
            print(f"   识别意图: {analysis.get('intents')}")
            print(f"   主要意图: {analysis.get('primary_intent')}")
            print(f"   复杂度: {analysis.get('complexity')}")
            print(f"   实体: {analysis.get('entities')}")
            print("─" * 50)

        elif event_type == "plan_info":
            print("\n" + "─" * 50)
            print("📋 [规划结果]")
            print(f"   执行顺序: {chunk.get('execution_order')}")
            print(f"   并行组: {chunk.get('parallel_groups')}")
            print(f"   需要协作: {chunk.get('requires_collaboration')}")
            print("─" * 50)

        elif event_type == "intent":
            print(f"\n🎯 [意图] {chunk.get('intent')} (置信度: {chunk.get('confidence')})")

        elif event_type == "chunk":
            content = chunk.get("content", "")
            full_content += content
            print(content, end="", flush=True)

        elif event_type == "plan":
            plan_data = chunk.get("plan")
            print("\n\n" + "=" * 50)
            print("📋 [训练计划]")
            print("=" * 50)
            print(f"  标题: {plan_data.get('title')}")
            print(f"  副标题: {plan_data.get('subtitle')}")
            print(f"  时长: {plan_data.get('total_duration')} 分钟")
            print(f"  场景: {plan_data.get('scene')}")
            print(f"  RPE: {plan_data.get('rpe')}")
            print(f"  AI备注: {plan_data.get('ai_note')}")
            print(f"  模块数量: {len(plan_data.get('modules', []))}")

            for i, module in enumerate(plan_data.get("modules", [])):
                print(f"\n  模块 {i+1}: {module.get('name')} ({module.get('type')})")
                for j, exercise in enumerate(module.get("exercises", [])):
                    print(f"    {j+1}. {exercise.get('name')}")
                    print(f"       时长: {exercise.get('duration')}秒 x {exercise.get('sets')}组")
                    print(f"       休息: {exercise.get('rest_seconds')}秒")
                    if exercise.get('description'):
                        print(f"       说明: {exercise.get('description')[:50]}...")

        elif event_type == "done":
            print("\n\n" + "=" * 50)
            print("✅ [完成]")
            print(f"   会话ID: {chunk.get('session_id')}")
            print(f"   包含计划: {chunk.get('has_plan')}")
            print("=" * 50)

        elif event_type == "error":
            print(f"\n❌ [错误] {chunk.get('message')}")

        else:
            print(f"\n[未知事件] {event_type}: {chunk}")

    return full_content, plan_data


def interactive_mode():
    """交互式测试模式"""
    # 使用全局测试数据
    global TEST_USER_PROFILE, TEST_HISTORY
    while True:
        try:
            user_input = input("User:")

            try:
                asyncio.run(run_agent_test(user_input))
            except Exception as e:
                import traceback
                traceback.print_exc()

        except KeyboardInterrupt:
            print("\n\n退出程序")
        except Exception as e:
            import traceback
            print(f"\n错误: {e}")
            traceback.print_exc()


def main():
    # 测试单个消息
    test_messages = [
        "你好",
        "请帮我生成今天的训练计划",
        "我今天想做一些减脂训练",
        "给我一个15分钟的居家训练",
    ]

    # 可以选择运行单个测试或交互模式
    if len(sys.argv) > 1:
        # 命令行参数作为测试消息
        message = " ".join(sys.argv[1:])
        asyncio.run(run_agent_test(message))
    else:
        # 默认进入交互模式
        interactive_mode()


if __name__ == "__main__":
    """
    定制一份训练腹肌计划，并解释每个动作训练的目标肌群
    定制2个训练计划，一个是训练腹肌，一个是训练肩膀
    我今天小腿酸疼，有什么方式可以缓解小腿的酸痛吗
    推荐几个广西的旅游城市
    """
    main()
