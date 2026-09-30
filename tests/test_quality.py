import tempfile
import unittest
from pathlib import Path

from olist_pipeline.quality import validate_dataset


class DataContractTests(unittest.TestCase):
    def test_valid_dataset_passes_contract(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory)
            csv_path = temp_path / "orders.csv"
            csv_path.write_text(
                "order_id,customer_id,status,amount\no-1,c-1,paid,10.50\no-2,c-2,pending,0\n",
                encoding="utf-8",
            )
            spec = {
                "file": "orders.csv",
                "required_columns": ["order_id", "customer_id", "status", "amount"],
                "not_null": ["order_id", "customer_id"],
                "unique": [["order_id"]],
                "accepted_values": {"status": ["paid", "pending"]},
                "non_negative": ["amount"],
            }

            _, results = validate_dataset("orders", spec, temp_path)

            self.assertTrue(results)
            self.assertTrue(all(result.status == "PASS" for result in results))

    def test_invalid_dataset_reports_quality_failures(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            temp_path = Path(directory)
            csv_path = temp_path / "orders.csv"
            csv_path.write_text(
                "order_id,customer_id,status,amount\no-1,c-1,paid,10\no-1,,unexpected,-2\n",
                encoding="utf-8",
            )
            spec = {
                "file": "orders.csv",
                "required_columns": ["order_id", "customer_id", "status", "amount"],
                "not_null": ["order_id", "customer_id"],
                "unique": [["order_id"]],
                "accepted_values": {"status": ["paid", "pending"]},
                "non_negative": ["amount"],
            }

            _, results = validate_dataset("orders", spec, temp_path)
            failing_tests = {result.test_name for result in results if result.status == "ERROR"}

            self.assertIn("customer_id_not_null", failing_tests)
            self.assertIn("order_id_unique", failing_tests)
            self.assertIn("status_accepted_values", failing_tests)
            self.assertIn("amount_non_negative", failing_tests)


if __name__ == "__main__":
    unittest.main()
