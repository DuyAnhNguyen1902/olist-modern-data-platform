from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pandas as pd


@dataclass
class CheckResult:
    test_name: str
    dataset: str
    dimension: str
    severity: str
    status: str
    failed_rows: int
    total_rows: int
    message: str


def _result(
    test_name: str,
    dataset: str,
    dimension: str,
    failed_rows: int,
    total_rows: int,
    message: str,
    severity: str = "ERROR",
) -> CheckResult:
    return CheckResult(
        test_name=test_name,
        dataset=dataset,
        dimension=dimension,
        severity=severity,
        status="PASS" if failed_rows == 0 else severity,
        failed_rows=int(failed_rows),
        total_rows=int(total_rows),
        message=message,
    )


def load_contract(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _read_dataset(data_dir: Path, spec: dict[str, Any]) -> pd.DataFrame:
    path = data_dir / spec["file"]
    if not path.exists():
        raise FileNotFoundError(path)
    return pd.read_csv(path, dtype=str, keep_default_na=True, low_memory=False)


def validate_dataset(
    dataset_name: str, spec: dict[str, Any], data_dir: Path
) -> tuple[pd.DataFrame | None, list[CheckResult]]:
    path = data_dir / spec["file"]
    if not path.exists():
        return None, [
            _result(
                "file_exists",
                dataset_name,
                "availability",
                1,
                1,
                f"Thiếu file {path.name}",
            )
        ]

    frame = _read_dataset(data_dir, spec)
    results = [
        _result(
            "file_not_empty",
            dataset_name,
            "availability",
            int(frame.empty),
            len(frame),
            f"File có {len(frame):,} dòng",
        )
    ]

    expected = set(spec.get("required_columns", []))
    missing = sorted(expected - set(frame.columns))
    results.append(
        _result(
            "required_columns",
            dataset_name,
            "schema",
            len(missing),
            len(expected),
            "Đủ cột bắt buộc" if not missing else f"Thiếu cột: {missing}",
        )
    )
    if missing:
        return frame, results

    for column in spec.get("not_null", []):
        failed = int((frame[column].isna() | frame[column].fillna("").str.strip().eq("")).sum())
        results.append(
            _result(
                f"{column}_not_null",
                dataset_name,
                "completeness",
                failed,
                len(frame),
                f"{failed:,} giá trị null/rỗng",
            )
        )

    for columns in spec.get("unique", []):
        failed = int(frame.duplicated(subset=columns, keep=False).sum())
        results.append(
            _result(
                f"{'_'.join(columns)}_unique",
                dataset_name,
                "uniqueness",
                failed,
                len(frame),
                f"{failed:,} dòng thuộc khóa bị trùng",
            )
        )

    for column, accepted in spec.get("accepted_values", {}).items():
        failed = int((~frame[column].isin(accepted) & frame[column].notna()).sum())
        results.append(
            _result(
                f"{column}_accepted_values",
                dataset_name,
                "validity",
                failed,
                len(frame),
                f"{failed:,} giá trị ngoài danh sách cho phép",
            )
        )

    for column in spec.get("non_negative", []):
        numeric = pd.to_numeric(frame[column], errors="coerce")
        invalid = frame[column].notna() & numeric.isna()
        failed = int(((numeric < 0) | invalid).sum())
        results.append(
            _result(
                f"{column}_non_negative",
                dataset_name,
                "validity",
                failed,
                len(frame),
                f"{failed:,} giá trị âm hoặc không phải số",
            )
        )

    for column, bounds in spec.get("ranges", {}).items():
        numeric = pd.to_numeric(frame[column], errors="coerce")
        invalid = frame[column].notna() & numeric.isna()
        failed = int(((numeric < bounds[0]) | (numeric > bounds[1]) | invalid).sum())
        results.append(
            _result(
                f"{column}_range",
                dataset_name,
                "validity",
                failed,
                len(frame),
                f"{failed:,} giá trị ngoài khoảng [{bounds[0]}, {bounds[1]}]",
            )
        )

    return frame, results


def validate_directory(data_dir: Path, contract_path: Path, output_path: Path) -> dict[str, Any]:
    contract = load_contract(contract_path)
    frames: dict[str, pd.DataFrame] = {}
    results: list[CheckResult] = []

    for dataset_name, spec in contract["datasets"].items():
        frame, dataset_results = validate_dataset(dataset_name, spec, data_dir)
        results.extend(dataset_results)
        if frame is not None:
            frames[dataset_name] = frame

    for relationship in contract.get("foreign_keys", []):
        child_name = relationship["child_dataset"]
        parent_name = relationship["parent_dataset"]
        if child_name not in frames or parent_name not in frames:
            continue
        child = frames[child_name][relationship["child_column"]].dropna()
        parent_values = set(frames[parent_name][relationship["parent_column"]].dropna())
        failed = int((~child.isin(parent_values)).sum())
        results.append(
            _result(
                relationship["name"],
                child_name,
                "integrity",
                failed,
                len(child),
                f"{failed:,} khóa không tồn tại trong {parent_name}",
                relationship.get("severity", "ERROR"),
            )
        )

    serialized = [asdict(item) for item in results]
    summary = {
        "total_checks": len(results),
        "passed": sum(item.status == "PASS" for item in results),
        "warnings": sum(item.status == "WARN" for item in results),
        "errors": sum(item.status == "ERROR" for item in results),
    }
    report = {
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "summary": summary,
        "results": serialized,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    return report
