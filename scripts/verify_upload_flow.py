"""End-to-end check that a client-shaped upload reaches the admin invoice list.

Usage: python scripts/verify_upload_flow.py [base_url]
"""

import json
import sys
import uuid

import httpx

BASE = (sys.argv[1] if len(sys.argv) > 1 else "https://gst-expense-scanner.onrender.com").rstrip("/")
JPEG = bytes.fromhex(
    "ffd8ffe000104a46494600010100000100010000ffdb004300ffffffffffffffffffffffff"
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc200110800"
    "01000101011100ffc40014000100000000000000000000000000000009ffda0008010100"
    "00000001bfffd9"
)


def main() -> int:
    with httpx.Client(timeout=120.0) as client:
        client.post(f"{BASE}/v1/auth/otp/request", json={"mobile": "9999999999"})
        tokens = client.post(
            f"{BASE}/v1/auth/otp/verify",
            json={"mobile": "9999999999", "otp": "123456"},
        ).json()
        employee_headers = {"Authorization": f"Bearer {tokens['accessToken']}"}

        key = str(uuid.uuid4())
        payload = {
            "deviceId": "verify-script",
            "ocrConfidence": 0.9,
            "ocrData": {"vendorName": "Verify Traders", "invoiceNumber": key[:8]},
            "editedData": {
                "vendorName": "Verify Traders",
                "invoiceNumber": key[:8],
                "gstin": "29ABCDE1234F1Z5",
                "taxableValue": 1000,
                "cgst": 90,
                "sgst": 90,
                "netAmount": 1180,
            },
            "duplicateOverride": True,
        }
        upload = client.post(
            f"{BASE}/v1/invoices/upload",
            headers=employee_headers,
            data={"idempotencyKey": key, "payload": json.dumps(payload)},
            files={
                "original": ("original.jpg", JPEG, "image/jpeg"),
                "compressed": ("compressed.jpg", JPEG, "image/jpeg"),
                "thumbnail": ("thumbnail.jpg", JPEG, "image/jpeg"),
            },
        )
        print(f"upload  -> {upload.status_code} {upload.text[:300]}")
        if upload.status_code >= 400:
            return 1

        admin = client.post(
            f"{BASE}/v1/admin/auth/login",
            json={"email": "acme@demo.com", "password": "DemoAdmin!123"},
        ).json()
        listing = client.get(
            f"{BASE}/v1/admin/invoices",
            headers={"Authorization": f"Bearer {admin['accessToken']}"},
        ).json()
        items = listing.get("items", [])
        print(f"admin sees {len(items)} invoice(s)")
        for item in items[:5]:
            print(
                f"  {item.get('vendorName')} | {item.get('netAmount')} | "
                f"{item.get('approvalStatus')} | {item.get('imageUrl')}"
            )
        return 0 if items else 1


if __name__ == "__main__":
    raise SystemExit(main())
