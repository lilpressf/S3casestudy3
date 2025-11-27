resource "aws_dynamodb_table" "employees" {
  name         = "innovatech-employees"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "employee_id"

  attribute {
    name = "employee_id"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "cs3-innovatech"
    Purpose     = "employee-lifecycle"
  }
}

resource "aws_dynamodb_table" "devices" {
  name         = "innovatech-devices"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "device_id"

  attribute {
    name = "device_id"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "cs3-innovatech"
    Purpose     = "device-management"
  }
}

resource "aws_dynamodb_table" "audit_logs" {
  name         = "innovatech-audit-logs"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "log_id"

  attribute {
    name = "log_id"
    type = "S"
  }

  tags = {
    Environment = "dev"
    Project     = "cs3-innovatech"
    Purpose     = "audit-logging"
  }
}
