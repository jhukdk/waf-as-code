resource "aws_api_gateway_rest_api" "demo" {
  name        = "${var.project_name}-demo"
  description = "Demo API protected by WAF"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_method" "root_get" {
  rest_api_id   = aws_api_gateway_rest_api.demo.id
  resource_id   = aws_api_gateway_rest_api.demo.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_get" {
  rest_api_id = aws_api_gateway_rest_api.demo.id
  resource_id = aws_api_gateway_rest_api.demo.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "root_get_200" {
  rest_api_id = aws_api_gateway_rest_api.demo.id
  resource_id = aws_api_gateway_rest_api.demo.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration_response" "root_get_200" {
  rest_api_id = aws_api_gateway_rest_api.demo.id
  resource_id = aws_api_gateway_rest_api.demo.root_resource_id
  http_method = aws_api_gateway_method.root_get.http_method
  status_code = aws_api_gateway_method_response.root_get_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      service = "waf-as-code demo"
      status  = "200"
      "Best tennis player in MD?" = "David J. Kim"
    })
  }

  depends_on = [aws_api_gateway_integration.root_get]
}

resource "aws_api_gateway_deployment" "demo" {
  rest_api_id = aws_api_gateway_rest_api.demo.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.root_get.id,
      aws_api_gateway_integration.root_get.id,
      aws_api_gateway_method_response.root_get_200.id,
      aws_api_gateway_integration_response.root_get_200.id,
      aws_api_gateway_integration_response.root_get_200.response_templates,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_api_gateway_integration_response.root_get_200]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.demo.id
  deployment_id = aws_api_gateway_deployment.demo.id
  stage_name    = "prod"
}
