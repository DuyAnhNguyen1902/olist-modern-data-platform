"""Scheduled incremental ingestion from the simulated PostgreSQL OLTP source."""

from __future__ import annotations

from datetime import timedelta

import pendulum
from airflow.sdk import dag, task

from olist_pipeline.dbt_runner import dbt_build
from olist_pipeline.incremental import (
    INCREMENTAL_DATASETS,
    get_watermarks,
    ingest_incremental_dataset,
)
from olist_pipeline.settings import settings


@dag(
    dag_id="olist_incremental",
    description="Watermark-based incremental ingestion from PostgreSQL source",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    tags=["portfolio", "olist", "incremental", "watermark"],
    default_args={
        "owner": "data-engineering",
        "retries": 2,
        "retry_delay": timedelta(seconds=30),
    },
)
def olist_incremental():
    @task(execution_timeout=timedelta(minutes=2))
    def check_source_ready() -> dict:
        watermarks = get_watermarks(settings)
        configured = {item["dataset"] for item in watermarks}
        missing = sorted(set(INCREMENTAL_DATASETS) - configured)
        if missing:
            raise RuntimeError(
                f"Source simulator is not initialized. Missing watermarks: {missing}"
            )
        return {"datasets": len(configured), "status": "READY"}

    @task(execution_timeout=timedelta(minutes=10))
    def ingest_dataset(dataset_name: str) -> dict:
        return ingest_incremental_dataset(settings, dataset_name)

    @task(execution_timeout=timedelta(minutes=20))
    def build_and_test_dbt_incremental() -> dict:
        return dbt_build(settings)

    ready = check_source_ready()
    ingested = ingest_dataset.expand(dataset_name=list(INCREMENTAL_DATASETS))
    dbt_built = build_and_test_dbt_incremental()

    ready >> ingested >> dbt_built


olist_incremental()
