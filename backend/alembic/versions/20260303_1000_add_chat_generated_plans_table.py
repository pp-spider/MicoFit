"""add chat_generated_plans table

Revision ID: 20260303_1000
Revises: 20260302_2230
Create Date: 2026-03-03 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '20260303_1000'
down_revision: Union[str, None] = '20260302_2230'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """创建 chat_generated_plans 表"""
    op.create_table(
        'chat_generated_plans',
        sa.Column('id', mysql.CHAR(36), nullable=False),
        sa.Column('user_id', mysql.CHAR(36), nullable=False),
        sa.Column('session_id', mysql.CHAR(36), nullable=False),
        sa.Column('message_id', mysql.CHAR(36), nullable=True),
        sa.Column('plan_id', sa.String(50), nullable=False),
        sa.Column('title', sa.String(100), nullable=False),
        sa.Column('subtitle', sa.String(200), nullable=True),
        sa.Column('total_duration', sa.Integer(), nullable=False),
        sa.Column('scene', sa.String(20), nullable=False),
        sa.Column('rpe', sa.Integer(), nullable=False),
        sa.Column('ai_note', sa.Text(), nullable=True),
        sa.Column('modules', mysql.JSON(), nullable=False),
        sa.Column('response_status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('applied_plan_id', mysql.CHAR(36), nullable=True),
        sa.Column('generated_at', sa.DateTime(), nullable=False),
        sa.Column('responded_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['session_id'], ['chat_sessions.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['message_id'], ['chat_messages.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['applied_plan_id'], ['workout_plans.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
        mysql_engine='InnoDB'
    )
    op.create_index('ix_chat_generated_plans_user_id', 'chat_generated_plans', ['user_id'])
    op.create_index('ix_chat_generated_plans_session_id', 'chat_generated_plans', ['session_id'])
    op.create_index('ix_chat_generated_plans_response_status', 'chat_generated_plans', ['response_status'])


def downgrade() -> None:
    """删除 chat_generated_plans 表"""
    op.drop_index('ix_chat_generated_plans_response_status', table_name='chat_generated_plans')
    op.drop_index('ix_chat_generated_plans_session_id', table_name='chat_generated_plans')
    op.drop_index('ix_chat_generated_plans_user_id', table_name='chat_generated_plans')
    op.drop_table('chat_generated_plans')
