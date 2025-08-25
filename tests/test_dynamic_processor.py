import unittest
from unittest.mock import MagicMock, patch
import os
import sys

# Add the src directory to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../scripts/lambda")))

from dynamic_processor import DynamicProcessor

class TestDynamicProcessor(unittest.TestCase):

    @patch("boto3.resource")
    def test_get_processing_config_found(self, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_1", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table

        processor = DynamicProcessor("test_table")
        config = processor.get_processing_config("test_table_1")

        self.assertIsNotNone(config)
        self.assertEqual(config["table_name"], "test_table_1")
        mock_table.get_item.assert_called_with(Key={
            "table_name": "test_table_1"
        })

    @patch("boto3.resource")
    def test_get_processing_config_not_found(self, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {}
        mock_boto3_resource.return_value.Table.return_value = mock_table

        processor = DynamicProcessor("test_table")
        config = processor.get_processing_config("non_existent_table")

        self.assertIsNone(config)

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_lambda_strategy(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_lambda", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "success"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_lambda", 300, "Bronze")

        self.assertEqual(result["status"], "success")
        self.assertEqual(result["strategy"], "Spark on AWS Lambda")
        self.assertEqual(result["target_layer"], "Bronze")
        mock_run_glue_data_quality_check.assert_called_with("test_table_lambda", "Landing", "Structural and Schema Validation")

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_kubernetes_strategy(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_eks", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "success"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_eks", 5000, "Silver")

        self.assertEqual(result["status"], "success")
        self.assertEqual(result["strategy"], "Spark on Kubernetes (EKS)")
        self.assertEqual(result["target_layer"], "Silver")
        mock_run_glue_data_quality_check.assert_called_with("test_table_eks", "Silver", "Completeness and Consistency")

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_glue_strategy(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_glue", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "success"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_glue", 15000, "Gold")

        self.assertEqual(result["status"], "success")
        self.assertEqual(result["strategy"], "Spark on AWS Glue")
        self.assertEqual(result["target_layer"], "Gold")
        mock_run_glue_data_quality_check.assert_called_with("test_table_glue", "Gold", "Accuracy and Business Rules")

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_no_config(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {}
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "success"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("non_existent_table", 100, "Bronze")

        self.assertEqual(result["status"], "failed")
        self.assertIn("No configuration found", result["message"])
        mock_run_glue_data_quality_check.assert_not_called()

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_dq_check_fails_bronze(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_fail_dq", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "failed", "error": "DQ failed"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_fail_dq", 100, "Bronze")

        self.assertEqual(result["status"], "failed")
        self.assertIn("Data Quality check failed", result["message"])
        mock_run_glue_data_quality_check.assert_called_with("test_table_fail_dq", "Landing", "Structural and Schema Validation")

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_dq_check_fails_silver(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_fail_dq", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "failed", "error": "DQ failed"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_fail_dq", 5000, "Silver")

        self.assertEqual(result["status"], "failed")
        self.assertIn("Data Quality check failed", result["message"])
        mock_run_glue_data_quality_check.assert_called_with("test_table_fail_dq", "Silver", "Completeness and Consistency")

    @patch("boto3.resource")
    @patch.object(DynamicProcessor, "run_glue_data_quality_check")
    def test_process_data_dq_check_fails_gold(self, mock_run_glue_data_quality_check, mock_boto3_resource):
        mock_table = MagicMock()
        mock_table.get_item.return_value = {
            "Item": {"table_name": "test_table_fail_dq", "param1": "value1"}
        }
        mock_boto3_resource.return_value.Table.return_value = mock_table
        mock_run_glue_data_quality_check.return_value = {"status": "failed", "error": "DQ failed"}

        processor = DynamicProcessor("test_table")
        result = processor.process_data("test_table_fail_dq", 15000, "Gold")

        self.assertEqual(result["status"], "failed")
        self.assertIn("Data Quality check failed", result["message"])
        mock_run_glue_data_quality_check.assert_called_with("test_table_fail_dq", "Gold", "Accuracy and Business Rules")

if __name__ == "__main__":
    unittest.main()


