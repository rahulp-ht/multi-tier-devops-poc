# AWS cost and usage report for the Multi-tier DevOps POC

**Prepared 21 November 2026** · **Mumbai (ap-south-1)** · **USD**

AWS recorded **$91.01 in pre-credit usage charges on account billing meters that match the POC**, for **1 through 20 November 2026 UTC**. This is the closest available estimate of POC spend. The full AWS account recorded **$91.02 in usage charges** and **$91.02 in credits**, leaving **$0.00 net** at cent precision. AWS marks the billing period as estimated.

**Current always-on POC baseline: $0.30235 per hour or $220.71 per month** at Mumbai On-Demand rates, before credits, taxes, and usage-based charges.

The matching subtotal may include shared or untagged usage. The `Project` cost allocation tag is inactive, the `Project=multi-tier-poc` query returned no line items, and resource-level billing data is disabled. AWS therefore cannot verify an exact historical POC-only total or split historical charges by individual host. [AWS Cost Explorer API](https://docs.aws.amazon.com/aws-cost-management/latest/APIReference/API_GetCostAndUsage.html) · [AWS cost allocation tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)

## Actual AWS usage and charges

The table uses Cost Explorer `UsageQuantity` by usage type and `UnblendedCost` for records of type `Usage`. Charges are before credits. Values below one cent are shown where useful. Historical and current resources appear together where they share a billing meter.

| Service or meter | Verified POC configuration | AWS account usage, 1–20 Nov UTC | Usage charge |
|---|---|---:|---:|
| EC2 compute | Two private Linux `c7i-flex.large` ECS hosts | 197.214 matching instance-hours | $16.72 |
| EBS gp3 | Two 30 GiB root disks at 3,000 IOPS and 125 MiB/s each | 8.223 GB-month | $0.75 |
| Amazon ECS | ECS on EC2, with two frontend and two backend tasks at normal capacity | 143.285 vCPU-hours and 143.285 GB-hours on ECS on EC2 meters | $0.00 |
| Amazon RDS compute | Single-AZ `db.t3.micro`, currently MySQL 8.4.11 | 143.516 matching instance-hours | $3.59 |
| Amazon RDS gp3 storage | 20 GiB, with one day of automated backup retention | 5.074 GB-month. No separate backup charge was identified. | $0.66 |
| RDS Extended Support | Historical MySQL 8.0 usage before the upgrade | 262.599 vCPU-hours | $29.94 |
| Application Load Balancer | One internet-facing ALB in two AZs, with HTTP and HTTPS listeners | 184 ALB-hours and 0.258665 LCU-hours | $4.40 |
| NAT gateway | One public zonal NAT in `ap-south-1a` | 15 gateway-hours and 0.041504 GB processed | $0.84 |
| Public IPv4 | One NAT Elastic IP. The fixed-cost model assumes two ALB IPv4 addresses. | 347.662 in-use address-hours and 0.167 idle address-hours | $1.74 |
| AWS PrivateLink interface endpoints | Historical. All 10 paid POC interface endpoints have been removed. | 2,435 endpoint-AZ-hours and 0.638099 GB processed | $31.66 |
| S3 gateway endpoint | One active gateway endpoint for S3 access and ECR image-layer downloads | No gateway endpoint charge | $0.00 |
| Amazon ECR | Two private repositories, `multi-tier-poc/frontend` and `multi-tier-poc/backend` | 0.022724 GB-month of registry storage | $0.00227 |
| AWS Secrets Manager | Application DB secret and an RDS-managed master credential secret | Mumbai meters show 0.510756 secret-month and 234 API requests | $0.20547 |
| Amazon CloudWatch | One POC dashboard and two ECS log groups with 7-day retention | 0.008569 GB of Mumbai log ingestion, plus dashboard and alarm usage | $0.00 |
| Amazon Route 53 | One hosted zone with an alias from `poc.therahulpatil.in` to the ALB | 1 hosted zone, 8,082 standard queries, and 744 intra-AWS queries | $0.50323 |
| AWS Certificate Manager | One certificate on the POC HTTPS listener | 1 Mumbai public certificate domain issuance | $0.00 |
| AWS KMS | RDS storage encryption is enabled | 838 Mumbai KMS requests across the account | $0.00 |
| AWS Systems Manager | Session Manager access directly to the private ECS hosts | No standalone session charge appears in the usage records | $0.00 |
| Amazon VPC and EC2 Auto Scaling | Public and private subnets, route tables, security groups, and one EC2 Auto Scaling group | Associated NAT, IPv4, endpoint, EC2, and transfer costs are accounted for on their own meters | No separate charge identified |
| AWS IAM | ECS host, ECS task, and deployment access policies | No separate usage charge identified | $0.00 |
| **POC-matching subtotal** | **Pre-credit charges on matching account meters** | Shared or untagged usage may be included | **$91.01** |

The matching subtotal sums the displayed billing meters using AWS amounts before rounding. It includes historical PrivateLink and MySQL 8.0 Extended Support charges. The complete account total also includes small data-transfer and API charges. The Route 53 zone serves multiple records, and its full zone and query totals cannot be isolated to the POC hostname from Cost Explorer.

## Current fixed-cost baseline

The baseline assumes 730 hours in a month, continuous operation of the current resources, and no credits or discounts. The rates are from the AWS Price List API for Mumbai, with the AWS commercial public IPv4 rate. The hourly column shows the total for the listed quantity, with storage expressed as a monthly charge divided by 730. There is no bastion in the baseline. [AWS Price List API](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-changes.html)

| Current resource | Quantity and AWS On-Demand rate | USD/hour | USD/month |
|---|---|---:|---:|
| EC2 Linux compute | 2 hosts × $0.08479 per host-hour | $0.16958 | $123.79 |
| EC2 gp3 root storage | 60 GiB × $0.09120 per GB-month | $0.00750 | $5.47 |
| RDS MySQL compute | 1 instance × $0.02500 per hour | $0.02500 | $18.25 |
| RDS gp3 storage | 20 GiB × $0.13100 per GB-month | $0.00359 | $2.62 |
| Public NAT gateway | 1 gateway × $0.05600 per hour | $0.05600 | $40.88 |
| Application Load Balancer | 1 ALB × $0.02390 per hour | $0.02390 | $17.45 |
| Public IPv4 | 3 addresses × $0.00500 per address-hour | $0.01500 | $10.95 |
| Secrets Manager | 2 active DB secrets × $0.40 per secret-month | $0.00110 | $0.80 |
| Route 53 hosted zone | 1 shared public zone × $0.50 per month, fully included in this estimate | $0.00068 | $0.50 |
| CloudWatch dashboard and alarms | 1 dashboard and 2 standard-resolution alarms within applicable allowances | $0.00000 | $0.00 |
| **Fixed-cost baseline** | **Calculated before rounding individual rows** | **$0.30235** | **$220.71** |

The baseline includes the full fee for the shared Route 53 hosted zone and both verified database secrets. CloudWatch is modeled at $0.00 for its current dashboard and alarms because the account's reported usage was within the applicable free allowance. The baseline does not assume AWS promotional credits.

## Usage-based costs and services with no fixed fee

Add the variable charges below to the fixed baseline as usage accrues. AWS recorded the usage available for 1–20 November in the earlier table. Traffic and storage volumes change over time.

| Service | Current POC use | Additional charge or fixed-fee treatment |
|---|---|---|
| NAT gateway and ALB | One NAT gateway and one load balancer | NAT processing at $0.056 per GB and ALB capacity at $0.008 per LCU-hour. The gateway and load balancer hourly fees are in the baseline. |
| AWS data transfer | Internet and cross-AZ traffic, including traffic from AZ B to NAT in AZ A | Billed where applicable based on the traffic path and volume. |
| Amazon ECR | Two private image repositories | No repository fee. Private image storage is $0.10 per GB-month, with transfer charges where applicable. |
| CloudWatch Logs and API | Two log groups with 7-day retention | Mumbai Standard logs are $0.67 per GB ingested and $0.03 per GB-month stored after applicable allowances. Queries and API usage can add charges. |
| CloudWatch dashboard and alarms | One dashboard and two standard-resolution scaling alarms | $0.00 at current allowance. If uncovered, list rates for these resources are $3.00 per dashboard-month plus $0.10 per alarm metric-month. |
| AWS Secrets Manager and Route 53 | Two secrets and a public DNS alias to the ALB | Secrets API calls at $0.05 per 10,000 calls. The POC alias to ELB has no Route 53 query charge. Other records in the shared zone can generate query charges. |
| Amazon RDS backups | One day of automated backup retention | Excess backup storage and retained snapshots can add usage charges. |
| Amazon VPC and S3 | VPC networking and one S3 gateway endpoint for ECR layers | No fee for the gateway endpoint. Standard S3 charges apply if billed storage or requests are used. |
| Amazon ECS and EC2 Auto Scaling | ECS on EC2 with one Auto Scaling group | No separate service fee for this setup. Extra EC2 hosts during a deployment add compute and disk usage. |
| AWS Systems Manager, IAM, ACM, and KMS | Session Manager on EC2, IAM roles, a non-exportable ACM certificate on the ALB, and an AWS-managed KMS key for RDS | No separate fixed fee for these configurations. KMS requests and optional session logging can add charges. |

Rates and allowance details come from AWS pricing. [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) · [AWS ALB pricing](https://aws.amazon.com/elasticloadbalancing/pricing/) · [Amazon ECR pricing](https://aws.amazon.com/ecr/pricing/) · [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) · [Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) · [Route 53 pricing](https://aws.amazon.com/route53/pricing/) · [KMS pricing](https://aws.amazon.com/kms/pricing/)

## Historical charges that no longer match the current configuration

- **MySQL 8.0 Extended Support accounted for $29.94.** The RDS event log confirms the same DB instance upgraded to MySQL 8.4.11 on 19 November. The MySQL 8.0 Extended Support meter has no usage on 20 November in the available billing data. [AWS RDS Extended Support charges](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/extended-support-charges.html)
- **Interface endpoints accounted for $31.66.** Cost Explorer includes endpoint hours through 20 November. The live POC VPC now contains only the S3 gateway endpoint, which has no additional endpoint fee. The fixed-cost baseline includes the NAT gateway that replaced those interfaces. [AWS S3 gateway endpoint pricing](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html)

No AWS resources, billing settings, or Terraform settings were changed for this report.
