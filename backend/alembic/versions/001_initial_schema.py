"""initial schema

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-10-21 22:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = '001_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

def upgrade() -> None:
    # 1. users table
    op.create_table(
        'users',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('username', sa.String(length=100), nullable=False),
        sa.Column('hashed_password', sa.String(length=255), nullable=False),
        sa.Column('role', sa.String(length=50), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('manager_id', sa.String(length=36), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['manager_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_username'), 'users', ['username'], unique=True)
    op.create_index(op.f('ix_users_role'), 'users', ['role'], unique=False)
    op.create_index(op.f('ix_users_is_active'), 'users', ['is_active'], unique=False)
    op.create_index(op.f('ix_users_manager_id'), 'users', ['manager_id'], unique=False)

    # 2. refresh_tokens table
    op.create_table(
        'refresh_tokens',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('token_hash', sa.String(length=255), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('is_revoked', sa.Boolean(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_refresh_tokens_user_id'), 'refresh_tokens', ['user_id'], unique=False)
    op.create_index(op.f('ix_refresh_tokens_token_hash'), 'refresh_tokens', ['token_hash'], unique=True)
    op.create_index(op.f('ix_refresh_tokens_is_revoked'), 'refresh_tokens', ['is_revoked'], unique=False)

    # 3. field_visits table
    op.create_table(
        'field_visits',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('employee_id', sa.String(length=36), nullable=False),
        sa.Column('client_name', sa.String(length=255), nullable=False),
        sa.Column('client_phone', sa.String(length=50), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('gps_accuracy', sa.Float(), nullable=False),
        sa.Column('is_mock_location', sa.Boolean(), nullable=False),
        sa.Column('device_capture_time', sa.DateTime(timezone=True), nullable=False),
        sa.Column('server_receipt_time', sa.DateTime(timezone=True), nullable=False),
        sa.Column('photo_asset_id', sa.String(length=255), nullable=False),
        sa.Column('photo_url', sa.String(length=512), nullable=True),
        sa.Column('photo_metadata', sa.Text(), nullable=True),
        sa.Column('photo_uploaded_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('is_flagged_for_review', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('review_signals', sa.Text(), nullable=True),
        sa.Column('clock_drift_seconds', sa.Float(), nullable=True),
        sa.Column('status', sa.String(length=50), nullable=False),
        sa.Column('review_reason', sa.Text(), nullable=True),
        sa.Column('reviewed_by_id', sa.String(length=36), nullable=True),
        sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['employee_id'], ['users.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['reviewed_by_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_field_visits_employee_id'), 'field_visits', ['employee_id'], unique=False)
    op.create_index(op.f('ix_field_visits_status'), 'field_visits', ['status'], unique=False)
    op.create_index(op.f('ix_field_visits_photo_asset_id'), 'field_visits', ['photo_asset_id'], unique=True)
    op.create_index(op.f('ix_field_visits_is_flagged_for_review'), 'field_visits', ['is_flagged_for_review'], unique=False)
    op.create_index(op.f('ix_field_visits_reviewed_by_id'), 'field_visits', ['reviewed_by_id'], unique=False)

    # 4. employee_targets table
    op.create_table(
        'employee_targets',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('employee_id', sa.String(length=36), nullable=False),
        sa.Column('target_count', sa.Integer(), nullable=False),
        sa.Column('period_type', sa.String(length=20), nullable=False),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=False),
        sa.Column('created_by_id', sa.String(length=36), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['created_by_id'], ['users.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['employee_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_employee_targets_employee_id'), 'employee_targets', ['employee_id'], unique=False)
    op.create_index(op.f('ix_employee_targets_start_date'), 'employee_targets', ['start_date'], unique=False)
    op.create_index(op.f('ix_employee_targets_end_date'), 'employee_targets', ['end_date'], unique=False)

    # 5. audit_events table
    op.create_table(
        'audit_events',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('actor_id', sa.String(length=36), nullable=True),
        sa.Column('actor_role', sa.String(length=50), nullable=True),
        sa.Column('action', sa.String(length=100), nullable=False),
        sa.Column('affected_record_id', sa.String(length=100), nullable=True),
        sa.Column('affected_record_type', sa.String(length=50), nullable=True),
        sa.Column('server_timestamp', sa.DateTime(timezone=True), nullable=False),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['actor_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_audit_events_actor_id'), 'audit_events', ['actor_id'], unique=False)
    op.create_index(op.f('ix_audit_events_action'), 'audit_events', ['action'], unique=False)
    op.create_index(op.f('ix_audit_events_affected_record_id'), 'audit_events', ['affected_record_id'], unique=False)
    op.create_index(op.f('ix_audit_events_server_timestamp'), 'audit_events', ['server_timestamp'], unique=False)

def downgrade() -> None:
    op.drop_table('audit_events')
    op.drop_table('employee_targets')
    op.drop_table('field_visits')
    op.drop_table('refresh_tokens')
    op.drop_table('users')
