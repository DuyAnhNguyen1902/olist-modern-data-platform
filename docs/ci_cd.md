# CI/CD

GitHub Actions workflow `.github/workflows/ci.yml` validates every push and pull request.

## Quality gates

1. Ruff formatting check.
2. Ruff linting.
3. Python unit tests with pytest.
4. dbt project parsing without partial-parse cache.
5. Docker Compose configuration validation.

The workflow uses Python 3.12, matching the Airflow image. It does not require production
credentials or raw Olist files because `dbt parse` validates project structure, Jinja, sources,
refs, tests, and configuration without executing warehouse queries.

## Run the same checks locally

Install the project and development dependencies once:

```powershell
python -m pip install -e ".[dev]"
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_ci_checks.ps1
```

CI is intentionally separated from runtime integration validation. The Docker/Airflow/dbt
end-to-end result is recorded in `docs/end_to_end_validation.md`.

## GitHub setup

After creating an empty GitHub repository, add it as `origin`, push the branch, and verify the
**Data Platform CI** workflow in the Actions tab. Protect the default branch by requiring the
`Python, dbt, and Compose validation` check before merge.
