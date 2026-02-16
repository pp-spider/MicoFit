"""微动 MicoFit Backend - FastAPI 应用入口"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
import logging

from app.core.config import settings
from app.api.v1 import auth, profiles, users, ai, workouts, feedback, sync, chat_sessions
from app.db.base import Base

logger = logging.getLogger(__name__)


async def create_database_if_not_exists():
    """如果数据库不存在则创建"""
    # 构建 MySQL 连接 URL（不指定数据库）
    mysql_url = (
        f"mysql+aiomysql://{settings.DB_USER}:{settings.DB_PASSWORD}"
        f"@{settings.DB_HOST}:{settings.DB_PORT}"
    )

    engine = create_async_engine(mysql_url, echo=False)

    try:
        async with engine.connect() as conn:
            # 检查数据库是否存在
            result = await conn.execute(
                text(
                    "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA "
                    "WHERE SCHEMA_NAME = :db_name"
                ),
                {"db_name": settings.DB_NAME}
            )
            exists = result.first() is not None

            if not exists:
                logger.info(f"数据库 {settings.DB_NAME} 不存在，正在创建...")
                await conn.execute(
                    text(
                        f"CREATE DATABASE {settings.DB_NAME} "
                        "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
                    )
                )
                logger.info(f"数据库 {settings.DB_NAME} 创建成功")
            else:
                logger.info(f"数据库 {settings.DB_NAME} 已存在")
    finally:
        await engine.dispose()


async def create_tables():
    """创建所有表"""
    from app.db.session import engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("数据库表创建/更新完成")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时执行
    logger.info("正在初始化数据库...")
    await create_database_if_not_exists()
    await create_tables()
    logger.info("数据库初始化完成")

    yield

    # 关闭时执行（如果需要）
    logger.info("应用关闭")


# 创建 FastAPI 应用
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    debug=settings.DEBUG,
    description="微动健身应用后端 API",
    lifespan=lifespan,
)

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(auth.router, prefix="/api/v1")
app.include_router(profiles.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(ai.router, prefix="/api/v1")
app.include_router(workouts.router, prefix="/api/v1")
app.include_router(feedback.router, prefix="/api/v1")
app.include_router(sync.router, prefix="/api/v1")
app.include_router(chat_sessions.router, prefix="/api/v1")


@app.get("/")
async def root():
    """根路径"""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
    }


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
    )
