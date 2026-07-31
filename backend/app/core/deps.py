from dataclasses import dataclass
from uuid import UUID

import jwt
from fastapi import Depends, Header, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.session import get_db
from app.models import Employee, Role, User
from app.services.subscription import require_active_subscription

bearer = HTTPBearer(auto_error=False)


@dataclass
class Principal:
    user: User
    company_id: UUID | None
    employee_id: UUID | None


async def current_principal(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    x_company_id: UUID | None = Header(default=None, alias="X-Company-Id"),
    db: AsyncSession = Depends(get_db),
) -> Principal:
    if not credentials:
        raise HTTPException(401, "Authentication required")
    try:
        claims = decode_token(credentials.credentials)
        user_id = UUID(claims["sub"])
        token_company = UUID(claims["company_id"]) if claims.get("company_id") else None
        employee_id = UUID(claims["employee_id"]) if claims.get("employee_id") else None
    except (jwt.InvalidTokenError, KeyError, ValueError):
        raise HTTPException(401, "Invalid or expired token")
    user = await db.scalar(select(User).where(User.id == user_id, User.is_active.is_(True)))
    if not user:
        raise HTTPException(401, "User disabled")
    if token_company and x_company_id and token_company != x_company_id:
        raise HTTPException(403, "Company header does not match token")
    if user.company_id != token_company:
        raise HTTPException(403, "Tenant mismatch")
    if token_company:
        await require_active_subscription(db, token_company)
    return Principal(user=user, company_id=token_company, employee_id=employee_id)


async def employee_principal(principal: Principal = Depends(current_principal)) -> Principal:
    if principal.user.role != Role.employee or not principal.employee_id or not principal.company_id:
        raise HTTPException(403, "Employee role required")
    return principal


async def admin_principal(principal: Principal = Depends(current_principal)) -> Principal:
    if principal.user.role not in (Role.company_admin, Role.super_admin):
        raise HTTPException(403, "Admin role required")
    return principal


async def company_admin_principal(principal: Principal = Depends(admin_principal)) -> Principal:
    if principal.user.role != Role.company_admin or not principal.company_id:
        raise HTTPException(403, "Company admin role required")
    return principal


async def super_principal(principal: Principal = Depends(current_principal)) -> Principal:
    if principal.user.role != Role.super_admin:
        raise HTTPException(403, "Super admin role required")
    return principal


async def current_employee(
    principal: Principal = Depends(employee_principal),
    db: AsyncSession = Depends(get_db),
) -> Employee:
    employee = await db.scalar(
        select(Employee).where(
            Employee.id == principal.employee_id,
            Employee.company_id == principal.company_id,
            Employee.is_active.is_(True),
        )
    )
    if not employee:
        raise HTTPException(403, "Employee disabled")
    return employee
