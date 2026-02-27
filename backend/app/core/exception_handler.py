"""全局异常处理中间件

提供统一的异常处理和错误响应格式化
"""
import logging
import traceback
from typing import Union
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
from pydantic import ValidationError

logger = logging.getLogger(__name__)


class APIException(Exception):
    """自定义 API 异常基类"""

    def __init__(
        self,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        error_code: str = "BAD_REQUEST",
        details: dict = None
    ):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)


class AuthenticationError(APIException):
    """认证错误"""

    def __init__(self, message: str = "认证失败"):
        super().__init__(
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHORIZED"
        )


class PermissionDeniedError(APIException):
    """权限不足错误"""

    def __init__(self, message: str = "权限不足"):
        super().__init__(
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="FORBIDDEN"
        )


class ResourceNotFoundError(APIException):
    """资源不存在错误"""

    def __init__(self, resource: str = "资源"):
        super().__init__(
            message=f"{resource}不存在",
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND"
        )


class RateLimitError(APIException):
    """请求频率限制错误"""

    def __init__(self, message: str = "请求过于频繁，请稍后再试"):
        super().__init__(
            message=message,
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            error_code="RATE_LIMIT_EXCEEDED"
        )


class AIServiceError(APIException):
    """AI 服务错误"""

    def __init__(self, message: str = "AI 服务暂时不可用"):
        super().__init__(
            message=message,
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            error_code="AI_SERVICE_UNAVAILABLE"
        )


def create_error_response(
    message: str,
    status_code: int,
    error_code: str,
    details: dict = None,
    request_id: str = None
) -> dict:
    """创建标准错误响应格式"""
    return {
        "success": False,
        "error": {
            "code": error_code,
            "message": message,
            "details": details or {},
            "request_id": request_id
        }
    }


async def api_exception_handler(request: Request, exc: APIException) -> JSONResponse:
    """处理自定义 API 异常"""
    logger.warning(
        f"APIException: {exc.error_code} - {exc.message} "
        f"Path: {request.url.path}"
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=create_error_response(
            message=exc.message,
            status_code=exc.status_code,
            error_code=exc.error_code,
            details=exc.details
        )
    )


async def validation_exception_handler(
    request: Request,
    exc: Union[RequestValidationError, ValidationError]
) -> JSONResponse:
    """处理请求参数验证错误"""
    errors = []
    if isinstance(exc, RequestValidationError):
        for error in exc.errors():
            errors.append({
                "field": ".".join(str(x) for x in error["loc"]),
                "message": error["msg"],
                "type": error["type"]
            })
    else:
        errors.append({
            "field": "unknown",
            "message": str(exc),
            "type": "validation_error"
        })

    logger.warning(
        f"ValidationError: Path: {request.url.path}, Errors: {errors}"
    )

    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=create_error_response(
            message="请求参数验证失败",
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            error_code="VALIDATION_ERROR",
            details={"errors": errors}
        )
    )


async def sqlalchemy_exception_handler(
    request: Request,
    exc: SQLAlchemyError
) -> JSONResponse:
    """处理数据库错误"""
    error_message = str(exc)

    # 根据错误类型返回不同的错误信息
    if isinstance(exc, IntegrityError):
        if "Duplicate entry" in error_message:
            message = "数据已存在，请勿重复提交"
            error_code = "DUPLICATE_ENTRY"
        elif "foreign key constraint" in error_message.lower():
            message = "关联数据不存在"
            error_code = "FOREIGN_KEY_VIOLATION"
        else:
            message = "数据完整性错误"
            error_code = "INTEGRITY_ERROR"
    else:
        message = "数据库操作失败"
        error_code = "DATABASE_ERROR"

    logger.error(
        f"DatabaseError: {error_code} - {error_message} "
        f"Path: {request.url.path}",
        exc_info=True
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=create_error_response(
            message=message,
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            error_code=error_code,
            details={"debug_info": error_message} if __debug__ else {}
        )
    )


async def general_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """处理通用异常"""
    error_traceback = traceback.format_exc()

    logger.error(
        f"UnhandledException: {type(exc).__name__} - {str(exc)} "
        f"Path: {request.url.path}\n"
        f"Traceback: {error_traceback}"
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=create_error_response(
            message="服务器内部错误",
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            error_code="INTERNAL_SERVER_ERROR",
            details={
                "exception_type": type(exc).__name__,
                "debug_info": str(exc) if __debug__ else None
            }
        )
    )


class ExceptionHandlerMiddleware:
    """异常处理中间件

    捕获和处理所有未处理的异常，提供统一的错误响应
    """

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        try:
            await self.app(scope, receive, send)
        except Exception as exc:
            # 创建请求对象以便处理异常
            if scope["type"] == "http":
                request = Request(scope, receive)

                # 根据异常类型选择处理器
                if isinstance(exc, APIException):
                    response = await api_exception_handler(request, exc)
                elif isinstance(exc, (RequestValidationError, ValidationError)):
                    response = await validation_exception_handler(request, exc)
                elif isinstance(exc, SQLAlchemyError):
                    response = await sqlalchemy_exception_handler(request, exc)
                else:
                    response = await general_exception_handler(request, exc)

                await response(scope, receive, send)
            else:
                # 非 HTTP 请求，重新抛出异常
                raise exc


def register_exception_handlers(app):
    """注册所有异常处理器到 FastAPI 应用"""

    # 注册自定义 API 异常处理器
    app.add_exception_handler(APIException, api_exception_handler)

    # 注册验证错误处理器
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(ValidationError, validation_exception_handler)

    # 注册数据库错误处理器
    app.add_exception_handler(SQLAlchemyError, sqlalchemy_exception_handler)

    # 注册通用异常处理器（作为后备）
    app.add_exception_handler(Exception, general_exception_handler)

    logger.info("全局异常处理器注册完成")
