
resource "random_string" "default" {
  length = 32
  special=false
  upper=false
}
locals {
  bucket_name = "${random_string.default.result}"
  functionrandomextension = "${random_string.default.result}"
  lambda_content = "lambda.zip"
  dynamotable="items"
} 
 provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
  access_key = "AKIAIED2T2PHG6FI33HA"
  secret_key = "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"
}

resource "aws_s3_bucket" "b" {
  bucket = local.bucket_name
  acl    = "private"

  tags = {
    Name        = local.bucket_name
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_object" "object" {
  bucket = local.bucket_name
  key    = local.lambda_content
  source = "${path.module}/${local.lambda_content}"
 depends_on = [
   "aws_s3_bucket.b"
  ]
  etag = "${filemd5("${path.module}/${local.lambda_content}")}"
}
 
 # IAM role which dictates what other AWS services the Lambda function
 # may access.
 resource "aws_iam_role" "lambda_exec" {
   name = "function-${local.bucket_name}-policy"

   assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
 EOF

 }


resource "aws_lambda_function" "getbyidfunction" {
   function_name = "getitembyid-${local.functionrandomextension}"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content

   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "src/handlers/get-by-id.getByIdHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
 }


resource "aws_lambda_function" "putitemfunction" {
   function_name = "putitem-${local.functionrandomextension}"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content

   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "src/handlers/put-item.putItemHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
 }
 
resource "aws_lambda_function" "getallitemsfunction" {
   function_name = "putgetallitems-${local.functionrandomextension}"

   # The bucket name as created earlier with "aws s3api create-bucket"
   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content

   # "main" is the filename within the zip file (main.js) and "handler"
   # is the name of the property under which the handler function was
   # exported in that file.
   handler = "src/handlers/get-all-items.getAllItemsHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
 }
 resource "aws_dynamodb_table" "dynamotable" {
  name             = local.dynamotable
  hash_key         = "Id"
  billing_mode     = "PAY_PER_REQUEST"
 
  attribute {
    name = "Id"
    type = "S"
  }
  attribute {
    name = "Value"
    type = "S"
  }

}

 output "bucket_name" {
  value = local.bucket_name
}
