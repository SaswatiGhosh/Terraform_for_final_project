provider "aws" {
  region = "ap-south-1"

}
# resource "aws_instance" "saswati" {
#     instance_type = "t2.micro"
#     ami = "ami-0e35ddab05955cf57"
#     subnet_id = "subnet-06e8432ff61e832e8"

# }

# s3 bucket policies and roles
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "test-----terraform"
}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["080636249926"]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject"
    ]
    resources = [
      aws_s3_bucket.s3_bucket.arn,
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
  }
}


#lambda function
resource "aws_iam_role" "assume_role" {
  name = "assume_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"

}

resource "aws_iam_role_policy" "iam_for_lambda" {
  name = "iam_for_lambda"
  role = aws_iam_role.assume_role.name
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:*",
          "s3-object-lambda:*"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "SNSFullAccess",
        "Effect" : "Allow",
        "Action" : "sns:*",
        "Resource" : "*"
      },
      {
        "Sid" : "SMSAccessViaSNS",
        "Effect" : "Allow",
        "Action" : [
          "sms-voice:DescribeVerifiedDestinationNumbers",
          "sms-voice:CreateVerifiedDestinationNumber",
          "sms-voice:SendDestinationNumberVerificationCode",
          "sms-voice:SendTextMessage",
          "sms-voice:DeleteVerifiedDestinationNumber",
          "sms-voice:VerifyDestinationNumber",
          "sms-voice:DescribeAccountAttributes",
          "sms-voice:DescribeSpendLimits",
          "sms-voice:DescribePhoneNumbers",
          "sms-voice:SetTextMessageSpendLimitOverride",
          "sms-voice:DescribeOptedOutNumbers",
          "sms-voice:DeleteOptedOutNumber"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:CalledViaLast" : "sns.amazonaws.com"
          }
        }
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "textract:*"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# To zip the lambda function python files
data "archive_file" "lambda1" {
  type        = "zip"
  source_file = "process_textract_result_lambda.py"
  output_path = "process_textract_result_lambda.zip"
}
data "archive_file" "lambda2" {
  type        = "zip"
  source_file = "start_textract_lambda.py"
  output_path = "start_textract_lambda.zip"
}

resource "aws_lambda_function" "start_textract_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = lambda2.output_path
  function_name = "start_textract_lambda_test"
  role          = aws_iam_role.assume_role.arn
  handler       = "start_textract_lambda.lambda_handler"

  source_code_hash = filebase64sha256(lambda2.output_path)

  runtime = "python3.13"
}

resource "aws_lambda_function" "process_textract_result_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = lambda1.output_path
  function_name = "process_textract_result_lambda_test"
  role          = aws_iam_role.assume_role.arn
  handler       = "process_textract_result_lambda.lambda_handler"

  source_code_hash = filebase64sha256(lambda1.output_path)

  runtime = "python3.13"

}

resource "aws_sns_topic" "user_updates" {
  name = "sns-document-analysis"
}


resource "aws_lambda_permission" "start_textract_lambda_permission" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_textract_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::test-----terraform"
}

# Triggered when s3 bucket object uploaded
resource "aws_s3_bucket_notification" "notification_object_uploaded_in_s3" {
  bucket = aws_s3_bucket.s3_bucket.bucket
  lambda_function {
    lambda_function_arn = aws_lambda_function.start_textract_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
  depends_on = [aws_lambda_permission.start_textract_lambda_permission]
}
# Lambda Permission for SNS to invoke Lambda 2
resource "aws_lambda_permission" "allow_sns_invoke_process_textract_result_lambda" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_textract_result_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.user_updates.arn
}

resource "aws_sns_topic_subscription" "name" {
  topic_arn = aws_sns_topic.user_updates.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.process_textract_result_lambda.arn
}

resource "aws_lambda_function_event_invoke_config" "lambda_event_invoke_config" {
  function_name = aws_lambda_function.start_textract_lambda.function_name
  destination_config {
    on_success {
      destination = aws_sns_topic.user_updates.arn
    }
  }
}
