"""remove workout plan unique constraint

Revision ID: 20260302_2230
Revises: 4a1fd58090ed
Create Date: 2026-03-02 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '20260302_2230'
down_revision: Union[str, None] = 'fbb5b95162fc'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """移除 workout_plans 表的唯一约束，支持同一天多个计划"""
    # 删除旧的唯一索引
    op.drop_index('ix_workout_plans_user_date', table_name='workout_plans')
    # 创建新的非唯一索引
    op.create_index('ix_workout_plans_user_date', 'workout_plans', ['user_id', 'plan_date'], unique=False)


def downgrade() -> None:
    """恢复唯一约束"""
    op.drop_index('ix_workout_plans_user_date', table_name='workout_plans')
    op.create_index('ix_workout_plans_user_date', 'workout_plans', ['user_id', 'plan_date'], unique=True)
