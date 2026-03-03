"""用户管理 API 端点"""
import os
import uuid
from fastapi import APIRouter, Depends, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pathlib import Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.user import UserResponse, UserUpdate
from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User

router = APIRouter(prefix="/users", tags=["用户管理"])

# 头像上传目录
AVATAR_DIR = Path("uploads/avatars")
AVATAR_DIR.mkdir(parents=True, exist_ok=True)


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
):
    """
    获取当前用户信息
    """
    return current_user


@router.put("/me", response_model=UserResponse)
async def update_me(
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    更新当前用户信息
    """
    if data.nickname is not None:
        current_user.nickname = data.nickname
    if data.avatar_url is not None:
        current_user.avatar_url = data.avatar_url

    # 提交数据库事务
    await db.commit()
    await db.refresh(current_user)

    return current_user


@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    上传用户头像
    """
    # 根据文件扩展名判断类型
    file_ext = os.path.splitext(file.filename)[1].lower() if file.filename else ""
    allowed_exts = [".jpg", ".jpeg", ".png", ".gif", ".webp"]

    # 验证文件扩展名
    if file_ext not in allowed_exts:
        raise HTTPException(status_code=400, detail="不支持的图片格式")

    # 验证文件大小 (最大 5MB)
    contents = await file.read()
    if len(contents) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="图片大小不能超过5MB")

    # 生成唯一文件名
    avatar_filename = f"{current_user.id}_{uuid.uuid4().hex}{file_ext}"
    avatar_path = AVATAR_DIR / avatar_filename

    # 保存文件
    with open(avatar_path, "wb") as f:
        f.write(contents)

    # 构建可访问的URL
    avatar_url = f"/api/v1/users/avatars/{avatar_filename}"

    # 更新用户头像URL
    current_user.avatar_url = avatar_url

    # 提交数据库事务
    await db.commit()
    await db.refresh(current_user)

    return JSONResponse({
        "avatar_url": avatar_url,
        "message": "头像上传成功"
    })


@router.get("/avatars/{filename}")
async def get_avatar(filename: str):
    """
    获取用户头像
    """
    avatar_path = AVATAR_DIR / filename
    if not avatar_path.exists():
        raise HTTPException(status_code=404, detail="头像不存在")

    from fastapi.responses import FileResponse
    return FileResponse(avatar_path)
