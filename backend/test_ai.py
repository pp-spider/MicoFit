"""测试 AI 配置是否正确"""
import asyncio
import logging

# 设置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def test_chat_agent():
    """测试聊天 Agent"""
    try:
        from app.agents.chat_agent import ChatAgent
        from app.core.config import settings

        logger.info("=" * 50)
        logger.info("测试 ChatAgent")
        logger.info("=" * 50)
        logger.info(f"OPENAI_API_KEY: {'已配置' if settings.OPENAI_API_KEY else '未配置'}")
        logger.info(f"OPENAI_MODEL: {settings.OPENAI_MODEL}")
        logger.info(f"OPENAI_BASE_URL: {settings.OPENAI_BASE_URL}")
        logger.info(f"OPENAI_TEMPERATURE: {settings.OPENAI_TEMPERATURE}")
        logger.info(f"OPENAI_MAX_TOKENS: {settings.OPENAI_MAX_TOKENS}")

        agent = ChatAgent()
        logger.info("✅ ChatAgent 初始化成功")

        # 测试简单聊天
        logger.info("\n测试流式聊天...")
        chunk_count = 0
        async for chunk in agent.chat_stream(
            user_id="test_user",
            session_id="test_session",
            user_message="你好",
            user_profile=None,
            history=[]
        ):
            logger.info(f"收到: {chunk}")
            chunk_count += 1
            if chunk_count > 5:  # 只收5个块就停止
                break

        logger.info("✅ 流式聊天测试通过")

    except Exception as e:
        logger.error(f"❌ ChatAgent 测试失败: {e}")
        import traceback
        logger.error(traceback.format_exc())

async def test_workout_agent():
    """测试训练计划 Agent"""
    try:
        from app.agents.workout_agent import WorkoutAgent

        logger.info("\n" + "=" * 50)
        logger.info("测试 WorkoutAgent")
        logger.info("=" * 50)

        agent = WorkoutAgent()
        logger.info("✅ WorkoutAgent 初始化成功")

    except Exception as e:
        logger.error(f"❌ WorkoutAgent 测试失败: {e}")
        import traceback
        logger.error(traceback.format_exc())

if __name__ == "__main__":
    asyncio.run(test_chat_agent())
    asyncio.run(test_workout_agent())
