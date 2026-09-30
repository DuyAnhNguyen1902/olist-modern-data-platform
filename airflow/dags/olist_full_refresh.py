"""Airflow orchestration for the Olist full-refresh learning pipeline."""

from __future__ import annotations

from datetime import timedelta

import pendulum
from airflow.sdk import dag, task

from olist_pipeline.database import (
    initialize_database,
    load_raw_data,
    reconcile_raw_counts,
)
from olist_pipeline.dbt_runner import dbt_build
from olist_pipeline.profiling import profile_directory
from olist_pipeline.quality import validate_directory
from olist_pipeline.settings import settings


@dag(
    dag_id="olist_full_refresh",
    description="Validate, load, model, and quality-check the Olist warehouse",
    schedule=None,
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["portfolio", "olist", "data-quality", "kimball"],
    default_args={
        "owner": "data-engineering",
        "retries": 1,
        "retry_delay": timedelta(seconds=30),
    },
)
def olist_full_refresh():
    """A manual full refresh; incremental ingestion is introduced in a later phase."""

    @task(execution_timeout=timedelta(minutes=10))
    def profile_source() -> dict:
        output = settings.reports_dir / "airflow_source_profile.json"
        report = profile_directory(settings.data_dir, output)
        return {
            "files": len(report["datasets"]),
            "rows": sum(item["row_count"] for item in report["datasets"]),
        }

    @task(execution_timeout=timedelta(minutes=10))
    def validate_source() -> dict:
        output = settings.reports_dir / "airflow_source_quality.json"
        report = validate_directory(settings.data_dir, settings.quality_config, output)
        if report["summary"]["errors"]:
            raise RuntimeError(f"Source quality gate failed: {report['summary']}")
        return report["summary"]

    @task(retries=2, execution_timeout=timedelta(minutes=2))
    def initialize_postgres() -> None:
        initialize_database(settings)

    @task(retries=2, execution_timeout=timedelta(minutes=15))
    def load_raw_full_refresh() -> None:
        load_raw_data(settings, replace=True)

    @task(execution_timeout=timedelta(minutes=5))
    def reconcile_raw() -> dict:
        results = reconcile_raw_counts(settings)
        mismatches = [item for item in results if item["status"] != "PASS"]
        if mismatches:
            raise RuntimeError(f"RAW reconciliation failed: {mismatches}")
        return {"datasets": len(results), "status": "PASS"}

    @task(retries=1, execution_timeout=timedelta(minutes=20))
    def build_and_test_dbt() -> dict:
        return dbt_build(settings, full_refresh=True)

    profile = profile_source()
    source_quality = validate_source()
    database_ready = initialize_postgres()
    raw_loaded = load_raw_full_refresh()
    raw_reconciled = reconcile_raw()
    dbt_built = build_and_test_dbt()

    profile >> source_quality >> database_ready >> raw_loaded
    raw_loaded >> raw_reconciled >> dbt_built


olist_full_refresh()
