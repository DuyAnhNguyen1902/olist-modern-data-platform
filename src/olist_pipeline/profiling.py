from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pandas as pd


def _serializable(value: Any) -> Any:
    if pd.isna(value):
        return None
    if hasattr(value, "item"):
        return value.item()
    return value


def profile_csv(path: Path) -> dict[str, Any]:
    frame = pd.read_csv(path, low_memory=False)
    columns: dict[str, Any] = {}

    for column in frame.columns:
        series = frame[column]
        samples = [_serializable(value) for value in series.dropna().head(3).tolist()]
        columns[column] = {
            "inferred_type": str(series.dtype),
            "null_count": int(series.isna().sum()),
            "null_percent": round(float(series.isna().mean() * 100), 4),
            "distinct_count": int(series.nunique(dropna=True)),
            "sample_values": samples,
        }

    return {
        "file": path.name,
        "size_bytes": path.stat().st_size,
        "row_count": len(frame),
        "column_count": len(frame.columns),
        "duplicate_rows": int(frame.duplicated().sum()),
        "columns": columns,
    }


def profile_directory(data_dir: Path, output_path: Path) -> dict[str, Any]:
    csv_files = sorted(data_dir.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"Không tìm thấy file CSV trong {data_dir}")

    report = {
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "data_directory": str(data_dir),
        "datasets": [profile_csv(path) for path in csv_files],
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report
