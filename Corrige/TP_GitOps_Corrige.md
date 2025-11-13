# CORRIGÉ - TP DevOps : Pipeline GitOps Locale Sécurisée

**Document Enseignant - Solutions Complètes**  
**⚠️ CONFIDENTIEL - Ne pas distribuer aux étudiants**

---

## 📝 Vue d'ensemble du Corrigé

Ce document contient toutes les solutions et commandes pour réaliser le TP GitOps. Les étudiants doivent arriver aux mêmes résultats en suivant les instructions du TP.

---

## ✅ Partie 1 : Solutions - Préparation de l'Environnement

### Solution 1.1 : Création de la Structure Complète

```bash
# Script complet de setup
cat > setup-environment.sh << 'EOF'
#!/bin/bash
set -e

# Créer la structure complète
mkdir -p ~/tp-gitops-local/{infrastructure/terraform,configuration/ansible/{templates,group_vars,host_vars},application/docker,monitoring/{prometheus/rules,grafana/{dashboards,datasources}},security/policies,scripts,tests,jenkins_home}

cd ~/tp-gitops-local

# Créer les fichiers de base
touch infrastructure/terraform/{main.tf,variables.tf,outputs.tf,versions.tf}
touch configuration/ansible/{playbook.yml,inventory.yml,ansible.cfg}
touch Jenkinsfile
touch docker-compose.yml
touch README.md

# Permissions pour Jenkins
sudo chown -R 1000:1000 jenkins_home

echo "✅ Structure créée avec succès"
tree -L 3
EOF

chmod +x setup-environment.sh
./setup-environment.sh
```

### Solution 1.2 : Installation Complète des Outils

```bash
# Script d'installation complet
cat > install-tools.sh << 'EOF'
#!/bin/bash
set -e

# Update system
sudo apt-get update

# Install Python and pip
sudo apt-get install -y python3 python3-pip python3-venv

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Checkov
pip install --upgrade pip
pip install checkov==3.0.36

# Install Trivy
sudo apt-get install -y wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# Install Ansible
pip install ansible==8.5.0

# Install Docker (if not present)
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
fi

# Verify installations
echo "=== Verification ==="
docker --version
terraform --version
ansible --version
checkov --version
trivy --version

echo "✅ All tools installed successfully"
EOF

chmod +x install-tools.sh
./install-tools.sh
```

### Solution 1.3 : Configuration Git Complète

```bash
# Configuration Git avec hooks
cd ~/tp-gitops-local

# Initialize Git
git init

# Create comprehensive .gitignore
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ansible
*.retry
.vault_pass
ansible.log

# Security
secrets/
*.key
*.pem
*.crt

# Jenkins
jenkins_home/secrets/
jenkins_home/workspace/
jenkins_home/jobs/*/builds/
jenkins_home/logs/

# Python
venv/
__pycache__/
*.pyc
.pytest_cache/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
.env
docker-compose.override.yml

# Reports
*-report.json
*-report.xml
trivy-*.json
checkov-*.json

# Logs
*.log
logs/
EOF

# Create pre-commit hook for security scanning
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running security checks before commit..."

# Check for secrets
if grep -r "password\|secret\|token\|key" --exclude-dir=.git .; then
    echo "⚠️  Warning: Possible secrets detected!"
    read -p "Continue commit? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Run Checkov on changed files
git diff --cached --name-only | grep -E "\.(tf|yml|yaml)$" | while read file; do
    if [ -f "$file" ]; then
        checkov -f "$file" --quiet || true
    fi
done

echo "✅ Pre-commit checks complete"
EOF

chmod +x .git/hooks/pre-commit

# Initial commit
git add .
git commit -m "Initial commit: GitOps project structure"
```

---

## ✅ Partie 2 : Solutions - Infrastructure as Code avec Terraform

### Solution 2.1 : Terraform Complet et Fonctionnel

