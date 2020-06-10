
resource "random_string" "default" {
  length = 32
  special=false
  upper=false
}
locals {
  bucket_name = "${random_string.default.result}"
  functionrandomextension = "${random_string.default.result}"
  apigatewayextension = "${random_string.default.result}"
  lambda_content = "lambda.zip"
  dynamotable="items"
} 
 provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
  access_key = "AKIAJQVHTHUEM6WOP6HA"
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


resource "aws_api_gateway_rest_api" "example" {
  name        = "ServerlessExample"
  description = "Terraform Serverless Application Example"
}
 resource "aws_api_gateway_resource" "proxy" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   parent_id   = aws_api_gateway_rest_api.example.root_resource_id
   path_part   = "awslab"
}

resource "aws_api_gateway_method" "proxy" {
   rest_api_id   = aws_api_gateway_rest_api.example.id
   resource_id   = aws_api_gateway_resource.proxy.id
   http_method   = "ANY"
   authorization = "NONE"
 }
 resource "aws_api_gateway_integration" "lambda" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   resource_id = aws_api_gateway_method.proxy.resource_id
   http_method = aws_api_gateway_method.proxy.http_method

   integration_http_method = "GET"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.getbyidfunction.invoke_arn
 }
  resource "aws_api_gateway_method" "proxy_root" {
   rest_api_id   = aws_api_gateway_rest_api.example.id
   resource_id   = aws_api_gateway_rest_api.example.root_resource_id
   http_method   = "GET"
   authorization = "NONE"
 }

 resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = aws_api_gateway_rest_api.example.id
   resource_id = aws_api_gateway_method.proxy_root.resource_id
   http_method = aws_api_gateway_method.proxy_root.http_method

   integration_http_method = "GET"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.getbyidfunction.invoke_arn
 }

 output "bucket_name" {
  value = local.bucket_name
}
