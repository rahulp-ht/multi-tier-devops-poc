# Multi-Tier DevOps POC — operator walkthrough

24 November 2026 · Run the commands from the repository root in Bash unless a block says otherwise.

## 1. Prepare the operator session

Use the intended AWS account and a role or profile approved for the operation. Read-only inventory needs describe/list permissions. Starting or stopping requires ECS service, ASG, EC2 and RDS permissions. A Session Manager connection also requires operator session permissions, the Session Manager plugin, and an online managed EC2 host. For Terraform review use Terraform 1.5 or later and access to the existing state. Jenkins needs its configured credentials, SonarQube integration and compatible Docker image access across CI and CD.

```bash
aws --version
terraform version
export AWS_PROFILE=trainee AWS_REGION=ap-south-1 AWS_PAGER=""
CLUSTER=multi-tier-poc-cluster
ASG=multi-tier-poc-ecs-asg
DB=multi-tier-poc-db
FRONTEND=multi-tier-poc-frontend
BACKEND=multi-tier-poc-backend
SITE=https://poc.therahulpatil.in
aws sts get-caller-identity --query Account --output text
```

Expect account `809554586055`. Change the profile to an equivalent approved identity if needed. The core Terraform provider explicitly uses the `trainee` profile. Avoid storing credentials in the repository, shell transcript, or report.

## 2. Review Terraform before changing infrastructure

Core AWS resources are in `terraform/`. The public DNS alias, ACM certificate, certificate validation, HTTPS listener/rules and HTTPS ingress are managed from the separate `route53/` root. Work with the existing state for each root. The core cutover file shown below contains the NAT and interface endpoint selections. Confirm all effective inputs against the deployment record, including capacity and service enable flags. A new or incorrect state can produce a plan to duplicate live infrastructure.

```bash
terraform -chdir=terraform init
terraform -chdir=terraform state list
terraform -chdir=terraform validate
terraform -chdir=terraform plan -var-file=poc-live.tfvars -var-file=nat-endpoint-final.tfvars
```

For a DNS or TLS change, review that root with its existing state and approved inputs.

```bash
terraform -chdir=route53 init
terraform -chdir=route53 state list
terraform -chdir=route53 validate
terraform -chdir=route53 plan
```

Inspect each action. Verify that RDS, the ALB, private subnet associations, and ECS services are not unexpectedly replaced or removed. Check the three active private routes (local, S3 and NAT). The current working tree also contains a separate ECR lifecycle edit. A paused environment can show expected differences in desired capacity and service counts. Review before applying anything. Treat state, plans, and any rendered secret attributes as sensitive.

## 3. Bring the POC online

The `Hault/` script set is currently local. From a fresh checkout, obtain the approved `poc-start.sh`, `poc-stop.sh` and `poc-common.sh` from the POC owner before running this section. Avoid running start or stop during a deployment.

```bash
bash -n Hault/poc-start.sh && bash -n Hault/poc-stop.sh &&
  bash -n Hault/poc-common.sh
bash Hault/poc-start.sh
```

Type `START` at the prompt. The script validates the account, starts RDS if needed, starts existing standby hosts and returns them to service, or restores a two-host ASG if the group is empty. It checks EC2 and ECS readiness, sets each service to two tasks, waits for healthy ALB targets and checks the public site. Expected end state is RDS `available`, two hosts `InService`, and two running tasks per service.

## 4. Check website, API, capacity and routing

```bash
curl --fail --silent --show-error --max-time 15 -o /dev/null \
  -w 'Website HTTP %{http_code}\n' "$SITE/"
curl --fail --silent --show-error --max-time 15 -o /dev/null \
  -w 'Books API HTTP %{http_code}\n' "$SITE/api/books"

aws ecs describe-services --cluster "$CLUSTER" \
  --services "$FRONTEND" "$BACKEND" \
  --query 'services[].[serviceName,desiredCount,runningCount,pendingCount,taskDefinition]' \
  --output table
aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$ASG" \
  --query 'AutoScalingGroups[0].Instances[].[InstanceId,AvailabilityZone,LifecycleState]' \
  --output table
aws rds describe-db-instances --db-instance-identifier "$DB" \
  --query 'DBInstances[0].[DBInstanceStatus,AvailabilityZone,MultiAZ,Endpoint.Address]' \
  --output table
```

Expect HTTP 200 for each request, two running tasks per service, normally one host per AZ, and an available single-AZ database in 1a. The public API test exercises MySQL. The target group's `/health` is checked directly against private backend tasks.

```bash
for service in "$FRONTEND" "$BACKEND"; do
  tg=$(aws ecs describe-services --cluster "$CLUSTER" --services "$service" \
    --query 'services[0].loadBalancers[0].targetGroupArn' --output text)
  aws elbv2 describe-target-health --target-group-arn "$tg" \
    --query 'TargetHealthDescriptions[].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason]' \
    --output table
done
aws ec2 describe-route-tables \
  --route-table-ids rtb-026e0e64693886254 \
  --query 'RouteTables[0].{Subnets:Associations[].SubnetId,Routes:Routes}' --output json
```