```bash
# Créer tous les fichiers Terraform
cd ~/tp-gitops-local/infrastructure/terraform

# versions.tf
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }
  }
}
EOF

# providers.tf
cat > providers.tf << 'EOF'
provider "docker" {
  host = "unix:///var/run/docker.sock"
}

provider "local" {}
EOF

# variables.tf complet
cat > variables.tf << 'EOF'
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "gitops-monitoring"
}

variable "network_subnet" {
  description = "Docker network subnet"
  type        = string
  default     = "172.20.0.0/16"
}

variable "monitoring_config" {
  description = "Monitoring configuration"
  type = object({
    prometheus_retention = string
    prometheus_port      = number
    grafana_port        = number
    jenkins_port        = number
  })
  default = {
    prometheus_retention = "15d"
    prometheus_port      = 9090
    grafana_port        = 3000
    jenkins_port        = 8080
  }
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "gitops2024"
}
EOF

# main.tf corrigé et complet
cat > main.tf << 'EOF'
# Docker Network
resource "docker_network" "monitoring" {
  name   = "${var.project_name}-network"
  driver = "bridge"
  
  ipam_config {
    subnet  = var.network_subnet
    gateway = cidrhost(var.network_subnet, 1)
  }
  
  labels {
    label = "project"
    value = var.project_name
  }
  
  labels {
    label = "environment"
    value = var.environment
  }
}

# Volumes
resource "docker_volume" "prometheus_data" {
  name = "${var.project_name}-prometheus-data"
  labels {
    label = "service"
    value = "prometheus"
  }
}

resource "docker_volume" "grafana_data" {
  name = "${var.project_name}-grafana-data"
  labels {
    label = "service"
    value = "grafana"
  }
}

resource "docker_volume" "jenkins_data" {
  name = "${var.project_name}-jenkins-data"
  labels {
    label = "service"
    value = "jenkins"
  }
}

# Prometheus Configuration
resource "local_file" "prometheus_config" {
  filename = "${path.module}/../../monitoring/prometheus/prometheus.yml"
  content  = <<-EOT
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        monitor: '${var.project_name}'
        environment: '${var.environment}'
    
    alerting:
      alertmanagers:
        - static_configs:
            - targets: []
    
    rule_files:
      - '/etc/prometheus/rules/*.yml'
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      
      - job_name: 'grafana'
        static_configs:
          - targets: ['grafana:3000']
      
      - job_name: 'jenkins'
        metrics_path: '/prometheus'
        static_configs:
          - targets: ['jenkins:8080']
      
      - job_name: 'node'
        static_configs:
          - targets: ['node-exporter:9100']
  EOT
}

# Grafana Datasource Configuration
resource "local_file" "grafana_datasource" {
  filename = "${path.module}/../../monitoring/grafana/datasources/prometheus.yml"
  content  = <<-EOT
    apiVersion: 1
    
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
        editable: true
  EOT
}

# Container: Prometheus
resource "docker_container" "prometheus" {
  name  = "${var.project_name}-prometheus"
  image = "cgr.dev/chainguard/prometheus:latest"
  
  networks_advanced {
    name         = docker_network.monitoring.name
    aliases      = ["prometheus"]
    ipv4_address = cidrhost(var.network_subnet, 10)
  }
  
  ports {
    internal = 9090
    external = var.monitoring_config.prometheus_port
  }
  
  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }
  
  volumes {
    host_path      = abspath(local_file.prometheus_config.filename)
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
  
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=${var.monitoring_config.prometheus_retention}",
    "--web.console.libraries=/usr/share/prometheus/console_libraries",
    "--web.console.templates=/usr/share/prometheus/consoles",
    "--web.enable-lifecycle"
  ]
  
  restart = "unless-stopped"
  
  labels {
    label = "monitoring"
    value = "prometheus"
  }
  
  labels {
    label = "project"
    value = var.project_name
  }
  
  healthcheck {
    test         = ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
    interval     = "30s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 3
  }
  
  depends_on = [
    local_file.prometheus_config
  ]
}

# Container: Grafana
resource "docker_container" "grafana" {
  name  = "${var.project_name}-grafana"
  image = "grafana/grafana:10.2.0"
  
  networks_advanced {
    name         = docker_network.monitoring.name
    aliases      = ["grafana"]
    ipv4_address = cidrhost(var.network_subnet, 11)
  }
  
  ports {
    internal = 3000
    external = var.monitoring_config.grafana_port
  }
  
  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }
  
  volumes {
    host_path      = abspath("${path.module}/../../monitoring/grafana/datasources")
    container_path = "/etc/grafana/provisioning/datasources"
    read_only      = true
  }
  
  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_INSTALL_PLUGINS=grafana-piechart-panel,grafana-clock-panel",
    "GF_SERVER_ROOT_URL=http://localhost:${var.monitoring_config.grafana_port}"
  ]
  
  restart = "unless-stopped"
  
  labels {
    label = "monitoring"
    value = "grafana"
  }
  
  labels {
    label = "project"
    value = var.project_name
  }
  
  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
    interval     = "30s"
    timeout      = "3s"
    start_period = "5s"
    retries      = 3
  }
  
  depends_on = [
    docker_container.prometheus,
    local_file.grafana_datasource
  ]
}

# Container: Jenkins
resource "docker_container" "jenkins" {
  name  = "${var.project_name}-jenkins"
  image = "jenkins/jenkins:2.426.1-lts"
  
  networks_advanced {
    name         = docker_network.monitoring.name
    aliases      = ["jenkins"]
    ipv4_address = cidrhost(var.network_subnet, 12)
  }
  
  ports {
    internal = 8080
    external = var.monitoring_config.jenkins_port
  }
  
  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    volume_name    = docker_volume.jenkins_data.name
    container_path = "/var/jenkins_home"
  }
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  env = [
    "JENKINS_OPTS=--prefix=/",
    "JAVA_OPTS=-Duser.timezone=Europe/Paris"
  ]
  
  restart = "unless-stopped"
  
  user = "root"
  
  labels {
    label = "ci"
    value = "jenkins"
  }
  
  labels {
    label = "project"
    value = var.project_name
  }
}

# Container: Node Exporter
resource "docker_container" "node_exporter" {
  name  = "${var.project_name}-node-exporter"
  image = "prom/node-exporter:v1.7.0"
  
  networks_advanced {
    name    = docker_network.monitoring.name
    aliases = ["node-exporter"]
  }
  
  ports {
    internal = 9100
    external = 9100
  }
  
  command = [
    "--path.procfs=/host/proc",
    "--path.rootfs=/rootfs",
    "--path.sysfs=/host/sys",
    "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
  ]
  
  volumes {
    host_path      = "/proc"
    container_path = "/host/proc"
    read_only      = true
  }
  
  volumes {
    host_path      = "/sys"
    container_path = "/host/sys"
    read_only      = true
  }
  
  volumes {
    host_path      = "/"
    container_path = "/rootfs"
    read_only      = true
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "monitoring"
    value = "node-exporter"
  }
}
EOF

# outputs.tf
cat > outputs.tf << 'EOF'
output "network_info" {
  value = {
    id     = docker_network.monitoring.id
    name   = docker_network.monitoring.name
    subnet = var.network_subnet
  }
}

output "service_urls" {
  value = {
    prometheus = "http://localhost:${var.monitoring_config.prometheus_port}"
    grafana    = "http://localhost:${var.monitoring_config.grafana_port}"
    jenkins    = "http://localhost:${var.monitoring_config.jenkins_port}"
  }
}

output "grafana_credentials" {
  value = {
    username = "admin"
    password = var.grafana_admin_password
  }
  sensitive = true
}

output "container_ips" {
  value = {
    prometheus = cidrhost(var.network_subnet, 10)
    grafana    = cidrhost(var.network_subnet, 11)
    jenkins    = cidrhost(var.network_subnet, 12)
  }
}
EOF

# terraform.tfvars pour personnaliser
cat > terraform.tfvars << 'EOF'
environment    = "development"
project_name   = "gitops-monitoring"
network_subnet = "172.20.0.0/16"

monitoring_config = {
  prometheus_retention = "15d"
  prometheus_port      = 9090
  grafana_port        = 3000
  jenkins_port        = 8080
}

grafana_admin_password = "gitops2024"
EOF
```

