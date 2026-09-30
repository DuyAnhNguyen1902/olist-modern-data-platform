from __future__ import annotations

import argparse
import sys
from datetime import UTC, datetime

from .database import (
    build_warehouse,
    initialize_database,
    load_raw_data,
    reconcile_raw_counts,
    validate_warehouse,
)
from .dbt_runner import dbt_build, dbt_debug
from .incremental import (
    INCREMENTAL_DATASETS,
    get_watermarks,
    ingest_incremental_dataset,
    initialize_source,
    simulate_source_changes,
)
from .profiling import profile_directory
from .quality import validate_directory
from .settings import settings


def _timestamped_report(prefix: str):
    timestamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    return settings.reports_dir / f"{prefix}_{timestamp}.json"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Olist data platform CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("profile", help="Tạo báo cáo data profiling")
    subparsers.add_parser("validate", help="Kiểm tra data contract cho CSV")
    subparsers.add_parser("init-db", help="Tạo schema và bảng PostgreSQL")
    load_parser = subparsers.add_parser("load-raw", help="Nạp CSV vào PostgreSQL RAW")
    load_parser.add_argument("--replace", action="store_true", help="Nạp lại bảng raw")
    subparsers.add_parser("check-raw", help="Đối chiếu số dòng CSV với RAW")
    subparsers.add_parser("build-warehouse", help="Xây Kimball warehouse")
    subparsers.add_parser("validate-warehouse", help="Chạy kiểm tra warehouse")
    subparsers.add_parser("init-source", help="Tạo và seed OLTP source mô phỏng")
    subparsers.add_parser("simulate-source", help="Tạo thay đổi mới trong OLTP source")
    incremental_parser = subparsers.add_parser(
        "ingest-incremental", help="Nạp thay đổi từ source vào RAW"
    )
    incremental_parser.add_argument(
        "--dataset", choices=INCREMENTAL_DATASETS, help="Bỏ trống để nạp tất cả dataset"
    )
    subparsers.add_parser("show-watermarks", help="Hiển thị watermark hiện tại")
    subparsers.add_parser("dbt-debug", help="Kiểm tra kết nối và cấu hình dbt")
    dbt_parser = subparsers.add_parser("dbt-build", help="Chạy dbt models và tests")
    dbt_parser.add_argument(
        "--full-refresh", action="store_true", help="Xây lại toàn bộ dbt models"
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()

    if args.command == "profile":
        output = _timestamped_report("profile")
        report = profile_directory(settings.data_dir, output)
        total_rows = sum(item["row_count"] for item in report["datasets"])
        print(f"Profiled {len(report['datasets'])} files with {total_rows:,} total rows.")
        print(f"Report: {output}")
        return

    if args.command == "validate":
        output = _timestamped_report("quality")
        report = validate_directory(settings.data_dir, settings.quality_config, output)
        summary = report["summary"]
        print(
            f"Checks: {summary['total_checks']} | PASS: {summary['passed']} | "
            f"WARN: {summary['warnings']} | ERROR: {summary['errors']}"
        )
        print(f"Report: {output}")
        if summary["errors"]:
            sys.exit(1)
        return

    if args.command == "init-db":
        initialize_database(settings)
        print("Created PostgreSQL schemas, raw tables, and staging views.")
        return

    if args.command == "load-raw":
        load_raw_data(settings, replace=args.replace)
        print("Loaded all CSV files into the raw schema.")
        return

    if args.command == "check-raw":
        results = reconcile_raw_counts(settings)
        for item in results:
            print(
                f"{item['dataset']:22} CSV={item['source_count']:>9,} "
                f"RAW={item['database_count']:>9,} {item['status']}"
            )
        if any(item["status"] == "ERROR" for item in results):
            sys.exit(1)
        return

    if args.command == "build-warehouse":
        build_warehouse(settings)
        print("Rebuilt the Kimball warehouse.")
        return

    if args.command == "validate-warehouse":
        rows = validate_warehouse(settings)
        for row in rows:
            print(" | ".join(str(value) for value in row[:-1]))
        if any(row[3] == "ERROR" for row in rows):
            sys.exit(1)
        return

    if args.command == "init-source":
        initialize_database(settings)
        initialize_source(settings)
        print("Created and seeded the simulated OLTP source.")
        return

    if args.command == "simulate-source":
        result = simulate_source_changes(settings)
        print(f"Created source changes: {result}")
        return

    if args.command == "ingest-incremental":
        datasets = [args.dataset] if args.dataset else INCREMENTAL_DATASETS
        for dataset in datasets:
            result = ingest_incremental_dataset(settings, dataset)
            print(
                f"{dataset:15} rows={result['rows_extracted']:,} "
                f"watermark={result['new_watermark']}"
            )
        return

    if args.command == "show-watermarks":
        for item in get_watermarks(settings):
            print(
                f"{item['dataset']:15} rows={item['rows_extracted']:>5,} "
                f"watermark={item['watermark']}"
            )
        return

    if args.command == "dbt-debug":
        result = dbt_debug(settings)
        print(result["output_tail"])
        return

    if args.command == "dbt-build":
        result = dbt_build(settings, full_refresh=args.full_refresh)
        print(result["output_tail"])
        return


if __name__ == "__main__":
    main()
