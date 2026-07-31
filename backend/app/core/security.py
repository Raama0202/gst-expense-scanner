from datetime import datetime, timedelta, timezone
from hashlib import sha256
from uuid import UUID

import jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def hash_otp(code: str) -> str:
    return sha256(f"{settings.jwt_secret}:{code}".encode()).hexdigest()


def create_token(
    subject: UUID | str,
    role: str,
    company_id: UUID | str | None,
    employee_id: UUID | str | None = None,
    token_type: str = "access",
) -> tuple[str, int]:
    now = datetime.now(timezone.utc)
    lifetime = (
        timedelta(minutes=settings.jwt_access_minutes)
        if token_type == "access"
        else timedelta(days=settings.jwt_refresh_days)
    )
    expires = now + lifetime
    payload = {
        "sub": str(subject),
        "role": role,
        "company_id": str(company_id) if company_id else None,
        "employee_id": str(employee_id) if employee_id else None,
        "type": token_type,
        "iat": now,
        "exp": expires,
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256"), int(lifetime.total_seconds())


def decode_token(token: str, expected_type: str = "access") -> dict:
    payload = jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    if payload.get("type") != expected_type:
        raise jwt.InvalidTokenError("Invalid token type")
    return payload
