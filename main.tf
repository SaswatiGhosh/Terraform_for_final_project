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
    bucket = "smart-upload-doc"

}

resource "aws_s3_bucket_policy" "allow_access_from_another_account" {
  bucket = aws_s3_bucket.s3_bucket.id
  policy = data.aws_iam_policy_document.allow_access_from_another_account.json
}

data "aws_iam_policy_document" "allow_access_from_another_account" {
  statement {
    principals {
      type        = "AWS"
     identifiers = ["123456789012"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.s3_bucket,
      "${aws_s3_bucket.smart-upload-doc.arn}/*",
    ]
  }
}
resource "aws_s3_bucket_notification" "notification_object_uploaded_in_s3" {
  bucket = aws_s3_bucket.s3_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.start_textract_lambda
    events = ["s3:ObjectCreated:*"]
  }
  
}
resource "aws_lambda_permission" "start_textract_lambda_permission" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_textract_lambda.start_textract_lambda
  principal = "s3.amazon.com"
  source_arn = "arn:aws:s3:::smart-upload-doc"
  
}

#lambda function

# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"] # All kore debo
#   }
# }

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = jsondecode({
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "s3-object-lambda:*"
            ],
            "Resource": "*"
        }
    ]
}
 


  })

}
# resource "aws_iam_user_policy_attachment" "lambda_policy" {
   
#   role=aws_iam_role.iam_for_lambda.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  
# }

# data "archive_file" "lambda1" {
#   type        = "zip"
#   source_file = "process_textract_result_lambda.py"
#   output_path = "process_textract_result_lambda.zip"
# }
# data "archive_file" "lambda2" {
#   type        = "zip"
#   source_file = "start_textract_lambda.py"
#   output_path = "start_textract_lambda.zip"
# }

resource "aws_lambda_function" "start_textract_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "start_textract_lambda.zip"
  function_name = "start_textract_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.test"

  source_code_hash = filebase64sha256("start_textract_lambda.zip")

  runtime = "python3.13"


}
resource "aws_lambda_function" "process_textract_result_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "process_textract_result_lambda.zip"
  function_name = "process_textract_result_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.test"

  source_code_hash = filebase64sha256("process_textract_result_lambda.zip")

  runtime = "python3.13"

}


resource "aws_sns_topic" "user_updates" {
  name = "user-updates-topic"
}
resource "aws_sns_topic_subscription" "name" {
  topic_arn = aws_sns_topic.user_updates.arn
  protocol = "lambda"
  endpoint = "arn:aws:sns:ap-south-1:080636249926:process-textract"
}
