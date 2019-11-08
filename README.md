# Sunshine Cybernetics Infrastructure as Code

This repo contains the code that defines our infrastructure.

For now, we are only managing one environment: Production.

This repository consists of multiple terraform projects, each located on its own directory:

- `prod/` - Production environment (K8S Cluster + Applications)
- `dns/` - Domain DNS records (A, CNAME, MX, ...)

The state is stored on Terraform Cloud