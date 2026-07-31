from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "GST Expense Scanner API"
    env: str = "dev"
    database_url: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/gst_expenses"
    jwt_secret: str = "change-this-in-production-32-bytes-minimum"
    jwt_access_minutes: int = 60
    jwt_refresh_days: int = 30
    storage_path: Path = Path("./uploads")
    otp_dev_fixed: str | None = "123456"
    cors_origins: str = "http://localhost:3000,http://localhost:8000,http://localhost:8080,http://127.0.0.1:8080,http://localhost:5000"
    # Free Gemini API key from https://aistudio.google.com/apikey — required for
    # AI invoice extraction. Leave empty to force clients onto on-device OCR.
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.5-flash"
    gsp_base_url: str = ""
    gsp_client_id: str = ""
    gsp_client_secret: str = ""
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False, extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]

    @property
    def async_database_url(self) -> str:
        url = self.database_url
        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
        # Neon / libpq use sslmode=; asyncpg expects ssl=
        url = url.replace("sslmode=require", "ssl=require")
        return url


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
