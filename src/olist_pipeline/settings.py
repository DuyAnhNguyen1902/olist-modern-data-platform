from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _load_local_env(path: Path) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


_load_local_env(PROJECT_ROOT / ".env")


@dataclass(frozen=True)
class Settings:
    postgres_host: str = os.getenv("POSTGRES_HOST", "localhost")
    postgres_port: int = int(os.getenv("POSTGRES_PORT", "5432"))
    postgres_db: str = os.getenv("POSTGRES_DB", "ecommerce")
    postgres_user: str = os.getenv("POSTGRES_USER", "ecommerce")
    postgres_password: str = os.getenv("POSTGRES_PASSWORD", "ecommerce_dev")
    data_dir: Path = PROJECT_ROOT / os.getenv("DATA_DIR", "data/raw/olist")
    quality_config: Path = PROJECT_ROOT / os.getenv("QUALITY_CONFIG", "config/data_contracts.json")
    reports_dir: Path = PROJECT_ROOT / os.getenv("REPORTS_DIR", "reports")

    @property
    def postgres_dsn(self) -> str:
        return (
            f"host={self.postgres_host} port={self.postgres_port} "
            f"dbname={self.postgres_db} user={self.postgres_user} "
            f"password={self.postgres_password}"
        )


settings = Settings()
