"""add workout and chat tables

Revision ID: 29631c9808a0
Revises:
Create Date: 2026-02-07 12:21:33.923035

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '29631c9808a0'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """创建训练计划、训练记录、聊天会话和聊天消息表"""

    # 创建 workout_plans 表
    op.create_table(
        'workout_plans',
        sa.Column('id', mysql.CHAR(length=36), nullable=False),
        sa.Column('user_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('plan_date', sa.Date(), nullable=False),
        sa.Column('title', mysql.VARCHAR(length=100), nullable=False),
        sa.Column('subtitle', mysql.VARCHAR(length=200), nullable=True),
        sa.Column('total_duration', mysql.INTEGER(), nullable=False),
        sa.Column('scene', mysql.VARCHAR(length=20), nullable=False),
        sa.Column('rpe', mysql.INTEGER(), nullable=False),
        sa.Column('ai_note', mysql.TEXT(), nullable=True),
        sa.Column('modules', mysql.JSON(), nullable=False),
        sa.Column('is_completed', mysql.TINYINT(display_width=1), default=0, nullable=False),
        sa.Column('is_applied', mysql.TINYINT(display_width=1), default=0, nullable=False),
        sa.Column('feedback_id', mysql.CHAR(length=36), nullable=True),
        sa.Column('created_at', mysql.DATETIME(), nullable=False),
        sa.Column('updated_at', mysql.DATETIME(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        mysql_collate='utf8mb4_0900_ai_ci',
        mysql_default_charset='utf8mb4',
        mysql_engine='InnoDB'
    )
    op.create_index('ix_workout_plans_user_id', 'workout_plans', ['user_id'])
    op.create_index('ix_workout_plans_plan_date', 'workout_plans', ['plan_date'])
    op.create_index('ix_workout_plans_user_date', 'workout_plans', ['user_id', 'plan_date'], unique=True)

    # 创建 workout_records 表
    op.create_table(
        'workout_records',
        sa.Column('id', mysql.CHAR(length=36), nullable=False),
        sa.Column('user_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('plan_id', mysql.CHAR(length=36), nullable=True),
        sa.Column('record_date', sa.Date(), nullable=False),
        sa.Column('duration', mysql.INTEGER(), nullable=False),
        sa.Column('completion', mysql.VARCHAR(length=20), nullable=False),
        sa.Column('feeling', mysql.VARCHAR(length=20), nullable=False),
        sa.Column('tomorrow', mysql.VARCHAR(length=20), nullable=False),
        sa.Column('pain_locations', mysql.JSON(), nullable=True),
        sa.Column('completed', mysql.TINYINT(display_width=1), default=1, nullable=False),
        sa.Column('created_at', mysql.DATETIME(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['plan_id'], ['workout_plans.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        mysql_collate='utf8mb4_0900_ai_ci',
        mysql_default_charset='utf8mb4',
        mysql_engine='InnoDB'
    )
    op.create_index('ix_workout_records_user_id', 'workout_records', ['user_id'])
    op.create_index('ix_workout_records_record_date', 'workout_records', ['record_date'])
    op.create_index('ix_workout_records_user_date', 'workout_records', ['user_id', 'record_date'], unique=True)

    # 创建 chat_sessions 表
    op.create_table(
        'chat_sessions',
        sa.Column('id', mysql.CHAR(length=36), nullable=False),
        sa.Column('user_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('title', mysql.VARCHAR(length=100), nullable=True),
        sa.Column('context_summary', mysql.TEXT(), nullable=True),
        sa.Column('message_count', mysql.INTEGER(), default=0, nullable=False),
        sa.Column('created_at', mysql.DATETIME(), nullable=False),
        sa.Column('updated_at', mysql.DATETIME(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        mysql_collate='utf8mb4_0900_ai_ci',
        mysql_default_charset='utf8mb4',
        mysql_engine='InnoDB'
    )
    op.create_index('ix_chat_sessions_user_id', 'chat_sessions', ['user_id'])
    op.create_index('ix_chat_sessions_updated_at', 'chat_sessions', ['updated_at'])

    # 创建 chat_messages 表
    op.create_table(
        'chat_messages',
        sa.Column('id', mysql.CHAR(length=36), nullable=False),
        sa.Column('session_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('role', mysql.VARCHAR(length=20), nullable=False),
        sa.Column('content', mysql.TEXT(), nullable=False),
        sa.Column('structured_data', mysql.JSON(), nullable=True),
        sa.Column('data_type', mysql.VARCHAR(length=50), nullable=True),
        sa.Column('tool_calls', mysql.JSON(), nullable=True),
        sa.Column('tool_call_id', mysql.VARCHAR(length=100), nullable=True),
        sa.Column('created_at', mysql.DATETIME(), nullable=False),
        sa.ForeignKeyConstraint(['session_id'], ['chat_sessions.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        mysql_collate='utf8mb4_0900_ai_ci',
        mysql_default_charset='utf8mb4',
        mysql_engine='InnoDB'
    )
    op.create_index('ix_chat_messages_session_id', 'chat_messages', ['session_id'])
    op.create_index('ix_chat_messages_created_at', 'chat_messages', ['created_at'])


def downgrade() -> None:
    """删除表（反向顺序）"""
    op.drop_table('chat_messages')
    op.drop_table('chat_sessions')
    op.drop_table('workout_records')
    op.drop_table('workout_plans')
