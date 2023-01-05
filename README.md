Description
===========

This repository contains experimental Terraform code to deploy
[AWSRedrive](https://github.com/nickntg/awsredrive.core) to AWS.

Deployment
==========

A default VPC is assumed to be configured in the selected AWS region. If that
is not the case, `aws ec2 create-default-vpc` can be used to create it.

The first two commands below are optional and needed only if the AWS
credentials are not configured and if SSH access is desired, respectively.

```
$ aws configure
$ export TF_VAR_awsredrive_key_pair_name=foo@bar
$ terraform apply
```

Terraform will deploy the following resources:

1. Debian 11 EC2 instance configured to run AWSRedrive as a systemd service
2. SNS/SQS pair and roles/policies for the EC2 instance to be able to process
   messages from the queue
3. Security group that allows inbound SSH connections

If a key pair was specified above, the status and logs of AWSRedrive can be
inspected using:

```
$ ssh admin@$(terraform output -raw public_ip)

admin@ip-xx-xx-xx-xx:~$ systemctl status awsredrive
admin@ip-xx-xx-xx-xx:~$ journalctl -u awsredrive
```

Upgrading AWSRedrive
====================

Changing `awsredrive_version` in `variables.tf` and applying the Terraform
configuration will create a new EC2 instance running the new version of
AWSRedrive. The old EC2 instance will be terminated after the new one has been
created.

The same process can be used for rolling back to an older version.

Possible improvements
=====================

1. Install CloudWatch Agent to the EC2 instance and push application logs to
   CloudWatch
2. Implement support for multiple deployment environments (dev/staging/prod)
3. Extract the SNS/SQS pair creation into a template so it can be reused
4. Make the creation of the SSH security group conditional upon the use of a
   key pair
5. Store the Terraform state in an S3 bucket or a managed database

Known issues
============

The AWSRedrive process does not launch cleanly under systemd. As a workaround,
the current systemd service runs it under bash with stdin closed.
