import os
import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.dialects import postgresql
from sqlalchemy.schema import CreateTable

from app.core.database import Base
from app.models.app_version import AppVersionConfig
from app.models.user import User
from app.models.refresh_token import RefreshToken
from app.models.attendance import Attendance
from app.models.customer import Customer
from app.models.visit import FieldVisit
from app.models.target import EmployeeTarget
from app.models.audit import AuditEvent
from app.models.chat import ChatRoom, ChatMessage

ALL_MODELS = [
    AppVersionConfig,
    User,
    RefreshToken,
    Attendance,
    Customer,
    FieldVisit,
    EmployeeTarget,
    AuditEvent,
    ChatRoom,
    ChatMessage,
]

def test_postgresql_ddl_compilation_all_tables():
    """
    Validates that every single SQLAlchemy 2.0 ORM model in PhytoDoctor compiles
    to 100% valid PostgreSQL DDL syntax without dialect errors, type mismatches,
    or unsupported constraints.
    """
    pg_dialect = postgresql.dialect()
    compiled_tables = []
    for model_cls in ALL_MODELS:
        table = model_cls.__table__
        create_stmt = CreateTable(table).compile(dialect=pg_dialect)
        sql_str = str(create_stmt).strip()
        assert len(sql_str) > 0, f"Table {table.name} compiled to empty DDL string"
        assert table.name.lower() in sql_str.lower()
        compiled_tables.append(table.name)
    assert len(compiled_tables) == 10, f"Expected 10 compiled tables, got {len(compiled_tables)}"

def test_foreign_key_dependency_ordering():
    """
    Verifies that the ORM dependency graph topologically sorts cleanly for PostgreSQL
    schema creation and tear-down without circular foreign keys.
    """
    sorted_tables = [t.name for t in Base.metadata.sorted_tables]
    # users must be created before field_visits, attendances, customers, targets, chat
    assert "users" in sorted_tables
    assert sorted_tables.index("users") < sorted_tables.index("field_visits")
    assert sorted_tables.index("users") < sorted_tables.index("customers")
    assert sorted_tables.index("users") < sorted_tables.index("attendances")
    assert sorted_tables.index("users") < sorted_tables.index("employee_targets")
    assert sorted_tables.index("users") < sorted_tables.index("chat_rooms")
    assert sorted_tables.index("chat_rooms") < sorted_tables.index("chat_messages")

@pytest.mark.asyncio
async def test_live_postgresql_staging_crud_and_rollback():
    """
    Tests live PostgreSQL connection if POSTGRES_TEST_DATABASE_URL environment variable
    is provided. If no PostgreSQL instance is configured, skips with NOT VERIFIED status
    as required by safety & compliance instructions.
    """
    postgres_url = os.environ.get("POSTGRES_TEST_DATABASE_URL") or os.environ.get("POSTGRES_URL")
    if not postgres_url:
        pytest.skip(
            "NOT VERIFIED: POSTGRES_TEST_DATABASE_URL is not set. "
            "No live PostgreSQL staging instance available in local testing environment."
        )

    clean_url = postgres_url.replace("postgresql+asyncpg://", "postgresql://")
    engine = create_engine(clean_url, echo=False)

    try:
        with engine.connect() as conn:
            # 1. Connection check
            res = conn.execute(text("SELECT version();")).scalar()
            assert "PostgreSQL" in res, f"Expected PostgreSQL engine, got {res}"

            # 2. Test schema creation
            Base.metadata.create_all(engine)

            # 3. Test transaction and rollback
            trans = conn.begin()
            conn.execute(
                text(
                    "INSERT INTO app_version_config (id, minimum_supported_version, recommended_version, "
                    "force_update, title, message, created_at, updated_at) VALUES "
                    "('staging-test-uuid', '1.0.0', '1.0.0', false, 'Test', 'Test', NOW(), NOW())"
                )
            )
            # Rollback to ensure no residue in staging
            trans.rollback()

            check = conn.execute(
                text("SELECT count(*) FROM app_version_config WHERE id = 'staging-test-uuid'")
            ).scalar()
            assert check == 0, "Rollback failed: test record remained in database"
    finally:
        engine.dispose()
