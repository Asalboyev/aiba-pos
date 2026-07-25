import pkgutil

from app.core.config import settings

# Models that are not Tortoise model modules.
SKIP_MODULES = {"__init__", "base", "enums"}


def get_model_modules(package: str) -> list[str]:
    base_path = package.replace(".", "/")
    modules: list[str] = []
    for _, mod, is_pkg in pkgutil.iter_modules([base_path]):
        if not is_pkg and mod not in SKIP_MODULES:
            modules.append(f"{package}.{mod}")
    return modules


MODEL_MODULES = get_model_modules("app.models") + ["aerich.models"]

TORTOISE_ORM = {
    "connections": {
        "default": {
            "engine": "tortoise.backends.asyncpg",
            "credentials": {
                "database": settings.POSTGRES_DB,
                "host": settings.POSTGRES_HOST,
                "password": settings.POSTGRES_PASSWORD,
                "port": settings.POSTGRES_PORT,
                "user": settings.POSTGRES_USER,
                "command_timeout": 30,
            },
            "pool_recycle": 3600,
            "maxsize": settings.POSTGRES_POOL_SIZE,
            "minsize": 1,
            "max_queries": 50000,
            "max_inactive_connection_lifetime": 3600,
        }
    },
    "apps": {"models": {"models": MODEL_MODULES, "default_connection": "default"}},
    "use_tz": True,
    "timezone": settings.TIMEZONE,
}