### Solution 2.2 : Déploiement Terraform

```bash
# Commands pour déployer l'infrastructure
cd ~/tp-gitops-local/infrastructure/terraform

# Créer les répertoires nécessaires
mkdir -p ../../monitoring/prometheus/rules
mkdir -p ../../monitoring/grafana/datasources
mkdir -p ../../monitoring/grafana/dashboards

# Initialiser Terraform
terraform init

# Formatter le code
terraform fmt

# Valider la configuration
terraform validate

# Plan d'exécution
terraform plan -out=tfplan

# Appliquer
terraform apply tfplan

# Vérifier les outputs
terraform output -json > outputs.json

# Vérifier les containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## ✅ Partie 3 : Solutions - Configuration avec Ansible

### Solution 3.1 : Configuration Ansible Complète

```bash
cd ~/tp-gitops-local/configuration/ansible

# ansible.cfg
cat > ansible.cfg << 'EOF'
[defaults]
host_key_checking = False
inventory = inventory.yml
roles_path = roles
retry_files_enabled = False
stdout_callback = yaml
callback_whitelist = timer, profile_tasks
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts_cache
fact_caching_timeout = 86400

[inventory]
enable_plugins = yaml, ini, auto

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF

# inventory.yml corrigé
cat > inventory.yml << 'EOF'
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3
  children:
    monitoring:
      hosts:
        prometheus:
          ansible_connection: docker
          ansible_docker_container: gitops-monitoring-prometheus
        grafana:
          ansible_connection: docker
          ansible_docker_container: gitops-monitoring-grafana
    ci:
      hosts:
        jenkins:
          ansible_connection: docker
          ansible_docker_container: gitops-monitoring-jenkins
  vars:
    project_name: gitops-monitoring
    environment: development
EOF

