"""add workout_progress table

Revision ID: 4a1fd58090ed
Revises: 29631c9808a0
Create Date: 2026-02-13 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import mysql

# revision identifiers, used by Alembic.
revision: str = '4a1fd58090ed'
down_revision: Union[str, None] = '29631c9808a0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """创建训练进度表"""

    # 创建 workout_progress 表
    op.create_table(
        'workout_progress',
        sa.Column('id', mysql.CHAR(length=36), nullable=False),
        sa.Column('user_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('date_key', mysql.VARCHAR(length=10), nullable=False),
        sa.Column('plan_id', mysql.CHAR(length=36), nullable=False),
        sa.Column('status', mysql.VARCHAR(length=20), nullable=False, default='not_started'),
        sa.Column('current_module_index', mysql.INTEGER(), default=0, nullable=False),
        sa.Column('current_exercise_index', mysql.INTEGER(), default=0, nullable=False),
        sa.Column('total_exercises', mysql.INTEGER(), nullable=False),
        sa.Column('completed_exercise_ids', mysql.JSON(), nullable=False),
        sa.Column('start_time', mysql.DATETIME(), nullable=False),
        sa.Column('last_update_time', mysql.DATETIME(), nullable=False),
        sa.Column('actual_duration', mysql.INTEGER(), default=0, nullable=False),
        sa.Column('created_at', mysql.DATETIME(), nullable=False),
        sa.Column('updated_at', mysql.DATETIME(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        mysql_collate='utf8mb4_0900_ai_ci',
        mysql_default_charset='utf8mb4',
        mysql_engine='InnoDB'
    )
    op.create_index('ix_workout_progress_user_id', 'workout_progress', ['user_id'])
    op.create_index('ix_workout_progress_date_key', 'workout_progress', ['date_key'])
    op.create_index('ix_workout_progress_user_date', 'workout_progress', ['user_id', 'date_key'], unique=True)


def downgrade() -> None:
    """删除表"""
    op.drop_index('ix_workout_progress_user_date', table_name='workout_progress')
    op.drop_index('ix_workout_progress_date_key', table_name='workout_progress')
    op.drop_index('ix_workout_progress_user_id', table_name='workout_progress')
    op.drop_table('workout_progress')
