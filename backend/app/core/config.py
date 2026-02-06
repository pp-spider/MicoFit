"""应用配置管理"""
from pydantic_settings import BaseSettings
from typing import List
from pathlib import Path
# from dotenv import load_dotenv

# load_dotenv()

class Settings(BaseSettings):
    """应用配置"""

    # 应用基本信息
    APP_NAME: str = "微动 MicoFit API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # 数据库配置
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_USER: str = "micofit"
    DB_PASSWORD: str = ""
    DB_NAME: str = "micofit_db"

    @property
    def DATABASE_URL(self) -> str:
        """构建数据库连接 URL"""
        return f"mysql+aiomysql://{self.DB_USER}:{self.DB_PASSWORD}@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"

    # JWT 配置
    SECRET_KEY: str = "your-secret-key-change-this-in-production-min-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # CORS 配置
    FRONTEND_URL: str = "http://localhost:3000"
    CORS_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
    ]

    class Config:
        env_file = "backend\.env"
        case_sensitive = True


# 全局配置实例
settings = Settings()