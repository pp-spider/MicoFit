"""add applied_plan_id to chat_generated_plans

Revision ID: 20260303_1636
Revises: 20260303_1200
Create Date: 2026-03-03 16:36:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '20260303_1636'
down_revision: Union[str, None] = '20260303_1200'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """添加 applied_plan_id 列到 chat_generated_plans 表"""
    op.add_column(
        'chat_generated_plans',
        sa.Column('applied_plan_id', mysql.CHAR(36), nullable=True)
    )
    # 添加外键约束
    op.create_foreign_key(
        'fk_chat_generated_plans_applied_plan',
        'chat_generated_plans',
        'workout_plans',
        ['applied_plan_id'],
        ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    """删除 applied_plan_id 列"""
    # 删除外键约束
    op.drop_constraint('fk_chat_generated_plans_applied_plan', 'chat_generated_plans', type_='foreignkey')
    # 删除列
    op.drop_column('chat_generated_plans', 'applied_plan_id')
