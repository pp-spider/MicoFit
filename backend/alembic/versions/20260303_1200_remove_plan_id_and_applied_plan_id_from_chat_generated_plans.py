"""remove plan_id and applied_plan_id from chat_generated_plans

Revision ID: 20260303_1200
Revises: 20260303_1000
Create Date: 2026-03-03 12:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '20260303_1200'
down_revision: Union[str, None] = '20260303_1000'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """删除 plan_id 和 applied_plan_id 列"""
    # 删除外键约束
    op.drop_constraint('chat_generated_plans_ibfk_4', 'chat_generated_plans', type_='foreignkey')

    # 删除 applied_plan_id 列
    op.drop_column('chat_generated_plans', 'applied_plan_id')

    # 删除 plan_id 列
    op.drop_column('chat_generated_plans', 'plan_id')


def downgrade() -> None:
    """恢复 plan_id 和 applied_plan_id 列"""
    # 添加 plan_id 列
    op.add_column(
        'chat_generated_plans',
        sa.Column('plan_id', sa.String(50), nullable=False, server_default='')
    )

    # 添加 applied_plan_id 列
    op.add_column(
        'chat_generated_plans',
        sa.Column('applied_plan_id', mysql.CHAR(36), nullable=True)
    )

    # 添加外键约束
    op.create_foreign_key(
        'chat_generated_plans_ibfk_4',
        'chat_generated_plans',
        'workout_plans',
        ['applied_plan_id'],
        ['id'],
        ondelete='SET NULL'
    )