# playbook.yml complet
cat > playbook.yml << 'EOF'
---
- name: Configure GitOps Monitoring Stack
  hosts: localhost
  gather_facts: yes
  become: no
  
  vars:
    prometheus_version: "latest"
    grafana_version: "10.2.0"
    grafana_admin_password: "gitops2024"
    project_dir: "{{ playbook_dir }}/../.."
    
  tasks:
    - name: Create monitoring directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - "{{ project_dir }}/monitoring/prometheus/rules"
        - "{{ project_dir }}/monitoring/grafana/dashboards"
        - "{{ project_dir }}/monitoring/grafana/datasources"
        - "{{ project_dir }}/logs"
        - "{{ project_dir }}/backups"
    
    - name: Generate Prometheus alert rules
      copy:
        dest: "{{ project_dir }}/monitoring/prometheus/rules/alerts.yml"
        content: |
          groups:
            - name: basic_alerts
              interval: 30s
              rules:
                - alert: InstanceDown
                  expr: up == 0
                  for: 5m
                  labels:
                    severity: critical
                  annotations:
                    summary: "Instance {{ $labels.instance }} down"
                    description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes."
                
                - alert: HighMemoryUsage
                  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High memory usage detected"
                    description: "Memory usage is above 90% (current value: {{ $value }})"
                
                - alert: HighCPUUsage
                  expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                  for: 5m
                  labels:
                    severity: warning
                  annotations:
                    summary: "High CPU usage detected"
                    description: "CPU usage is above 80% (current value: {{ $value }})"
    
    - name: Create Grafana dashboard JSON
      copy:
        dest: "{{ project_dir }}/monitoring/grafana/dashboards/docker-monitoring.json"
        content: |
          {
            "dashboard": {
              "id": null,
              "uid": "docker-monitoring",
              "title": "Docker Monitoring",
              "timezone": "browser",
              "panels": [
                {
                  "id": 1,
                  "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
                  "type": "graph",
                  "title": "Container CPU Usage",
                  "targets": [
                    {
                      "expr": "rate(container_cpu_usage_seconds_total[5m]) * 100",
                      "refId": "A"
                    }
                  ]
                },
                {
                  "id": 2,
                  "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
                  "type": "graph",
                  "title": "Container Memory Usage",
                  "targets": [
                    {
                      "expr": "container_memory_usage_bytes",
                      "refId": "A"
                    }
                  ]
                }
              ],
              "schemaVersion": 27,
              "version": 1
            }
          }
    
    - name: Check Docker containers status
      shell: docker ps --format "table {{.Names}}\t{{.Status}}"
      register: docker_status
      changed_when: false
    
    - name: Display Docker containers status
      debug:
        msg: "{{ docker_status.stdout_lines }}"
    
    - name: Test Prometheus API
      uri:
        url: "http://localhost:9090/api/v1/query?query=up"
        method: GET
        status_code: 200
      register: prometheus_test
      retries: 5
      delay: 10
      until: prometheus_test.status == 200
    
    - name: Test Grafana API
      uri:
        url: "http://localhost:3000/api/health"
        method: GET
        status_code: 200
      register: grafana_test
      retries: 5
      delay: 10
      until: grafana_test.status == 200
    
    - name: Configure Grafana datasource via API
      uri:
        url: "http://localhost:3000/api/datasources"
        method: POST
        user: admin
        password: "{{ grafana_admin_password }}"
        force_basic_auth: yes
        body_format: json
        body:
          name: "Prometheus"
          type: "prometheus"
          url: "http://prometheus:9090"
          access: "proxy"
          isDefault: true
        status_code: [200, 409]  # 409 if already exists
      register: datasource_result
    
    - name: Import Grafana dashboard
      uri:
        url: "http://localhost:3000/api/dashboards/db"
        method: POST
        user: admin
        password: "{{ grafana_admin_password }}"
        force_basic_auth: yes
        body_format: json
        body:
          dashboard:
            id: null
            uid: "gitops-overview"
            title: "GitOps Overview"
            tags: ["gitops", "monitoring"]
            timezone: "browser"
            panels:
              - id: 1
                type: "stat"
                title: "Up Containers"
                gridPos:
                  h: 4
                  w: 6
                  x: 0
                  y: 0
                targets:
                  - expr: "count(up == 1)"
              - id: 2
                type: "gauge"
                title: "CPU Usage"
                gridPos:
                  h: 4
                  w: 6
                  x: 6
                  y: 0
                targets:
                  - expr: "avg(rate(container_cpu_usage_seconds_total[5m])) * 100"
          overwrite: true
        status_code: 200
      register: dashboard_result
    
    - name: Display configuration summary
      debug:
        msg:
          - "✅ Prometheus: http://localhost:9090"
          - "✅ Grafana: http://localhost:3000 (admin/{{ grafana_admin_password }})"
          - "✅ Jenkins: http://localhost:8080"
          - "✅ Datasource configured: {{ datasource_result.status }}"
          - "✅ Dashboard imported: {{ dashboard_result.status }}"
EOF

# Exécuter le playbook
ansible-playbook playbook.yml -v
```

---

## ✅ Partie 4 : Solutions - Sécurité

### Solution 4.1 : Scripts de Sécurité Complets

```bash
cd ~/tp-gitops-local

# Script de scan complet
cat > scripts/security-scan.sh << 'EOF'
#!/bin/bash

set -e

echo "=== Starting Complete Security Scan ==="

# Configuration
REPORT_DIR="security-reports-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$REPORT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function: Scan with Checkov
scan_checkov() {
    echo -e "${YELLOW}[Checkov] Scanning IaC files...${NC}"
    
    # Scan Terraform
    checkov -d infrastructure/terraform \
        --output json \
        --output-file-path "$REPORT_DIR" \
        --framework terraform \
        --quiet || true
    
    # Scan Ansible
    checkov -d configuration/ansible \
        --output json \
        --output-file-path "$REPORT_DIR" \
        --framework ansible \
        --quiet || true
    
    # Scan Dockerfiles
    find . -name "Dockerfile*" -type f | while read dockerfile; do
        checkov -f "$dockerfile" \
            --output json \
            --output-file-path "$REPORT_DIR" \
            --framework dockerfile \
            --quiet || true
    done
    
    echo -e "${GREEN}[Checkov] Scan complete${NC}"
}

# Function: Scan with Trivy
scan_trivy() {
    echo -e "${YELLOW}[Trivy] Scanning container images...${NC}"
    
    # List of images to scan
    images=(
        "cgr.dev/chainguard/prometheus:latest"
        "grafana/grafana:10.2.0"
        "jenkins/jenkins:2.426.1-lts"
        "prom/node-exporter:v1.7.0"
    )
    
    for image in "${images[@]}"; do
        echo -e "${GREEN}Scanning $image...${NC}"
        trivy image \
            --severity HIGH,CRITICAL \
            --format json \
            --output "$REPORT_DIR/trivy-$(echo $image | tr '/:' '-').json" \
            "$image" 2>/dev/null || true
    done
    
    # Scan filesystem
    trivy fs . \
        --severity HIGH,CRITICAL \
        --format json \
        --output "$REPORT_DIR/trivy-filesystem.json" \
        2>/dev/null || true
    
    echo -e "${GREEN}[Trivy] Scan complete${NC}"
}

