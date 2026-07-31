from pathlib import Path
from uuid import UUID, uuid4

import aiofiles
from fastapi import UploadFile

from app.core.config import settings

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_FILE_SIZE = 15 * 1024 * 1024


async def save_upload(file: UploadFile, company_id: UUID, kind: str) -> str:
    if file.content_type not in ALLOWED_TYPES:
        raise ValueError(f"Unsupported image type: {file.content_type}")
    extension = Path(file.filename or "image.jpg").suffix.lower() or ".jpg"
    relative = Path(str(company_id)) / f"{kind}-{uuid4().hex}{extension}"
    target = settings.storage_path / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    size = 0
    async with aiofiles.open(target, "wb") as output:
        while chunk := await file.read(1024 * 1024):
            size += len(chunk)
            if size > MAX_FILE_SIZE:
                await output.close()
                target.unlink(missing_ok=True)
                raise ValueError("Image exceeds 15 MB")
            await output.write(chunk)
    return relative.as_posix()


def public_url(path: str | None) -> str | None:
    return f"/uploads/{path}" if path else None
