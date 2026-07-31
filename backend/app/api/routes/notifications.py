from fastapi import APIRouter, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, company_admin_principal, current_employee
from app.db.session import get_db
from app.models import Employee, Notification
from app.schemas.common import Announcement, NotificationRead
from app.services.notifications import announce

router = APIRouter()
admin_router = APIRouter()


def serialize(item: Notification) -> dict:
    return {
        "id": item.id,
        "type": item.type,
        "title": item.title,
        "body": item.body,
        "createdAt": item.created_at,
        "read": item.read,
        "invoiceServerId": item.invoice_id,
        "sentAt": item.sent_at,
    }


@router.get("")
async def list_notifications(
    employee: Employee = Depends(current_employee), db: AsyncSession = Depends(get_db)
):
    items = (
        await db.scalars(
            select(Notification)
            .where(
                Notification.company_id == employee.company_id,
                Notification.employee_id == employee.id,
            )
            .order_by(Notification.created_at.desc())
            .limit(200)
        )
    ).all()
    return {"items": [serialize(item) for item in items]}


@router.post("/read")
async def mark_read(
    body: NotificationRead,
    employee: Employee = Depends(current_employee),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        update(Notification)
        .where(
            Notification.company_id == employee.company_id,
            Notification.employee_id == employee.id,
            Notification.id.in_(body.ids),
        )
        .values(read=True)
    )
    await db.commit()
    return {"updated": result.rowcount}


@admin_router.post("/announcements", status_code=201)
async def create_announcement(
    body: Announcement,
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    count = await announce(db, principal.company_id, body.title, body.body)
    return {"created": count}


@admin_router.get("")
async def admin_notifications(
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    items = (
        await db.scalars(
            select(Notification)
            .where(Notification.company_id == principal.company_id)
            .order_by(Notification.created_at.desc())
            .limit(500)
        )
    ).all()
    return {"items": [serialize(item) for item in items]}