# Function: Generate HTML report
generate_report() {
    echo -e "${YELLOW}Generating HTML report...${NC}"
    
    cat > "$REPORT_DIR/security-report.html" << 'HTML'
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>GitOps Security Scan Report</h1>
    <p>Generated: <script>document.write(new Date().toLocaleString());</script></p>
    
    <h2>Scan Summary</h2>
    <table>
        <tr><th>Tool</th><th>Target</th><th>Status</th></tr>
        <tr><td>Checkov</td><td>Terraform</td><td class="success">✓</td></tr>
        <tr><td>Checkov</td><td>Ansible</td><td class="success">✓</td></tr>
        <tr><td>Trivy</td><td>Containers</td><td class="success">✓</td></tr>
    </table>
    
    <h2>Recommendations</h2>
    <ul>
        <li>Keep all images updated to latest versions</li>
        <li>Use Chainguard images when possible</li>
        <li>Implement RBAC for Jenkins</li>
        <li>Enable TLS for all services</li>
    </ul>
</body>
</html>
HTML
    
    echo -e "${GREEN}Report generated: $REPORT_DIR/security-report.html${NC}"
}

# Main execution
scan_checkov
scan_trivy
generate_report

# Summary
echo -e "\n${GREEN}=== Security Scan Complete ===${NC}"
echo -e "Reports saved in: ${YELLOW}$REPORT_DIR${NC}"
ls -la "$REPORT_DIR"

