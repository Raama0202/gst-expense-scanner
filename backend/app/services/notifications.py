from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Employee, Notification


async def notify_employee(
    db: AsyncSession,
    company_id: UUID,
    employee_id: UUID,
    notification_type: str,
    title: str,
    body: str,
    invoice_id: UUID | None = None,
) -> Notification:
    item = Notification(
        company_id=company_id,
        employee_id=employee_id,
        type=notification_type,
        title=title,
        body=body,
        invoice_id=invoice_id,
    )
    db.add(item)
    return item


async def announce(db: AsyncSession, company_id: UUID, title: str, body: str) -> int:
    employee_ids = (
        await db.scalars(
            select(Employee.id).where(Employee.company_id == company_id, Employee.is_active.is_(True))
        )
    ).all()
    db.add_all(
        [
            Notification(
                company_id=company_id,
                employee_id=employee_id,
                type="companyAnnouncement",
                title=title,
                body=body,
            )
            for employee_id in employee_ids
        ]
    )
    await db.commit()
    return len(employee_ids)
