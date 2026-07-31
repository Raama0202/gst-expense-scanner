import logging
from hmac import compare_digest
from datetime import datetime, timedelta, timezone
from secrets import randbelow

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.security import hash_otp
from app.models import OTPChallenge

logger = logging.getLogger(__name__)


async def create_challenge(db: AsyncSession, mobile: str) -> None:
    recent = await db.scalar(
        select(func.count(OTPChallenge.id)).where(
            OTPChallenge.mobile == mobile,
            OTPChallenge.created_at >= datetime.now(timezone.utc) - timedelta(minutes=10),
        )
    )
    if recent >= 5:
        raise HTTPException(429, "Too many OTP requests; try again later")
    code = settings.otp_dev_fixed if settings.env == "dev" and settings.otp_dev_fixed else f"{randbelow(1_000_000):06d}"
    db.add(
        OTPChallenge(
            mobile=mobile,
            code_hash=hash_otp(code),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
        )
    )
    await db.commit()
    if settings.env == "dev":
        logger.warning("Development OTP for %s: %s", mobile, code)


async def verify_challenge(db: AsyncSession, mobile: str, code: str) -> bool:
    challenge = await db.scalar(
        select(OTPChallenge)
        .where(OTPChallenge.mobile == mobile, OTPChallenge.consumed_at.is_(None))
        .order_by(OTPChallenge.created_at.desc())
        .limit(1)
    )
    now = datetime.now(timezone.utc)
    if not challenge or challenge.expires_at.replace(tzinfo=timezone.utc) < now or challenge.attempts >= 5:
        return False
    challenge.attempts += 1
    if not compare_digest(challenge.code_hash, hash_otp(code)):
        await db.commit()
        return False
    challenge.consumed_at = now
    await db.commit()
    return True