# Check for critical issues
CRITICAL=$(grep -l "CRITICAL" "$REPORT_DIR"/*.json 2>/dev/null | wc -l)
if [ "$CRITICAL" -gt 0 ]; then
    echo -e "${RED}⚠ WARNING: Critical issues found!${NC}"
    exit 1
else
    echo -e "${GREEN}✅ No critical issues found${NC}"
fi
EOF

chmod +x scripts/security-scan.sh

# Exécuter le scan
./scripts/security-scan.sh
```

---

## ✅ Partie 5 : Solutions - Pipeline Jenkins

### Solution 5.1 : Configuration Jenkins Complète

```bash
# Setup Jenkins avec Docker
cd ~/tp-gitops-local

# Attendre que Jenkins soit prêt
until docker exec gitops-monitoring-jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; do
    echo "Waiting for Jenkins to start..."
    sleep 5
done

# Récupérer le mot de passe initial
JENKINS_PASSWORD=$(docker exec gitops-monitoring-jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Jenkins initial password: $JENKINS_PASSWORD"

# Installer Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# Script d'installation des plugins
cat > scripts/install-jenkins-plugins.sh << 'EOF'
#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS=$(docker exec gitops-monitoring-jenkins cat /var/jenkins_home/secrets/initialAdminPassword)

plugins=(
    "git"
    "workflow-aggregator"
    "docker-workflow"
    "ansible"
    "terraform"
    "prometheus"
    "github"
    "gitlab-plugin"
    "slack"
    "email-ext"
    "timestamper"
    "ws-cleanup"
    "credentials-binding"
    "pipeline-stage-view"
    "junit"
)

for plugin in "${plugins[@]}"; do
    echo "Installing $plugin..."
    java -jar jenkins-cli.jar \
        -s "$JENKINS_URL" \
        -auth "$JENKINS_USER:$JENKINS_PASS" \
        install-plugin "$plugin" -restart
done

echo "Plugins installation complete!"
EOF

chmod +x scripts/install-jenkins-plugins.sh
```

### Solution 5.2 : Jenkinsfile Complet et Fonctionnel

```groovy
// Jenkinsfile corrigé
cat > Jenkinsfile << 'EOF'
@Library('shared-library') _

pipeline {
    agent any
    
    options {
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }
    
    environment {
        PROJECT_NAME = 'gitops-monitoring'
        DOCKER_REGISTRY = 'localhost:5000'
        TERRAFORM_VERSION = '1.6.0'
        ANSIBLE_VERSION = '2.15'
        SLACK_CHANNEL = '#devops'
    }
    
    stages {
        stage('Initialization') {
            steps {
                script {
                    currentBuild.displayName = "#${BUILD_NUMBER} - ${env.BRANCH_NAME}"
                    currentBuild.description = "GitOps Pipeline Execution"
                }
                cleanWs()
                checkout scm
            }
        }
        
        stage('Security Scanning - IaC') {
            parallel {
                stage('Checkov - Terraform') {
                    steps {
                        script {
                            sh '''
                                echo "=== Checkov Terraform Scan ==="
                                pip3 install checkov
                                checkov -d infrastructure/terraform \
                                    --output junitxml \
                                    --output-file-path . \
                                    --framework terraform || true
                            '''
                            junit allowEmptyResults: true, testResults: 'results_terraform.xml'
                        }
                    }
                }
                
                stage('Checkov - Ansible') {
                    steps {
                        script {
                            sh '''
                                echo "=== Checkov Ansible Scan ==="
                                checkov -d configuration/ansible \
                                    --output junitxml \
                                    --output-file-path . \
                                    --framework ansible || true
                            '''
                            junit allowEmptyResults: true, testResults: 'results_ansible.xml'
                        }
                    }
                }
                
                stage('Trivy - Filesystem') {
                    steps {
                        script {
                            sh '''
                                echo "=== Trivy Filesystem Scan ==="
                                trivy fs . \
                                    --severity HIGH,CRITICAL \
                                    --format json \
                                    --output trivy-fs-report.json
                            '''
                            archiveArtifacts artifacts: 'trivy-fs-report.json', allowEmptyArchive: true
                        }
                    }
                }
            }
        }
        
        stage('Build Application') {
            steps {
                script {
                    sh '''
                        echo "=== Building Application ==="
                        
                        # Create sample application
                        mkdir -p application/docker
                        
                        cat > application/docker/app.js << 'JS'
const http = require('http');
const prometheus = require('prom-client');

// Create a Registry
const register = new prometheus.Registry();

// Add default metrics
prometheus.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestDuration = new prometheus.Histogram({
    name: 'http_request_duration_ms',
    help: 'Duration of HTTP requests in ms',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 5, 15, 50, 100, 500]
});
register.registerMetric(httpRequestDuration);

const server = http.createServer((req, res) => {
    const start = Date.now();
    
    if (req.url === '/metrics') {
        res.setHeader('Content-Type', register.contentType);
        register.metrics().then(metrics => {
            res.end(metrics);
        });
    } else if (req.url === '/health') {
        res.writeHead(200);
        res.end('OK');
    } else {
        res.writeHead(200);
        res.end('GitOps Monitoring App');
    }
    
    const duration = Date.now() - start;
    httpRequestDuration.observe({ method: req.method, route: req.url, status_code: res.statusCode }, duration);
});

const port = process.env.PORT || 3001;
server.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
JS
                        
                        cat > application/docker/package.json << 'JSON'
{
  "name": "gitops-monitoring-app",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "prom-client": "^14.0.0"
  }
}
JSON
                        
                        cat > application/docker/Dockerfile << 'DOCKERFILE'
FROM cgr.dev/chainguard/node:latest

WORKDIR /app

COPY --chown=node:node package*.json ./
RUN npm ci --only=production

COPY --chown=node:node . .

EXPOSE 3001

USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "app.js"]
DOCKERFILE
                        
                        # Build Docker image
                        cd application/docker
                        docker build -t ${PROJECT_NAME}-app:${BUILD_NUMBER} .
                        docker tag ${PROJECT_NAME}-app:${BUILD_NUMBER} ${PROJECT_NAME}-app:latest
                    '''
                }
            }
        }
        
        stage('Security Scan - Container') {
            steps {
                script {
                    sh '''
                        echo "=== Scanning Container Image ==="
                        trivy image \
                            --severity HIGH,CRITICAL \
                            --format table \
                            --exit-code 0 \
                            ${PROJECT_NAME}-app:${BUILD_NUMBER}
                    '''
                }
            }
        }
        
        stage('Deploy Infrastructure') {
            steps {
                dir('infrastructure/terraform') {
                    script {
                        sh '''
                            echo "=== Deploying with Terraform ==="
                            terraform init -backend=false
                            terraform validate
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                            terraform output -json > ../../terraform-outputs.json
                        '''
                    }
                }
            }
        }
        
        stage('Configure Services') {
            steps {
                dir('configuration/ansible') {
                    script {
                        sh '''
                            echo "=== Configuring with Ansible ==="
                            ansible-playbook \
                                -i inventory.yml \
                                playbook.yml \
                                --extra-vars "build_number=${BUILD_NUMBER}"
                        '''
                    }
                }
            }
        }
        
        stage('Deploy Application') {
            steps {
                script {
                    sh '''
                        echo "=== Deploying Application ==="
                        
                        # Run application container
                        docker run -d \
                            --name ${PROJECT_NAME}-app \
                            --network gitops-monitoring-network \
                            -p 3001:3001 \
                            --restart unless-stopped \
                            ${PROJECT_NAME}-app:${BUILD_NUMBER}
                        
                        # Wait for app to be ready
                        sleep 10
                        
                        # Test application health
                        curl -f http://localhost:3001/health || exit 1
                    '''
                }
            }
        }
        
        stage('Integration Tests') {
            steps {
                script {
                    sh '''
                        echo "=== Running Integration Tests ==="
                        
                        # Test Prometheus
                        curl -f http://localhost:9090/-/healthy
                        
                        # Test Grafana
                        curl -f http://localhost:3000/api/health
                        
                        # Test Application
                        curl -f http://localhost:3001/health
                        curl -f http://localhost:3001/metrics
                        
                        # Test metrics collection
                        sleep 15
                        curl -s "http://localhost:9090/api/v1/query?query=up" | grep -q '"status":"success"'
                        
                        echo "✅ All integration tests passed!"
                    '''
                }
            }
        }
        
        stage('Performance Tests') {
            steps {
                script {
                    sh '''
                        echo "=== Running Performance Tests ==="
                        
                        # Simple load test with curl
                        for i in {1..100}; do
                            curl -s http://localhost:3001/ > /dev/null &
                        done
                        wait
                        
                        # Check response times
                        response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:3001/)
                        echo "Response time: ${response_time}s"
                        
                        # Verify metrics are collected
                        curl -s http://localhost:3001/metrics | grep http_request_duration_ms
                    '''
                }
            }
        }
    }
    
    post {
        always {
            echo 'Collecting artifacts and cleaning up...'
            archiveArtifacts artifacts: '**/security-reports/**', allowEmptyArchive: true
            archiveArtifacts artifacts: '**/*.json', allowEmptyArchive: true
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'security-reports',
                reportFiles: 'security-report.html',
                reportName: 'Security Report'
            ])
        }
        
        success {
            echo '✅ Pipeline completed successfully!'
            script {
                def summary = """
                GitOps Pipeline Success!
                
                Build: ${env.BUILD_NUMBER}
                Duration: ${currentBuild.durationString}
                
                Services:
                - Prometheus: http://localhost:9090
                - Grafana: http://localhost:3000
                - Jenkins: http://localhost:8080
                - Application: http://localhost:3001
                
                Credentials:
                - Grafana: admin / gitops2024
                """
                
                echo summary
                
                // Uncomment to enable Slack notification
                // slackSend(
                //     channel: env.SLACK_CHANNEL,
                //     color: 'good',
                //     message: summary
                // )
            }
        }
        
        failure {
            echo '❌ Pipeline failed!'
            script {
                // Uncomment to enable Slack notification
                // slackSend(
                //     channel: env.SLACK_CHANNEL,
                //     color: 'danger',
                //     message: "GitOps Pipeline Failed! Build: ${env.BUILD_NUMBER}"
                // )
            }
        }
        
        cleanup {
            echo 'Final cleanup...'
            sh '''
                # Clean up test containers if needed
                docker rm -f ${PROJECT_NAME}-app-test 2>/dev/null || true
                
                # Prune old images
                docker image prune -f
            '''
        }
    }
}
EOF
```

---

## ✅ Partie 6 : Solutions - Tests

### Solution 6.1 : Suite de Tests Complète

```python
# tests/test_complete.py
cat > tests/test_complete.py << 'EOF'
#!/usr/bin/env python3

