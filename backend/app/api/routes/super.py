from datetime import datetime, timedelta, timezone
from secrets import token_urlsafe
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, super_principal
from app.core.security import hash_password
from app.db.session import get_db
from app.models import (
    Company,
    CompanyStatus,
    Role,
    Subscription,
    SubscriptionPlan,
    SubscriptionStatus,
    User,
)
from app.schemas.common import ActivationRequest, CompanyCreate, ExtendSubscription, PlanInput

router = APIRouter()
public_router = APIRouter()


def plan_json(plan: SubscriptionPlan) -> dict:
    return {
        "id": plan.id,
        "code": plan.code,
        "name": plan.name,
        "monthlyPriceInr": plan.monthly_price_inr,
        "maxEmployees": plan.max_employees,
        "features": plan.features_json,
    }


@router.get("/plans")
async def plans(_: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    return {"items": [plan_json(x) for x in (await db.scalars(select(SubscriptionPlan).order_by(SubscriptionPlan.monthly_price_inr))).all()]}


@router.post("/plans", status_code=201)
async def create_plan(body: PlanInput, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    if await db.scalar(select(SubscriptionPlan).where(SubscriptionPlan.code == body.code)):
        raise HTTPException(409, "Plan code exists")
    plan = SubscriptionPlan(code=body.code, name=body.name, monthly_price_inr=body.monthly_price_inr, max_employees=body.max_employees, features_json=body.features)
    db.add(plan); await db.commit(); await db.refresh(plan)
    return plan_json(plan)


@router.put("/plans/{plan_id}")
async def update_plan(plan_id: UUID, body: PlanInput, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    plan = await db.get(SubscriptionPlan, plan_id)
    if not plan: raise HTTPException(404, "Plan not found")
    plan.code, plan.name, plan.monthly_price_inr = body.code, body.name, body.monthly_price_inr
    plan.max_employees, plan.features_json = body.max_employees, body.features
    await db.commit(); return plan_json(plan)


@router.delete("/plans/{plan_id}", status_code=204)
async def delete_plan(plan_id: UUID, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    plan = await db.get(SubscriptionPlan, plan_id)
    if not plan: raise HTTPException(404, "Plan not found")
    if await db.scalar(select(Subscription).where(Subscription.plan_code == plan.code).limit(1)):
        raise HTTPException(409, "Plan is assigned to subscriptions")
    await db.delete(plan); await db.commit()


@router.post("/companies", status_code=201)
async def create_company(body: CompanyCreate, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    plan = await db.scalar(select(SubscriptionPlan).where(SubscriptionPlan.code == body.plan_code))
    if not plan: raise HTTPException(400, "Unknown plan")
    if plan.max_employees is not None and body.seats > plan.max_employees:
        raise HTTPException(400, "Seats exceed plan maximum")
    if await db.scalar(select(User).where(User.email == body.admin_email.lower())):
        raise HTTPException(409, "Admin email already exists")
    company = Company(name=body.name, industry=body.industry, activation_code=token_urlsafe(9), status=CompanyStatus.pending)
    db.add(company); await db.flush()
    db.add(User(company_id=company.id, email=body.admin_email.lower(), password_hash=hash_password(body.admin_password), role=Role.company_admin))
    now = datetime.now(timezone.utc)
    db.add(Subscription(company_id=company.id, plan_code=plan.code, seats=body.seats, starts_at=now, ends_at=now + timedelta(days=body.subscription_days), status=SubscriptionStatus.active))
    await db.commit()
    return {"id": company.id, "name": company.name, "status": company.status, "activationCode": company.activation_code}


@public_router.post("/companies/activate")
async def activate(body: ActivationRequest, db: AsyncSession = Depends(get_db)):
    company = await db.scalar(select(Company).where(Company.activation_code == body.activation_code))
    if not company: raise HTTPException(404, "Invalid activation code")
    if company.status == CompanyStatus.suspended: raise HTTPException(403, "Company is suspended")
    company.status = CompanyStatus.active
    await db.commit()
    return {"id": company.id, "status": company.status}


@router.get("/companies")
async def companies(_: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    items = (await db.scalars(select(Company).order_by(Company.created_at.desc()))).all()
    return {"items": [{"id": x.id, "name": x.name, "industry": x.industry, "status": x.status, "activationCode": x.activation_code, "createdAt": x.created_at} for x in items]}


async def set_status(company_id: UUID, status: CompanyStatus, db: AsyncSession):
    company = await db.get(Company, company_id)
    if not company: raise HTTPException(404, "Company not found")
    company.status = status; await db.commit()
    return {"id": company.id, "status": company.status}


@router.post("/companies/{company_id}/suspend")
async def suspend(company_id: UUID, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    return await set_status(company_id, CompanyStatus.suspended, db)


@router.post("/companies/{company_id}/reactivate")
async def reactivate(company_id: UUID, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    return await set_status(company_id, CompanyStatus.active, db)


@router.post("/companies/{company_id}/subscription/extend")
async def extend(company_id: UUID, body: ExtendSubscription, _: Principal = Depends(super_principal), db: AsyncSession = Depends(get_db)):
    subscription = await db.scalar(select(Subscription).where(Subscription.company_id == company_id).order_by(Subscription.ends_at.desc()))
    if not subscription: raise HTTPException(404, "Subscription not found")
    now = datetime.now(timezone.utc)
    base = max(subscription.ends_at.replace(tzinfo=timezone.utc), now)
    subscription.ends_at = base + timedelta(days=body.days)
    subscription.status = SubscriptionStatus.active
    await db.commit()
    return {"companyId": company_id, "endsAt": subscription.ends_at, "status": subscription.status}