Expect two healthy targets on TCP 80 and two on TCP 3200 once the services settle. The private table should show both subnet associations, VPC local routing, the S3 prefix-list route to the gateway endpoint, and default IPv4 to NAT.

## 5. Deploy and verify an application change

Push to a feature branch, review the Branch Security Scanning results, and use the approved PR workflow. From Jenkins, review the appropriate main CI build, including SonarQube and Trivy gates. Follow the downstream CD job for that successful build. Confirm the upstream build and tag, ECR digest artifact, baseline/spare-capacity stages, backend and frontend stabilization, and capacity cleanup.

```bash
aws ecs wait services-stable --cluster "$CLUSTER" \
  --services "$BACKEND" "$FRONTEND"
for service in "$BACKEND" "$FRONTEND"; do
  task_def=$(aws ecs describe-services --cluster "$CLUSTER" --services "$service" \
    --query 'services[0].taskDefinition' --output text)
  aws ecs describe-task-definition --task-definition "$task_def" \
    --query 'taskDefinition.containerDefinitions[].[name,image]' --output table
done
```

Compare both image references byte-for-byte with the matching approved digests in `ecr-images.properties`. A stable service after circuit-breaker rollback can still be on the old revision. Repeat the website and API smoke tests and the target health check. Confirm the ASG returns to its normal configuration after cleanup.

## 6. Inspect a private host and its logs

Get the live instance ID from the ASG output in step 4, then assign it when prompted. Session Manager needs a running instance registered as online.

```bash
read -r -p 'Running ECS EC2 instance ID: ' HOST_ID
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$HOST_ID" \
  --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output table
aws ssm start-session --target "$HOST_ID"
```

Inside the session, inspect containers and return to your workstation.

```bash
sudo docker ps
exit
```

From your workstation, review logs for the last 15 minutes.

```bash
aws logs tail /ecs/multi-tier-poc/backend --since 15m
aws logs tail /ecs/multi-tier-poc/frontend --since 15m
aws ecs describe-services --cluster "$CLUSTER" --services "$BACKEND" "$FRONTEND" \
  --query 'services[].{Service:serviceName,Events:events[0:5].[createdAt,message]}' \
  --output json
```

Each healthy host normally shows an ECS agent plus application containers and task networking containers. Perform container inspection through the approved operator role. The EC2 host SG requires no inbound SSH rule.

## 7. Troubleshoot by symptom

| Symptom | Checks |
| --- | --- |
| DNS failure or TLS warning | Confirm the host resolves to the ALB alias and check the current ACM certificate and HTTPS listener configuration. |
| ALB 502/503 or unhealthy targets | Check ECS desired/running counts, target health reason codes, listener rules, target ports, and ALB-to-task security group rules. |
| Browser loads but books API fails | Confirm the frontend was built with `VITE_API_URL=/api`. Test `/api/books` directly, then check backend logs, RDS availability, task DB settings, TCP 3306 rules and the VPC local route. |
| Task pending or rollout stalled | Read ECS service events, verify the spare EC2 host is active with an agent connected, and check CPU, memory, ENI capacity and distinct-host placement. Verify RDS and NAT for healthy startup. |
| Cannot pull image or initialize task | Verify the approved digest exists in ECR, access through the execution identity, private default NAT routing, the S3 endpoint route and reachability to Secrets Manager. |
| Session Manager target is offline | Verify region, instance state, the host instance profile, SSM agent status and the outbound HTTPS path. Verify operator permissions and the local plugin. |
| Pipeline stabilized on the wrong revision | Check the ECS rollout reason, Jenkins CD digest verification, stopped-task reason and whether ECS rolled back. Keep the approved image and baseline evidence for review. |

## 8. Pause the POC

Run the stop script from an approved terminal when the environment can be offline.

```bash
bash Hault/poc-stop.sh
```

Type `STOP` at the prompt. The script scales services to zero, waits for tasks to drain, puts hosts into ASG Standby while adjusting capacity, stops EC2, and stops RDS. Use step 4 to verify zero desired/running tasks and RDS `stopped`. Use EC2 describe-instances with the recorded host IDs to confirm each host is `stopped`; the ASG membership can show `Standby` independently of EC2 power state. Expect the website to become unavailable. NAT, ALB, Elastic IP/public IPv4 charges, EBS, RDS storage, DNS and other retained resources can still incur charges. RDS can automatically restart when its stop limit is reached.

## Reference

- Infrastructure definitions are in `terraform/` and `route53/`.
- Release definitions are `.github/workflows/branch-security.yml`, `Jenkinsfile.ci`, `Jenkinsfile.cd` and `scripts/cleanup-ecs-capacity.sh`.
- See [POC-Report.md](POC-Report.md) for architecture, security, costs and open items.
