from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Company, CompanyStatus, Employee, Subscription, SubscriptionStatus


async def require_active_subscription(db: AsyncSession, company_id: UUID) -> Subscription:
    company = await db.get(Company, company_id)
    if not company or company.status != CompanyStatus.active:
        raise HTTPException(403, "Company is not active")
    subscription = await db.scalar(
        select(Subscription)
        .where(
            Subscription.company_id == company_id,
            Subscription.status == SubscriptionStatus.active,
        )
        .order_by(Subscription.ends_at.desc())
    )
    if not subscription or subscription.ends_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
        raise HTTPException(403, "Subscription expired")
    return subscription


async def enforce_seat_limit(db: AsyncSession, company_id: UUID) -> None:
    subscription = await require_active_subscription(db, company_id)
    count = await db.scalar(
        select(func.count(Employee.id)).where(
            Employee.company_id == company_id, Employee.is_active.is_(True)
        )
    )
    if count >= subscription.seats:
        raise HTTPException(409, "Subscription seat limit reached")
