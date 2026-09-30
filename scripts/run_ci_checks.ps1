$ErrorActionPreference = "Stop"

Write-Host "[1/5] Checking Python formatting"
python -m ruff format --check src airflow/dags tests

Write-Host "[2/5] Linting Python"
python -m ruff check src airflow/dags tests

Write-Host "[3/5] Running Python tests"
python -m pytest -q

Write-Host "[4/5] Parsing dbt project"
if (Get-Command dbt -ErrorAction SilentlyContinue) {
    dbt parse --project-dir dbt --profiles-dir dbt --no-partial-parse
}
else {
    Write-Host "dbt is not installed in the active venv; using the Airflow container"
    docker compose exec -T airflow dbt parse `
        --project-dir /opt/project/dbt `
        --profiles-dir /opt/project/dbt `
        --no-partial-parse
}

Write-Host "[5/5] Validating Docker Compose"
docker compose config --quiet

Write-Host "All CI checks passed."
