## Crewvia Python Monorepo Template

Opinionated, future‑proof starter for a microservice architecture in Python with:

- Services and packages in a single monorepo
- Terraform + LocalStack for infrastructure as code and local cloud emulation
- Makefile commands as the CLI for dev workflows
- Foundation for CI/CD pipelines
- Target platform: Amazon Web Services (AWS)

### Repository layout

- `services/`
  - `api/`: FastAPI service
  - `web/`: Django service
- `packages/`
  - Shared Python libraries (e.g., `util_math`, `data_io`)
- `infra/`
  - `services/`: Terraform modules for app infrastructure (used with LocalStack for local dev)
  - `app/` and `shared/`: Additional infra components
- `docker-compose.yml`: Local dev stack (includes LocalStack)
- `Makefile`: Single entrypoint for workflows (run, test, Terraform, etc.)

### Prerequisites

- Docker + Docker Compose
- `uv` (Python package manager) and Python 3.11+
- Terraform CLI and `tflocal` (terraform‑local wrapper)

### Quick start (local dev)

1) Bring up the local stack (LocalStack + services):

```bash
docker compose up -d
```

2) Install deps for all packages/services:

```bash
make sync
```

3) Terraform (LocalStack):

```bash
# Initialize providers/modules
make tflocal-init

# Validate configuration (syntax/types, no cloud calls)
make tflocal-validate

# Apply (non-interactive by default)
make tflocal-apply

# Destroy
make tflocal-destroy
```

Sensitive vars (example):

```bash
TF_VAR_SIGNING_PRIVATE_KEY="..." TF_VAR_SIGNING_PUBLIC_KEY="..." make tflocal-apply
```

4) Run services locally:

```bash
make run-api
make run-web
```

### AWS deployment intent

The Terraform in `infra/` is written for AWS. Local development uses LocalStack; production deploys target real AWS accounts. CI/CD can reuse the same Make targets with different backends/vars.

### CI/CD foundation

- `make fmt`, `make lint`, `make type`, `make test`, `make cov` are CI‑friendly.
- `make tflocal-validate` should run in PR checks to fail fast on infra issues.

### Networking (AWS)

- VPC and subnets (`infra/services/network.tf`)
  - One VPC (10.0.0.0/16) with DNS support enabled
  - Two public subnets (per AZ) routed to an Internet Gateway
  - Two private subnets (per AZ) routed to a NAT Gateway (egress only)
  - Separate route tables for public and private subnets
  - Optional Cloud Map HTTP namespace `private.crewvia` for service discovery (non‑LocalStack)

- Web service (`infra/app/service-web.tf`)
  - ECS Fargate task in public subnets with public IP
  - Exposed behind an ALB target group on port 3000, health check at `/healthcheck`
  - Security group allows 3000/tcp from the VPC CIDR; egress open to internet
  - Service Connect enabled (namespace `private.crewvia`)

- API service (`infra/app/service-api.tf`)
  - ECS Fargate task in private subnets, no public IP
  - Security group allows 9000/tcp from within VPC; egress open via NAT
  - Service Connect publishes as `api.private.crewvia` (client alias port 9000)
  - Environment and AWS resource references provided via Secrets Manager and outputs

#### Networking diagram

```mermaid
flowchart LR
  Internet((Internet)) -->|HTTPS| ALB[ALB]

  subgraph VPC[ VPC 10.0.0.0/16 ]
    direction LR

    subgraph PublicSubnets[Public Subnets]
      PSa[Subnet A]
      PSb[Subnet B]
    end

    subgraph PrivateSubnets[Private Subnets]
      PRa[Subnet A]
      PRb[Subnet B]
    end

    IGW[Internet Gateway]
    NAT[NAT Gateway]

    ALB --- PSa
    ALB --- PSb

    Web[Web Service (Fargate, :3000, public IP)] --- PSa
    Web --- PSb

    API[API Service (Fargate, :9000, no public IP)] --- PRa
    API --- PRb

    PSa --> IGW
    PSb --> IGW
    PRa -->|0.0.0.0/0| NAT --> IGW
    PRb -->|0.0.0.0/0| NAT

    Web -->|Service Connect| API
  end
```

### Utilities

- Local AWS CLI against LocalStack:

```bash
make localaws CMD="s3 ls"
```

### Conventions

- Prefer `make` targets over ad‑hoc commands.
- Keep shared logic in `packages/` and service‑specific code in `services/`.
- Treat Terraform as code: small modules, validated and formatted in CI.

### Notes

- This repo is a template; extend services, modules, and CI as your system grows.


