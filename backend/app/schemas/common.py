from datetime import date, datetime
from decimal import Decimal
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class ORMModel(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)


class OTPRequest(BaseModel):
    mobile: str = Field(pattern=r"^\+?[0-9]{10,15}$")


class OTPVerify(OTPRequest):
    otp: str = Field(pattern=r"^[0-9]{6}$")


class RefreshRequest(BaseModel):
    refresh_token: str = Field(alias="refreshToken")


class AdminLogin(BaseModel):
    email: EmailStr
    password: str


class EmployeeProfile(ORMModel):
    id: UUID
    name: str
    mobile: str
    employee_code: str = Field(alias="employeeCode")
    company_id: UUID = Field(alias="companyId")
    company_name: str = Field(alias="companyName")
    branch_id: UUID | None = Field(alias="branchId")
    branch_name: str | None = Field(alias="branchName")


class TokenResponse(BaseModel):
    access_token: str = Field(alias="accessToken")
    refresh_token: str = Field(alias="refreshToken")
    expires_in: int = Field(alias="expiresIn")
    employee: EmployeeProfile | None = None


class DuplicateCheck(BaseModel):
    invoice_number: str = Field(alias="invoiceNumber")
    gstin: str | None = None
    invoice_date: date | None = Field(default=None, alias="invoiceDate")
    net_amount: Decimal | None = Field(default=None, alias="netAmount")


class InvoicePayload(BaseModel):
    branch_id: UUID | None = Field(default=None, alias="branchId")
    category_id: UUID | None = Field(default=None, alias="categoryId")
    device_id: str | None = Field(default=None, alias="deviceId")
    latitude: Decimal | None = None
    longitude: Decimal | None = None
    ocr_confidence: Decimal | None = Field(default=None, alias="ocrConfidence")
    ocr_data: dict[str, Any] = Field(default_factory=dict, alias="ocrData")
    edited_data: dict[str, Any] = Field(default_factory=dict, alias="editedData")
    duplicate_override: bool = Field(default=False, alias="duplicateOverride")


class NotificationRead(BaseModel):
    ids: list[UUID]


class DeviceRegister(BaseModel):
    device_id: str = Field(alias="deviceId")
    platform: Literal["android", "ios"]
    app_version: str = Field(alias="appVersion")
    fcm_token: str | None = Field(default=None, alias="fcmToken")


class EmployeeCreate(BaseModel):
    name: str
    mobile: str
    employee_code: str = Field(alias="employeeCode")
    branch_id: UUID | None = Field(default=None, alias="branchId")
    is_active: bool = Field(default=True, alias="isActive")


class EmployeeUpdate(BaseModel):
    name: str | None = None
    mobile: str | None = None
    employee_code: str | None = Field(default=None, alias="employeeCode")
    branch_id: UUID | None = Field(default=None, alias="branchId")
    is_active: bool | None = Field(default=None, alias="isActive")


class NamedResource(BaseModel):
    name: str
    code: str | None = None
    parent_id: UUID | None = Field(default=None, alias="parentId")
    sort_order: int = Field(default=0, alias="sortOrder")
    is_active: bool = Field(default=True, alias="isActive")


class CompanySettings(BaseModel):
    name: str | None = None
    industry: str | None = None
    logo_url: str | None = Field(default=None, alias="logoUrl")
    primary_color_hex: str | None = Field(default=None, alias="primaryColorHex")
    requires_gps: bool | None = Field(default=None, alias="requiresGps")
    duplicate_check_enabled: bool | None = Field(default=None, alias="duplicateCheckEnabled")
    min_ocr_confidence_warn: Decimal | None = Field(default=None, alias="minOcrConfidenceWarn")
    features: dict[str, Any] | None = None


class Announcement(BaseModel):
    title: str
    body: str


class InvoiceDecision(BaseModel):
    remarks: str | None = None


class PlanInput(BaseModel):
    code: str
    name: str
    monthly_price_inr: Decimal = Field(alias="monthlyPriceInr")
    max_employees: int | None = Field(alias="maxEmployees")
    features: dict[str, Any] = Field(default_factory=dict)


class CompanyCreate(BaseModel):
    name: str
    industry: str | None = None
    admin_email: EmailStr = Field(alias="adminEmail")
    admin_password: str = Field(min_length=8, alias="adminPassword")
    plan_code: str = Field(alias="planCode")
    seats: int = Field(gt=0)
    subscription_days: int = Field(default=30, gt=0, alias="subscriptionDays")


class ActivationRequest(BaseModel):
    activation_code: str = Field(alias="activationCode")


class ExtendSubscription(BaseModel):
    days: int = Field(gt=0)


class InvoiceFilter(BaseModel):
    status: str | None = None
    employee_id: UUID | None = None
    branch_id: UUID | None = None
    date_from: datetime | None = None
    date_to: datetime | None = None
