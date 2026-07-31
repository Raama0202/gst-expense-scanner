from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import Principal, company_admin_principal
from app.db.session import get_db
from app.models import ApprovalStatus, Invoice

router = APIRouter()


@router.get("/dashboard")
async def dashboard(
    principal: Principal = Depends(company_admin_principal),
    db: AsyncSession = Depends(get_db),
):
    today = datetime.now(timezone.utc).date()
    rows = (
        await db.execute(
            select(Invoice.approval_status, func.count(Invoice.id))
            .where(Invoice.company_id == principal.company_id)
            .group_by(Invoice.approval_status)
        )
    ).all()
    counts = {status.value: count for status, count in rows}
    today_uploads = await db.scalar(
        select(func.count(Invoice.id)).where(
            Invoice.company_id == principal.company_id,
            func.date(Invoice.uploaded_at) == today,
        )
    )
    return {
        "pendingCount": counts.get(ApprovalStatus.pending.value, 0),
        "todayUploads": today_uploads or 0,
        "approvedCount": counts.get(ApprovalStatus.approved.value, 0),
        "rejectedCount": counts.get(ApprovalStatus.rejected.value, 0),
        "returnedCount": counts.get(ApprovalStatus.returned.value, 0),
    }