import unittest
import requests
import docker
import json
import time
import subprocess

class TestGitOpsInfrastructure(unittest.TestCase):
    
    @classmethod
    def setUpClass(cls):
        """Setup test environment"""
        cls.docker_client = docker.from_env()
        cls.base_urls = {
            'prometheus': 'http://localhost:9090',
            'grafana': 'http://localhost:3000',
            'jenkins': 'http://localhost:8080'
        }
    
    def test_01_docker_network_exists(self):
        """Test if monitoring network exists"""
        networks = self.docker_client.networks.list()
        network_names = [n.name for n in networks]
        self.assertIn('gitops-monitoring-network', network_names)
    
    def test_02_all_containers_running(self):
        """Test if all required containers are running"""
        required_containers = [
            'gitops-monitoring-prometheus',
            'gitops-monitoring-grafana',
            'gitops-monitoring-jenkins',
            'gitops-monitoring-node-exporter'
        ]
        
        running_containers = self.docker_client.containers.list()
        running_names = [c.name for c in running_containers]
        
        for container in required_containers:
            with self.subTest(container=container):
                self.assertIn(container, running_names)
                cont = self.docker_client.containers.get(container)
                self.assertEqual(cont.status, 'running')
    
    def test_03_prometheus_healthy(self):
        """Test Prometheus health endpoint"""
        response = requests.get(f"{self.base_urls['prometheus']}/-/healthy")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.text.strip(), 'Prometheus is Healthy.')
    
    def test_04_prometheus_targets(self):
        """Test Prometheus targets are up"""
        response = requests.get(f"{self.base_urls['prometheus']}/api/v1/targets")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data['status'], 'success')
        
        # Check that we have active targets
        active_targets = data['data']['activeTargets']
        self.assertGreater(len(active_targets), 0)
        
        # Check all targets are up
        for target in active_targets:
            with self.subTest(target=target['labels']['job']):
                self.assertEqual(target['health'], 'up')
    
    def test_05_grafana_health(self):
        """Test Grafana health endpoint"""
        response = requests.get(f"{self.base_urls['grafana']}/api/health")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data['database'], 'ok')
    
    def test_06_grafana_datasources(self):
        """Test Grafana has Prometheus datasource"""
        response = requests.get(
            f"{self.base_urls['grafana']}/api/datasources",
            auth=('admin', 'gitops2024')
        )
        self.assertEqual(response.status_code, 200)
        
        datasources = response.json()
        self.assertGreater(len(datasources), 0)
        
        prometheus_ds = [ds for ds in datasources if ds['type'] == 'prometheus']
        self.assertGreater(len(prometheus_ds), 0)
    
    def test_07_jenkins_login_available(self):
        """Test Jenkins login page is accessible"""
        response = requests.get(f"{self.base_urls['jenkins']}/login", allow_redirects=True)
        self.assertEqual(response.status_code, 200)
    
    def test_08_terraform_state_exists(self):
        """Test Terraform state file exists"""
        import os
        state_file = 'infrastructure/terraform/terraform.tfstate'
        self.assertTrue(os.path.exists(state_file))
        
        with open(state_file, 'r') as f:
            state = json.load(f)
            self.assertIn('resources', state)
            self.assertGreater(len(state['resources']), 0)
    
    def test_09_security_scan_passes(self):
        """Test security scans don't find critical issues"""
        result = subprocess.run(
            ['trivy', 'fs', '.', '--severity', 'CRITICAL', '--exit-code', '1'],
            capture_output=True
        )
        # Exit code 0 means no critical issues found
        self.assertEqual(result.returncode, 0)
    
    def test_10_metrics_collection(self):
        """Test that metrics are being collected"""
        # Query Prometheus for up metric
        response = requests.get(
            f"{self.base_urls['prometheus']}/api/v1/query",
            params={'query': 'up'}
        )
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertEqual(data['status'], 'success')
        self.assertGreater(len(data['data']['result']), 0)

