from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.encoders import jsonable_encoder
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.routes import admin, auth, company, devices, employees, invoices, itc, notifications, super
from app.core.config import settings


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings.storage_path.mkdir(parents=True, exist_ok=True)
    yield


app = FastAPI(title=settings.app_name, version="1.0.0", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.mount("/uploads", StaticFiles(directory=settings.storage_path, check_dir=False), name="uploads")

app.include_router(auth.router, prefix="/v1/auth", tags=["auth"])
app.include_router(auth.admin_router, prefix="/v1/admin/auth", tags=["admin-auth"])
app.include_router(employees.router, prefix="/v1/employees", tags=["employees"])
app.include_router(company.router, prefix="/v1/company", tags=["company"])
app.include_router(invoices.router, prefix="/v1/invoices", tags=["invoices"])
app.include_router(notifications.router, prefix="/v1/notifications", tags=["notifications"])
app.include_router(devices.router, prefix="/v1/devices", tags=["devices"])
app.include_router(admin.router, prefix="/v1/admin", tags=["admin"])
app.include_router(employees.admin_router, prefix="/v1/admin/employees", tags=["admin-employees"])
app.include_router(company.admin_router, prefix="/v1/admin/company", tags=["admin-company"])
app.include_router(invoices.admin_router, prefix="/v1/admin/invoices", tags=["admin-invoices"])
app.include_router(itc.router, prefix="/v1/admin/itc", tags=["admin-itc"])
app.include_router(notifications.admin_router, prefix="/v1/admin/notifications", tags=["admin-notifications"])
app.include_router(super.public_router, prefix="/v1/super", tags=["activation"])
app.include_router(super.router, prefix="/v1/super", tags=["super-admin"])


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.exception_handler(HTTPException)
async def http_error(_: Request, exc: HTTPException):
    detail = exc.detail if isinstance(exc.detail, str) else "Request failed"
    return JSONResponse(status_code=exc.status_code, content={"message": detail})


@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=400,
        content=jsonable_encoder(
            {"message": "Invalid request", "code": "VALIDATION_ERROR", "errors": exc.errors()}
        ),
    )
