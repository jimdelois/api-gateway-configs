#!/bin/bash
yum install -y aws-cli
aws s3 cp s3://kong-us-east-1-165383265659/ecs-kong.config /etc/ecs/ecs.config

# TODO: This is absolutely where Secure Parameters should be called in:
# https://aws.amazon.com/blogs/compute/managing-secrets-for-amazon-ecs-applications-using-parameter-store-and-iam-roles-for-tasks/
# (Keep in mind, this is for the entire instance, though. If multiple applications end up deployed to this instance,
#  there may be security implications to consider; As well as various tiers of apps dev/stg/prod)