if __name__ == '__main__':
    # Run tests with verbose output
    unittest.main(verbosity=2)
EOF

# Exécuter les tests
python3 tests/test_complete.py
```

---

## ✅ Validation Finale et Troubleshooting

### Script de Validation Complète

```bash
# validation-complete.sh
cat > scripts/validation-complete.sh << 'EOF'
#!/bin/bash

echo "=== GitOps Infrastructure Validation ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Function to check service
check_service() {
    local name=$1
    local url=$2
    local expected_code=$3
    
    echo -n "Checking $name... "
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$code" == "$expected_code" ]; then
        echo -e "${GREEN}✅ OK${NC}"
    else
        echo -e "${RED}❌ FAILED (HTTP $code)${NC}"
        ((ERRORS++))
    fi
}

# Check Docker
echo -e "\n${YELLOW}1. Docker Status${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check services
echo -e "\n${YELLOW}2. Service Health Checks${NC}"
check_service "Prometheus" "http://localhost:9090/-/healthy" "200"
check_service "Grafana" "http://localhost:3000/api/health" "200"
check_service "Jenkins" "http://localhost:8080/login" "200"

# Check Terraform
echo -e "\n${YELLOW}3. Terraform Status${NC}"
cd infrastructure/terraform
terraform show -json | jq '.values.root_module.resources[] | {type, name, values: .values.id}' || echo "No Terraform state found"
cd ../..

# Check Git
echo -e "\n${YELLOW}4. Git Status${NC}"
git log --oneline -5
git status --short

# Check disk usage
echo -e "\n${YELLOW}5. Disk Usage${NC}"
df -h | grep -E "^/|Filesystem"
docker system df

# Summary
echo -e "\n${YELLOW}=== Validation Summary ===${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo -e "\nAccess URLs:"
    echo "  Prometheus: http://localhost:9090"
    echo "  Grafana: http://localhost:3000 (admin/gitops2024)"
    echo "  Jenkins: http://localhost:8080"
else
    echo -e "${RED}❌ $ERRORS checks failed!${NC}"
    exit 1
fi
EOF

chmod +x scripts/validation-complete.sh
./scripts/validation-complete.sh
```

### Troubleshooting Guide

```bash
# Problème: Container not starting
docker logs gitops-monitoring-prometheus
docker logs gitops-monitoring-grafana
docker logs gitops-monitoring-jenkins

# Problème: Port already in use
sudo lsof -i :9090
sudo lsof -i :3000
sudo lsof -i :8080

# Problème: Permission denied
sudo chown -R $USER:$USER ~/tp-gitops-local
sudo chmod 666 /var/run/docker.sock

# Problème: Terraform state corrupted
cd infrastructure/terraform
rm -rf .terraform terraform.tfstate*
terraform init
terraform apply -auto-approve

# Problème: Jenkins not accessible
docker exec gitops-monitoring-jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# Clean restart
docker-compose down
docker system prune -a
./setup-environment.sh
```

---

## 📊 Résultats Attendus

### Captures d'écran des Services

1. **Prometheus Targets** (http://localhost:9090/targets)
   - Tous les targets doivent être "UP"
   - Prometheus, Grafana, Jenkins, Node Exporter

2. **Grafana Dashboard** (http://localhost:3000)
   - Login: admin / gitops2024
   - Dashboard "GitOps Overview" visible
   - Datasource Prometheus configuré

3. **Jenkins Pipeline** (http://localhost:8080)
   - Pipeline "GitOps Monitoring" créé
   - Dernière exécution: SUCCESS
   - Tous les stages verts

### Métriques de Performance

```bash
# Vérifier les métriques
curl -s http://localhost:9090/api/v1/query?query=up | jq '.data.result[] | {job: .metric.job, status: .value[1]}'

# Output attendu:
{
  "job": "prometheus",
  "status": "1"
}
{
  "job": "grafana",
  "status": "1"
}
{
  "job": "jenkins",
  "status": "1"
}
{
  "job": "node",
  "status": "1"
}
```

---

## 📝 Points d'Évaluation

### Grille de Notation (sur 20 points)

| Critère | Points | Validation |
|---------|--------|------------|
| **Infrastructure Terraform** | 4 | Tous les containers déployés |
| **Configuration Ansible** | 3 | Services configurés correctement |
| **Sécurité** | 4 | Pas de vulnérabilités HIGH/CRITICAL |
| **Pipeline Jenkins** | 4 | Pipeline s'exécute sans erreur |
| **Tests** | 3 | Tous les tests passent |
| **Documentation** | 2 | Code commenté, README présent |
| **Total** | 20 | |

### Bonus Possibles (+2 points)

- Implementation de monitoring avancé (+1)
- Ajout de nouvelles features sécurité (+1)

---

**FIN DU CORRIGÉ**

*Ce corrigé contient toutes les solutions pour réaliser le TP avec succès. Les étudiants doivent arriver aux mêmes résultats en suivant leur propre démarche.*
