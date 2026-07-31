from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.deps import Principal, company_admin_principal, current_employee
from app.db.session import get_db
from app.models import Branch, Company, Employee, Role, User
from app.schemas.common import EmployeeCreate, EmployeeUpdate
from app.services.subscription import enforce_seat_limit

router = APIRouter()
admin_router = APIRouter()


async def validate_branch(db: AsyncSession, company_id: UUID, branch_id: UUID | None) -> None:
    if branch_id and not await db.scalar(
        select(Branch.id).where(Branch.id == branch_id, Branch.company_id == company_id)
    ):
        raise HTTPException(400, "Branch does not belong to company")


def serialize(employee: Employee, company_name: str | None = None) -> dict:
    return {
        "id": employee.id,
        "name": employee.name,
        "mobile": employee.mobile,
        "employeeCode": employee.employee_code,
        "companyId": employee.company_id,
        "companyName": company_name,
        "branchId": employee.branch_id,
        "branchName": employee.branch.name if employee.branch else None,
        "isActive": employee.is_active,
    }


@router.get("/me")
async def me(employee: Employee = Depends(current_employee), db: AsyncSession = Depends(get_db)):
    employee = await db.scalar(
        select(Employee).options(selectinload(Employee.branch)).where(Employee.id == employee.id)
    )
    company = await db.get(Company, employee.company_id)
    return serialize(employee, company.name)


@admin_router.get("")
async def list_employees(
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    items = (
        await db.scalars(
            select(Employee)
            .options(selectinload(Employee.branch))
            .where(Employee.company_id == principal.company_id)
            .order_by(Employee.name)
        )
    ).all()
    return {"items": [serialize(item) for item in items]}


@admin_router.post("", status_code=201)
async def create_employee(
    body: EmployeeCreate,
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    await enforce_seat_limit(db, principal.company_id)
    await validate_branch(db, principal.company_id, body.branch_id)
    conflict = await db.scalar(
        select(Employee).where(
            Employee.company_id == principal.company_id,
            (Employee.mobile == body.mobile) | (Employee.employee_code == body.employee_code),
        )
    )
    if conflict:
        raise HTTPException(409, "Mobile or employee code already exists")
    user = User(company_id=principal.company_id, role=Role.employee, is_active=body.is_active)
    db.add(user)
    await db.flush()
    employee = Employee(
        company_id=principal.company_id,
        user_id=user.id,
        name=body.name,
        mobile=body.mobile,
        employee_code=body.employee_code,
        branch_id=body.branch_id,
        is_active=body.is_active,
    )
    db.add(employee)
    await db.commit()
    await db.refresh(employee)
    return serialize(employee)


@admin_router.patch("/{employee_id}")
async def update_employee(
    employee_id: UUID,
    body: EmployeeUpdate,
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    employee = await db.scalar(
        select(Employee).where(
            Employee.id == employee_id, Employee.company_id == principal.company_id
        )
    )
    if not employee:
        raise HTTPException(404, "Employee not found")
    if "branch_id" in body.model_fields_set:
        await validate_branch(db, principal.company_id, body.branch_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(employee, field, value)
    user = await db.get(User, employee.user_id)
    user.is_active = employee.is_active
    await db.commit()
    return serialize(employee)


@admin_router.delete("/{employee_id}", status_code=204)
async def disable_employee(
    employee_id: UUID,
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    employee = await db.scalar(
        select(Employee).where(
            Employee.id == employee_id, Employee.company_id == principal.company_id
        )
    )
    if not employee:
        raise HTTPException(404, "Employee not found")
    employee.is_active = False
    (await db.get(User, employee.user_id)).is_active = False
    await db.commit()
