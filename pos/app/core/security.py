import hashlib
import hmac
import os
from datetime import datetime, timedelta, timezone

from jose import jwt

from app.core.config import settings

# ---- JWT (terminal / staff tokens) ----


def create_access_token(data: dict, expires_minutes: int | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=expires_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    to_encode["exp"] = expire
    return jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.ALGORITHM])


# ---- PIN hashing (stdlib pbkdf2, no native deps) ----


def hash_pin(pin: str, salt: str | None = None) -> str:
    salt_bytes = bytes.fromhex(salt) if salt else os.urandom(16)
    dk = hashlib.pbkdf2_hmac("sha256", pin.encode("utf-8"), salt_bytes, 100_000)
    return f"{salt_bytes.hex()}${dk.hex()}"


def verify_pin(pin: str, stored: str) -> bool:
    try:
        salt_hex, _ = stored.split("$", 1)
    except ValueError:
        return False
    return hmac.compare_digest(hash_pin(pin, salt_hex), stored)
