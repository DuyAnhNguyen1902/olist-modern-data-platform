"""Print raw table counts and compare them with the source CSV row counts."""

from __future__ import annotations

from olist_pipeline.database import reconcile_raw_counts
from olist_pipeline.settings import settings


def main() -> None:
    results = reconcile_raw_counts(settings)
    for item in results:
        print(
            f"{item['dataset']:22} CSV={item['source_count']:>9,} "
            f"RAW={item['database_count']:>9,} {item['status']}"
        )
    if any(item["status"] == "ERROR" for item in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
