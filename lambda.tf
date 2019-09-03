resource "random_string" "name" {
  length  = 4
  special = false
  upper   = false
}

data "archive_file" "dir_hash_zip" {
  type        = "zip"
  source_dir  = "${var.source_code_path}/"
  output_path = "${path.module}/dir_hash_zip"
}

resource "null_resource" "install_python_dependencies" {
  triggers = {
    requirements = sha1(file("${var.source_code_path}/requirements.txt"))
    dir_hash     = data.archive_file.dir_hash_zip.output_base64sha256
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/py_pkg.sh"

    environment = {
      source_code_path = var.source_code_path
      path_cwd         = path.cwd
      path_module      = path.module
      runtime          = var.runtime
      function_name    = var.function_name
      lambda_pkg_dir   = var.lambda_pkg_dir
    }
  }
}

data "archive_file" "lambda_zip" {
  depends_on  = ["null_resource.install_python_dependencies"]
  type        = "zip"
  source_dir  = "${path.cwd}/${var.lambda_pkg_dir}/"
  output_path = var.output_path
}

resource "aws_lambda_function" "lambda" {
  filename         = var.output_path
  description      = var.description
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = var.role_arn
  function_name    = var.function_name
  handler          = var.handler_name
  runtime          = var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size

  vpc_config {
    security_group_ids = var.security_group_ids
    subnet_ids         = var.subnet_ids
  }

  environment {
    variables = var.environment
  }
}
