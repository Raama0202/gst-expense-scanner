# GST Expense Scanner API

Production-oriented FastAPI backend for the multi-tenant GST Expense Scanner SaaS.

## Run with Docker

From the repository root:

```bash
docker compose up --build
```

API: `http://localhost:8000/v1`  
OpenAPI: `http://localhost:8000/docs`  
Health: `http://localhost:8000/health`

The container runs migrations and the idempotent seed before starting Uvicorn.

## Local development

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
pip install -r requirements.txt
alembic upgrade head
python -m app.seed
uvicorn app.main:app --reload
```

Required production environment variables:

- `DATABASE_URL` — PostgreSQL async URL
- `JWT_SECRET` — long random secret (never use the provided development default)
- `JWT_ACCESS_MINUTES` — default `60`
- `JWT_REFRESH_DAYS` — default `30`
- `STORAGE_PATH` — persistent upload directory
- `OTP_DEV_FIXED` — development-only fixed OTP
- `CORS_ORIGINS` — comma-separated origins
- `ENV` — set to `production` outside development
- `GEMINI_API_KEY` — free key from https://aistudio.google.com/apikey for AI invoice extraction
- `GEMINI_MODEL` — default `gemini-2.5-flash`

## AI invoice extraction

`POST /v1/invoices/extract` accepts a JPEG/PNG/WebP image and returns structured
GST fields (vendor, GSTIN, invoice number/date, taxable, CGST/SGST/IGST, discount,
net amount). The client uses this when online and falls back to on-device OCR when
the key is missing, the device is offline, or the provider errors.

Without `GEMINI_API_KEY`, `GET /v1/invoices/extract/status` reports
`{"available": false}` and clients stay on the local regex parser.
## Seed credentials

- Super admin: `admin@gstexpenses.app` / `ChangeMeNow!123`
- Demo company admin: `acme@demo.com` / `DemoAdmin!123`
- Demo employee: `9999999999` / OTP `123456` in development
- Demo activation code: `ACME-DEMO-2026`

Change all seeded passwords and `JWT_SECRET` before exposing the service.

## Tests

Tests use SQLite and do not require PostgreSQL:

```bash
pytest -q
```

## Tenant and upload behavior

Company-scoped queries always include the authenticated JWT's `company_id`; a conflicting
`X-Company-Id` header is rejected. Employee access also scopes by `employee_id`.
Uploads are stored beneath a company-specific directory and served at `/uploads`.
For production, place the API behind TLS and optionally replace local uploads with
object storage or a private authenticated media proxy.
