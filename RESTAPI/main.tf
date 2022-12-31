provider "aws" {
    region = "eu-west-2"
}

data "archive_file" "lambda-zip" {
    type="zip"
    source_dir = "lambda"
    output_path = "lambda.zip"
}

data "aws_iam_policy_document" "policy" {
  statement {

    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda2" {
  name               = "iam_for_lambda2"
  assume_role_policy = "${data.aws_iam_policy_document.policy.json}"
}

resource "aws_lambda_function" "lambda" {

  function_name = "lambda-function"
  filename         = "lambda.zip"
  role    = aws_iam_role.iam_for_lambda2.arn
  handler = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime = "python3.9"

}

resource "aws_apigatewayv2_api" "lambda-api" {
  name        = "v2-http-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda-stage" {
  api_id = aws_apigatewayv2_api.lambda-api.id
  name = "$default"
  auto_deploy = true
}


resource "aws_apigatewayv2_integration" "lambda-integration" {
  api_id           = aws_apigatewayv2_api.lambda-api.id
  integration_type = "AWS_PROXY"
  integration_method = "POST"
  integration_uri = aws_lambda_function.lambda.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"

}

resource "aws_apigatewayv2_route" "lambda_route" {

  api_id = aws_apigatewayv2_api.lambda-api.id
  route_key = "GET /{proxy+}"
  target = "integrations/${aws_apigatewayv2_integration.lambda-integration.id}"

}

resource "aws_lambda_permission" "api-gw" {

    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.lambda.arn
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_apigatewayv2_api.lambda-api.execution_arn}/*/*/*"

}

