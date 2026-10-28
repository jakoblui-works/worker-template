from app.core.config import DatabaseSettings, RedisSettings, settings

DATABASE_PASSWORD = "database-password-not-for-logs"
REDIS_PASSWORD = "redis-password-not-for-logs"


def test_database_password_is_hidden_in_repr() -> None:
    database = DatabaseSettings.model_validate({"password": DATABASE_PASSWORD})

    assert DATABASE_PASSWORD not in repr(database)


def test_redis_password_is_hidden_in_repr() -> None:
    redis = RedisSettings.model_validate({"password": REDIS_PASSWORD})

    assert REDIS_PASSWORD not in repr(redis)


def test_passwords_are_hidden_in_settings_repr() -> None:
    shown = repr(
        settings.model_copy(
            update={
                "database": DatabaseSettings.model_validate({"password": DATABASE_PASSWORD}),
                "redis": RedisSettings.model_validate({"password": REDIS_PASSWORD}),
            }
        )
    )

    assert DATABASE_PASSWORD not in shown
    assert REDIS_PASSWORD not in shown
