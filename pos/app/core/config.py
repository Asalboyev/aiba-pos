import os

from dotenv import load_dotenv

load_dotenv()


class Settings:
    def __init__(self):
        self.APP_NAME = os.getenv("APP_NAME", "AIBA POS")
        self.APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
        self.TIMEZONE = os.getenv("TIMEZONE", "Asia/Tashkent")
        self.ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

        # --- Auth ---
        self.JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-pos-jwt-secret-change-me")
        self.ALGORITHM = os.getenv("ALGORITHM", "HS256")
        # POS terminals stay logged in for a whole work day by default.
        self.ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", str(60 * 16)))
        # cloud-os (Nextcloud) → pos service calls authenticate with this shared secret.
        self.SERVICE_SECRET_KEY = (
            os.getenv("AIBA_SERVICE_SECRET") or os.getenv("SERVICE_SECRET_KEY") or "dev-service-secret"
        )
        # Web adminka (/admin) login — issues an admin-role JWT.
        self.ADMIN_USERNAME = os.getenv("POS_ADMIN_USER", "admin")
        self.ADMIN_PASSWORD = os.getenv("POS_ADMIN_PASSWORD", "aiba2026")

        # --- Database ---
        self.POSTGRES_DB = os.getenv("POSTGRES_DB", "aiba_pos")
        self.POSTGRES_HOST = os.getenv("POSTGRES_HOST", "pos-db")
        self.POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", "5432"))
        self.POSTGRES_USER = os.getenv("POSTGRES_USER", "aiba_pos")
        self.POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "aiba_pos_pass")
        self.POSTGRES_POOL_SIZE = int(os.getenv("POSTGRES_POOL_SIZE", "20"))

        # --- Redis / Celery ---
        self.REDIS_URL = os.getenv("REDIS_URL", "redis://pos-redis:6379/0")
        self.CELERY_BROKER_URL = os.getenv("CELERY_BROKER_URL", "redis://pos-redis:6379/1")
        self.CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "redis://pos-redis:6379/1")

        # --- Fiscal (virtual cash register / OFD) ---
        # mock = sandbox provider that returns a deterministic fiscal sign + QR
        # (works end-to-end with no credentials). Switch to "multikassa" /
        # "regos" / "epos" once a real provider contract is in place.
        self.FISCAL_PROVIDER = os.getenv("FISCAL_PROVIDER", "mock").lower()
        self.FISCAL_API_URL = os.getenv("FISCAL_API_URL", "")
        self.FISCAL_API_TOKEN = os.getenv("FISCAL_API_TOKEN", "")
        # Where a customer verifies the cheque QR (soliq.uz OFD check page).
        self.FISCAL_VERIFY_BASE = os.getenv("FISCAL_VERIFY_BASE", "https://ofd.soliq.uz/epi/check")
        self.FISCAL_MAX_RETRIES = int(os.getenv("FISCAL_MAX_RETRIES", "12"))

        # --- E-POS Communicator (Universal Communicator 3.23.6+) ---
        # Real cashier PC: http://localhost:8347/uzpos
        # Integration test: http://integration.epos.uz:8347/uzpos
        self.EPOS_API_URL = os.getenv("EPOS_API_URL", "http://integration.epos.uz:8347/uzpos")
        self.EPOS_TOKEN = os.getenv("EPOS_TOKEN", "")
        self.EPOS_PORT = os.getenv("EPOS_PORT", "3448")

        self.SENTRY_DSN = os.getenv("SENTRY_DSN", "")


settings = Settings()
