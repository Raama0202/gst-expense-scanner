from hashlib import sha256
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.security import create_token, decode_token, verify_password
from app.db.session import get_db
from app.models import Company, Employee, Role, User
from app.schemas.common import AdminLogin, OTPRequest, OTPVerify, RefreshRequest
from app.services.otp import create_challenge, verify_challenge
from app.services.subscription import require_active_subscription

router = APIRouter()
admin_router = APIRouter()


def employee_json(employee: Employee, company: Company) -> dict:
    return {
        "id": employee.id,
        "name": employee.name,
        "mobile": employee.mobile,
        "employeeCode": employee.employee_code,
        "companyId": employee.company_id,
        "companyName": company.name,
        "branchId": employee.branch_id,
        "branchName": employee.branch.name if employee.branch else None,
    }


async def issue_tokens(db: AsyncSession, user: User, employee_id=None) -> tuple[str, str, int]:
    access, expires = create_token(user.id, user.role.value, user.company_id, employee_id)
    refresh, _ = create_token(user.id, user.role.value, user.company_id, employee_id, "refresh")
    user.refresh_token_hash = sha256(refresh.encode()).hexdigest()
    await db.commit()
    return access, refresh, expires


@router.post("/otp/request")
async def request_otp(body: OTPRequest, db: AsyncSession = Depends(get_db)):
    employees = (
        await db.scalars(
            select(Employee).where(Employee.mobile == body.mobile, Employee.is_active.is_(True))
        )
    ).all()
    if not employees:
        raise HTTPException(404, "No active employee is registered for this mobile")
    if len(employees) > 1:
        raise HTTPException(409, "Mobile belongs to multiple companies; contact administrator")
    await require_active_subscription(db, employees[0].company_id)
    await create_challenge(db, body.mobile)
    return {"ok": True}


@router.post("/otp/verify")
async def verify_otp(body: OTPVerify, db: AsyncSession = Depends(get_db)):
    if not await verify_challenge(db, body.mobile, body.otp):
        raise HTTPException(401, "Invalid or expired OTP")
    employee = await db.scalar(
        select(Employee)
        .options(selectinload(Employee.branch), selectinload(Employee.user))
        .where(Employee.mobile == body.mobile, Employee.is_active.is_(True))
    )
    if not employee or not employee.user.is_active:
        raise HTTPException(401, "Employee disabled")
    company = await db.get(Company, employee.company_id)
    await require_active_subscription(db, employee.company_id)
    access, refresh, expires = await issue_tokens(db, employee.user, employee.id)
    return {
        "accessToken": access,
        "refreshToken": refresh,
        "expiresIn": expires,
        "employee": employee_json(employee, company),
    }


@router.post("/token/refresh")
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        claims = decode_token(body.refresh_token, "refresh")
        user = await db.get(User, UUID(claims["sub"]))
    except Exception:
        raise HTTPException(401, "Invalid or expired refresh token")
    if not user or not user.is_active or user.refresh_token_hash != sha256(body.refresh_token.encode()).hexdigest():
        raise HTTPException(401, "Refresh token revoked")
    employee_id = claims.get("employee_id")
    access, refresh, expires = await issue_tokens(db, user, employee_id)
    return {"accessToken": access, "refreshToken": refresh, "expiresIn": expires}


@router.post("/logout", status_code=204)
async def logout(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    try:
        claims = decode_token(body.refresh_token, "refresh")
        user = await db.get(User, UUID(claims["sub"]))
        if user and user.refresh_token_hash == sha256(body.refresh_token.encode()).hexdigest():
            user.refresh_token_hash = None
            await db.commit()
    except Exception:
        pass
    return Response(status_code=204)


@admin_router.post("/login")
async def admin_login(body: AdminLogin, db: AsyncSession = Depends(get_db)):
    user = await db.scalar(select(User).where(User.email == body.email.lower()))
    if (
        not user
        or user.role not in (Role.company_admin, Role.super_admin)
        or not user.password_hash
        or not verify_password(body.password, user.password_hash)
        or not user.is_active
    ):
        raise HTTPException(401, "Invalid email or password")
    if user.company_id:
        await require_active_subscription(db, user.company_id)
    access, refresh, expires = await issue_tokens(db, user)
    return {
        "accessToken": access,
        "refreshToken": refresh,
        "expiresIn": expires,
        "user": {"id": user.id, "email": user.email, "role": user.role, "companyId": user.company_id},
    }
