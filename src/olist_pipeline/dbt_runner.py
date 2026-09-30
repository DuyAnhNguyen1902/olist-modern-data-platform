from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from .settings import PROJECT_ROOT, Settings


def _dbt_directory(variable: str, default: Path) -> Path:
    return Path(os.getenv(variable, str(default))).resolve()


def run_dbt(settings: Settings, *arguments: str) -> dict:
    """Run dbt with credentials supplied through environment variables."""
    executable = shutil.which("dbt")
    if not executable:
        raise RuntimeError(
            "dbt executable not found. Install the project again with: "
            'python -m pip install -e ".[dev]"'
        )

    project_dir = _dbt_directory("DBT_PROJECT_DIR", PROJECT_ROOT / "dbt")
    profiles_dir = _dbt_directory("DBT_PROFILES_DIR", project_dir)
    environment = os.environ.copy()
    environment.update(
        {
            "DBT_POSTGRES_HOST": settings.postgres_host,
            "DBT_POSTGRES_PORT": str(settings.postgres_port),
            "DBT_POSTGRES_DB": settings.postgres_db,
            "DBT_POSTGRES_USER": settings.postgres_user,
            "DBT_POSTGRES_PASSWORD": settings.postgres_password,
        }
    )

    command = [
        executable,
        *arguments,
        "--project-dir",
        str(project_dir),
        "--profiles-dir",
        str(profiles_dir),
        "--no-use-colors",
    ]
    process = subprocess.run(
        command,
        env=environment,
        text=True,
        capture_output=True,
        check=False,
    )
    output = "\n".join(part for part in (process.stdout, process.stderr) if part).strip()
    if process.returncode:
        raise RuntimeError(f"dbt failed with exit code {process.returncode}:\n{output}")
    return {
        "command": " ".join(arguments),
        "status": "SUCCESS",
        "output_tail": "\n".join(output.splitlines()[-20:]),
    }


def dbt_debug(settings: Settings) -> dict:
    return run_dbt(settings, "debug")


def dbt_build(settings: Settings, full_refresh: bool = False) -> dict:
    arguments = ["build"]
    if full_refresh:
        arguments.append("--full-refresh")
    return run_dbt(settings, *arguments)
