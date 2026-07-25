import hmac
from dataclasses import dataclass
from typing import Optional

from fastapi import HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError

from app.core.config import settings
from app.core.security import decode_access_token

bearer_scheme = HTTPBearer(auto_error=False)
service_secret_scheme = APIKeyHeader(name="X-Service-Secret", auto_error=False)


@dataclass
class Principal:
    """Who is calling the POS service.

    Two kinds of callers:
      * service  — cloud-os (Nextcloud) acting on behalf of a manager. It has
        already done its own per-user / per-company access check, so it may
        pass an explicit ?restaurant_id=.
      * terminal — a POS device logged in via /auth/login. Scoped to exactly
        one restaurant + terminal + staff role; it can never read another
        restaurant's data.
    """

    is_service: bool = False
    staff_id: Optional[str] = None
    restaurant_id: Optional[str] = None
    terminal_id: Optional[str] = None
    shift_id: Optional[str] = None
    role: Optional[str] = None


def verify_service_secret(secret: Optional[str]) -> bool:
    if not secret:
        return False
    return hmac.compare_digest(secret, settings.SERVICE_SECRET_KEY)


async def get_principal(
    authorization: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme),
    service_secret: Optional[str] = Security(service_secret_scheme),
) -> Principal:
    if verify_service_secret(service_secret):
        return Principal(is_service=True, role="service")

    if not authorization:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authorization header missing")

    try:
        payload = decode_access_token(authorization.credentials)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    # Web adminka login issues an admin-role JWT — service-equivalent access.
    if payload.get("role") == "admin":
        return Principal(is_service=True, role="service")

    return Principal(
        staff_id=payload.get("sub"),
        restaurant_id=payload.get("restaurant_id"),
        terminal_id=payload.get("terminal_id"),
        shift_id=payload.get("shift_id"),
        role=payload.get("role"),
    )


async def require_service(
    authorization: Optional[HTTPAuthorizationCredentials] = Security(bearer_scheme),
    service_secret: Optional[str] = Security(service_secret_scheme),
) -> Principal:
    """Admin/internal endpoints — cloud-os (service secret) or the web
    adminka (admin-role JWT). Terminal staff tokens are NOT accepted."""
    if verify_service_secret(service_secret):
        return Principal(is_service=True, role="service")
    if authorization:
        try:
            payload = decode_access_token(authorization.credentials)
        except JWTError:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
        if payload.get("role") == "admin":
            return Principal(is_service=True, role="service")
    raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Service secret required")


def resolve_restaurant_id(principal: Principal, restaurant_id: Optional[str]) -> str:
    """Terminals are pinned to their own restaurant; services must name one."""
    if principal.is_service:
        if not restaurant_id:
            raise HTTPException(status_code=400, detail="restaurant_id is required for service calls")
        return restaurant_id
    if not principal.restaurant_id:
        raise HTTPException(status_code=403, detail="Token is not scoped to a restaurant")
    if restaurant_id and restaurant_id != principal.restaurant_id:
        raise HTTPException(status_code=403, detail="Cross-restaurant access denied")
    return principal.restaurant_id
