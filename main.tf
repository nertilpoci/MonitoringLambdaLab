
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

//configure
 provider "aws" {
  version = "~> 2.0"
  region  = "us-east-1"
  access_key = "AKIAJQVHTHUEM6WOP6HA"
  secret_key = "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"
}

//create s3 bucket
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
 
# lambda permissions

resource "aws_iam_role" "lambda_exec" {
  name = "myrole"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}


resource "aws_lambda_function" "getbyidfunction" {
   function_name = "getitembyid-${local.functionrandomextension}"
   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content
   handler = "src/handlers/get-by-id.getByIdHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
   environment {
    variables = {
      SAMPLE_TABLE = local.dynamotable
    }
  }
 }
resource "aws_lambda_function" "putitemfunction" {
   function_name = "putitem-${local.functionrandomextension}"

   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content
   handler = "src/handlers/put-item.putItemHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
   environment {
    variables = {
      SAMPLE_TABLE = local.dynamotable
    }
  }
 }
 
resource "aws_lambda_function" "getallitemsfunction" {
   function_name = "putgetallitems-${local.functionrandomextension}"

   s3_bucket = local.bucket_name
   s3_key    = local.lambda_content
   handler = "src/handlers/get-all-items.getAllItemsHandler"
   runtime = "nodejs10.x"

   role = aws_iam_role.lambda_exec.arn
   depends_on = [
   "aws_s3_bucket_object.object"
  ]
   environment {
    variables = {
      SAMPLE_TABLE = local.dynamotable
    }
  }
 }


# Create dynamo db table

 resource "aws_dynamodb_table" "dynamotable" {
  name             = local.dynamotable
  hash_key         = "id"
  billing_mode     = "PAY_PER_REQUEST"
 
  attribute {
    name = "id"
    type = "S"
  }
  attribute {
    name = "name"
    type = "S"
  }
  global_secondary_index {
    name               = "NameIndex"
    hash_key           = "name"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "INCLUDE"
    non_key_attributes = ["id"]
  }


}

#lambda access to dynamodb



# POLICIES
resource "aws_iam_role_policy" "dynamodb-lambda-policy"{
  name = "dynamodb_lambda_policy"
  role = "${aws_iam_role.lambda_exec.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:*"
      ],
      "Resource": "${aws_dynamodb_table.dynamotable.arn}"
    }
  ]
}
EOF
}





 # Set permissions on the lambda function, allowing API Gateway to invoke the function
resource "aws_lambda_permission" "allow_api_gateway-getbyidfunction" {
  # The action this permission allows is to invoke the function
  action = "lambda:InvokeFunction"

  # The name of the lambda function to attach this permission to
  function_name = "${aws_lambda_function.getbyidfunction.arn}"

  # An optional identifier for the permission statement
  statement_id = "AllowExecutionFromApiGateway"

  # The item that is getting this lambda permission
  principal = "apigateway.amazonaws.com"

  # /*/*/* sets this permission for all stages, methods, and resource paths in API Gateway to the lambda
  # function. - https://bit.ly/2NbT5V5
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}
 # Set permissions on the lambda function, allowing API Gateway to invoke the function
resource "aws_lambda_permission" "allow_api_gateway-putitemfunction" {
  # The action this permission allows is to invoke the function
  action = "lambda:InvokeFunction"

  # The name of the lambda function to attach this permission to
  function_name = "${aws_lambda_function.putitemfunction.arn}"

  # An optional identifier for the permission statement
  statement_id = "AllowExecutionFromApiGateway"

  # The item that is getting this lambda permission
  principal = "apigateway.amazonaws.com"

  # /*/*/* sets this permission for all stages, methods, and resource paths in API Gateway to the lambda
  # function. - https://bit.ly/2NbT5V5
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

 # Set permissions on the lambda function, allowing API Gateway to invoke the function
resource "aws_lambda_permission" "allow_api_gateway-getallitemsfunction" {
  # The action this permission allows is to invoke the function
  action = "lambda:InvokeFunction"

  # The name of the lambda function to attach this permission to
  function_name = "${aws_lambda_function.getallitemsfunction.arn}"

  # An optional identifier for the permission statement
  statement_id = "AllowExecutionFromApiGateway"

  # The item that is getting this lambda permission
  principal = "apigateway.amazonaws.com"

  # /*/*/* sets this permission for all stages, methods, and resource paths in API Gateway to the lambda
  # function. - https://bit.ly/2NbT5V5
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/*"
}

# API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name = "awslab"
}

resource "aws_api_gateway_resource" "mainapiresource" {
  path_part   = "awslab"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}
//get all items
//getall items method
resource "aws_api_gateway_method" "getallmethod" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.mainapiresource.id}"
  http_method   = "GET"
  authorization = "NONE"
}
//getallitems integration
resource "aws_api_gateway_integration" "getallitemsintegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.mainapiresource.id}"
  http_method             = "${aws_api_gateway_method.getallmethod.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.getallitemsfunction.invoke_arn}"
}

//put item method
resource "aws_api_gateway_method" "putitemmethod" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.mainapiresource.id}"
  http_method   = "POST"
  authorization = "NONE"
}
//getitembyid integration
resource "aws_api_gateway_integration" "putitemintegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.mainapiresource.id}"
  http_method             = "${aws_api_gateway_method.putitemmethod.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.putitemfunction.invoke_arn}"
}



//get item by id
resource "aws_api_gateway_resource" "getbyidresource" {
  path_part   = "{id}"
  parent_id   = "${aws_api_gateway_resource.mainapiresource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}
//get item by id method
resource "aws_api_gateway_method" "getbyidmethod" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.getbyidresource.id}"
  http_method   = "GET"
  authorization = "NONE"
}
//getitembyid integration
resource "aws_api_gateway_integration" "getbyideintegration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.getbyidresource.id}"
  http_method             = "${aws_api_gateway_method.getbyidmethod.http_method}"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.getbyidfunction.invoke_arn}"
}


 output "bucket_name" {
  value = local.bucket_name
}
