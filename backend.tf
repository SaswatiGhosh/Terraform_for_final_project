terraform {
  backend "s3" {
    bucket = "saswati-s3-bucket-11"
    region = "ap-south-1"
    key= "saswati/terraform.tfstate"
    
  }
}