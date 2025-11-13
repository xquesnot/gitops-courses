# TP DevOps : Implémentation d'une Pipeline GitOps Locale Sécurisée

**Durée estimée : 4-6 heures**  
**Niveau : Master / Ingénieur**  
**Date : 2024-2025**

---

## 📚 Introduction et Contexte

### Objectifs pédagogiques
À l'issue de ce TP, vous serez capable de :
- ✅ Implémenter une pipeline GitOps locale complète
- ✅ Automatiser le déploiement d'infrastructure avec Terraform
- ✅ Configurer des services avec Ansible
- ✅ Mettre en place une chaîne CI/CD sécurisée avec Jenkins
- ✅ Intégrer des tests de sécurité (Checkov, Trivy)
- ✅ Déployer un stack de monitoring (Prometheus/Grafana)
- ✅ Utiliser des images sécurisées Chainguard

### Cas d'usage réel
**Scenario :** Vous êtes DevOps Engineer chez "TechMonitor Corp", une startup spécialisée dans les solutions de monitoring. Votre mission est de mettre en place une infrastructure GitOps locale pour déployer automatiquement une application de monitoring basée sur Prometheus et Grafana, tout en garantissant la sécurité à chaque étape.

---

## 🔧 Architecture Technique

### Vue d'ensemble
```
┌─────────────────────────────────────────────────────────┐
│                     Git Repository                       │
│  (GitHub: exemple-app + Infrastructure as Code)         │
└────────────┬────────────────────────────────────────────┘
             │ Push/Webhook
             ▼
┌─────────────────────────────────────────────────────────┐
│                      Jenkins                             │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Pipeline Stages:                                  │  │
│  │ 1. Checkout Code                                  │  │
│  │ 2. Security Scan IaC (Checkov)                    │  │
│  │ 3. Build Container                                │  │
│  │ 4. Security Scan Container (Trivy)               │  │
│  │ 5. Deploy Infrastructure (Terraform)              │  │
│  │ 6. Configure Services (Ansible)                   │  │
│  │ 7. Deploy Application                             │  │
│  │ 8. Run Tests                                      │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────┐
│              Docker Infrastructure                       │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐            │
│  │Prometheus │ │  Grafana  │ │   App     │            │
│  │           │ │           │ │ Container │            │
│  └───────────┘ └───────────┘ └───────────┘            │
└─────────────────────────────────────────────────────────┘
```

### Stack Technologique

| Composant | Version | Rôle | Source |
|-----------|---------|------|---------|
| **Docker** | 24.0+ | Container Runtime | [docker.com](https://docker.com) |
| **Chainguard Images** | Latest | Images sécurisées | [chainguard.dev](https://chainguard.dev) |
| **Jenkins** | 2.426+ | CI/CD Orchestration | [jenkins.io](https://jenkins.io) |
| **Terraform** | 1.6+ | Infrastructure as Code | [terraform.io](https://terraform.io) |
| **Ansible** | 2.15+ | Configuration Management | [ansible.com](https://ansible.com) |
| **Prometheus** | 2.47+ | Metrics Collection | [prometheus.io](https://prometheus.io) |
| **Grafana** | 10.2+ | Visualization | [grafana.com](https://grafana.com) |
| **Checkov** | 3.0+ | IaC Security | [checkov.io](https://checkov.io) |
| **Trivy** | 0.48+ | Container Security | [aquasecurity.github.io/trivy](https://aquasecurity.github.io/trivy) |

---

## 📋 Prérequis

### Environnement de travail
- **OS :** Linux (Ubuntu 22.04 LTS recommandé) ou macOS
- **RAM :** Minimum 8 GB (16 GB recommandé)
- **Stockage :** 20 GB disponibles
- **CPU :** 4 cores minimum

### Logiciels à installer
```bash
# Vérifier les installations
docker --version          # Docker version 24.0+
terraform --version        # Terraform v1.6+
ansible --version         # Ansible 2.15+
git --version            # Git 2.40+
python3 --version        # Python 3.10+
```

---

## 🚀 Partie 1 : Préparation de l'Environnement

### Étape 1.1 : Structure du Projet

Créez la structure de répertoires suivante :

```bash
mkdir -p ~/tp-gitops-local/{
  infrastructure/terraform,
  configuration/ansible,
  application/docker,
  monitoring/{prometheus,grafana},
  security/policies,
  scripts,
  tests
}

cd ~/tp-gitops-local
```

### Étape 1.2 : Installation des Outils de Sécurité

```bash
# Installation de Checkov
pip3 install checkov

# Installation de Trivy
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
sudo apt-get update && sudo apt-get install trivy

# Vérification
checkov --version
trivy --version
```

### Étape 1.3 : Configuration Git

```bash
# Initialiser le repository local
git init

# Configuration GitOps
cat > .gitignore << 'EOF'
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.retry
.vault_pass
secrets/
*.log
.env
EOF

git add .gitignore
git commit -m "Initial commit: GitOps structure"
```

---

## 🏗️ Partie 2 : Infrastructure as Code avec Terraform

### Étape 2.1 : Configuration Terraform

Créez le fichier `infrastructure/terraform/main.tf` :

```hcl
# Provider Docker
terraform {
  required_version = ">= 1.6"
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Network
resource "docker_network" "monitoring" {
  name   = "monitoring-network"
  driver = "bridge"
  
  ipam_config {
    subnet  = "172.20.0.0/16"
    gateway = "172.20.0.1"
  }
}

# Volume pour Prometheus
resource "docker_volume" "prometheus_data" {
  name = "prometheus-data"
}

# Volume pour Grafana
resource "docker_volume" "grafana_data" {
  name = "grafana-data"
}

# Container Prometheus (Chainguard)
resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = "cgr.dev/chainguard/prometheus:latest"
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  ports {
    internal = 9090
    external = 9090
  }
  
  volumes {
    volume_name    = docker_volume.prometheus_data.name
    container_path = "/prometheus"
  }
  
  volumes {
    host_path      = "${path.cwd}/../../monitoring/prometheus/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
  
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--web.console.libraries=/usr/share/prometheus/console_libraries",
    "--web.console.templates=/usr/share/prometheus/consoles"
  ]
  
  restart = "unless-stopped"
  
  labels {
    label = "monitoring"
    value = "prometheus"
  }
}

# Container Grafana
resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana:latest"
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  ports {
    internal = 3000
    external = 3000
  }
  
  volumes {
    volume_name    = docker_volume.grafana_data.name
    container_path = "/var/lib/grafana"
  }
  
  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=gitops2024",
    "GF_INSTALL_PLUGINS=grafana-piechart-panel"
  ]
  
  restart = "unless-stopped"
  
  labels {
    label = "monitoring"
    value = "grafana"
  }
  
  depends_on = [docker_container.prometheus]
}

# Container Jenkins
resource "docker_container" "jenkins" {
  name  = "jenkins"
  image = "jenkins/jenkins:lts"
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  ports {
    internal = 8080
    external = 8080
  }
  
  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  volumes {
    host_path      = "${path.cwd}/../../jenkins_home"
    container_path = "/var/jenkins_home"
  }
  
  restart = "unless-stopped"
  
  labels {
    label = "ci"
    value = "jenkins"
  }
}

# Outputs
output "network_id" {
  value = docker_network.monitoring.id
}

output "prometheus_url" {
  value = "http://localhost:9090"
}

output "grafana_url" {
  value = "http://localhost:3000"
}

output "jenkins_url" {
  value = "http://localhost:8080"
}
```

### Étape 2.2 : Variables Terraform

Créez `infrastructure/terraform/variables.tf` :

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "development"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "gitops-monitoring"
}

variable "monitoring_retention" {
  description = "Prometheus data retention"
  type        = string
  default     = "15d"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "gitops2024"
}
```

---

## 🔧 Partie 3 : Configuration avec Ansible

### Étape 3.1 : Inventaire Ansible

Créez `configuration/ansible/inventory.yml` :

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
  children:
    monitoring:
      hosts:
        prometheus:
          container_name: prometheus
          container_port: 9090
        grafana:
          container_name: grafana
          container_port: 3000
    ci:
      hosts:
        jenkins:
          container_name: jenkins
          container_port: 8080
```

### Étape 3.2 : Playbook Principal

Créez `configuration/ansible/playbook.yml` :

```yaml
---
- name: Configure Monitoring Stack
  hosts: localhost
  become: yes
  vars:
    prometheus_version: "latest"
    grafana_version: "latest"
    
  tasks:
    - name: Ensure monitoring directories exist
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - /tmp/monitoring/prometheus
        - /tmp/monitoring/grafana
        - /tmp/monitoring/alertmanager
    
    - name: Generate Prometheus configuration
      template:
        src: prometheus.yml.j2
        dest: "{{ playbook_dir }}/../../monitoring/prometheus/prometheus.yml"
        mode: '0644'
    
    - name: Generate Grafana datasources
      template:
        src: datasources.yml.j2
        dest: "{{ playbook_dir }}/../../monitoring/grafana/datasources.yml"
        mode: '0644'
    
    - name: Check Docker containers health
      docker_container_info:
        name: "{{ item }}"
      register: container_info
      loop:
        - prometheus
        - grafana
        - jenkins
    
    - name: Display container status
      debug:
        msg: "Container {{ item.item }} is {{ item.container.State.Status }}"
      loop: "{{ container_info.results }}"
      when: item.container is defined
    
    - name: Configure Prometheus scrape configs
      blockinfile:
        path: "{{ playbook_dir }}/../../monitoring/prometheus/prometheus.yml"
        block: |
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
            
            - job_name: 'docker'
              static_configs:
                - targets: ['172.20.0.1:9323']
        marker: "# {mark} ANSIBLE MANAGED BLOCK"
    
    - name: Setup Grafana dashboards
      uri:
        url: "http://localhost:3000/api/dashboards/db"
        method: POST
        user: admin
        password: gitops2024
        force_basic_auth: yes
        body_format: json
        body:
          dashboard:
            title: "GitOps Monitoring"
            panels:
              - title: "Container CPU Usage"
                type: "graph"
                targets:
                  - expr: "rate(container_cpu_usage_seconds_total[5m])"
              - title: "Container Memory Usage"
                type: "graph"
                targets:
                  - expr: "container_memory_usage_bytes"
          overwrite: true
      ignore_errors: yes
```

### Étape 3.3 : Templates Ansible

Créez `configuration/ansible/templates/prometheus.yml.j2` :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - /etc/prometheus/rules/*.yml

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
```

---

## 🔒 Partie 4 : Sécurité avec Checkov et Trivy

### Étape 4.1 : Politique Checkov

Créez `security/policies/checkov-policy.yaml` :

```yaml
metadata:
  name: "GitOps Security Policy"
  guidelines: "https://docs.bridgecrew.io/docs"
  
checks:
  - CKV_DOCKER_1: "Ensure port 22 is not exposed"
  - CKV_DOCKER_2: "Ensure HEALTHCHECK instructions are added"
  - CKV_DOCKER_3: "Ensure USER instruction is used"
  - CKV_DOCKER_4: "Ensure COPY is used instead of ADD"
  - CKV_DOCKER_5: "Ensure MAINTAINER is not used"
  - CKV_DOCKER_6: "Ensure LABEL is used for metadata"
  - CKV_DOCKER_7: "Ensure no secrets in ENV"
  - CKV_DOCKER_8: "Ensure non-root user"

terraform:
  - CKV_TF_1: "Ensure Terraform module sources use versions"
  - CKV_TF_2: "Ensure Terraform outputs don't expose secrets"

ansible:
  - CKV_ANSIBLE_1: "Ensure no_log is set for sensitive tasks"
  - CKV_ANSIBLE_2: "Ensure become is used appropriately"
```

### Étape 4.2 : Script de Scan de Sécurité

Créez `scripts/security-scan.sh` :

```bash
#!/bin/bash

set -e

echo "=== Starting Security Scan Pipeline ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Scan Terraform files with Checkov
echo -e "${YELLOW}[1/4] Scanning Terraform files with Checkov...${NC}"
checkov -d infrastructure/terraform \
  --output json \
  --quiet \
  --compact \
  > security-report-terraform.json || true

# Scan Ansible files with Checkov
echo -e "${YELLOW}[2/4] Scanning Ansible files with Checkov...${NC}"
checkov -d configuration/ansible \
  --framework ansible \
  --output json \
  --quiet \
  > security-report-ansible.json || true

# Scan Dockerfiles with Checkov
echo -e "${YELLOW}[3/4] Scanning Dockerfiles with Checkov...${NC}"
find . -name "Dockerfile*" -exec checkov -f {} \; \
  --output json \
  > security-report-docker.json || true

# Scan container images with Trivy
echo -e "${YELLOW}[4/4] Scanning container images with Trivy...${NC}"
for image in "cgr.dev/chainguard/prometheus:latest" "grafana/grafana:latest" "jenkins/jenkins:lts"; do
  echo -e "${GREEN}Scanning $image...${NC}"
  trivy image \
    --severity HIGH,CRITICAL \
    --format json \
    --output "trivy-$(echo $image | tr '/:' '-').json" \
    "$image" || true
done

# Generate summary report
echo -e "${GREEN}=== Security Scan Summary ===${NC}"
echo "Reports generated:"
ls -la *security-report*.json trivy-*.json 2>/dev/null || echo "No security issues found!"

# Check for critical issues
CRITICAL_COUNT=$(grep -c "CRITICAL" trivy-*.json 2>/dev/null || echo "0")
if [ "$CRITICAL_COUNT" -gt "0" ]; then
  echo -e "${RED}WARNING: $CRITICAL_COUNT critical vulnerabilities found!${NC}"
  exit 1
else
  echo -e "${GREEN}No critical vulnerabilities found.${NC}"
fi
```

---

## 🔄 Partie 5 : Pipeline Jenkins GitOps

### Étape 5.1 : Jenkinsfile

Créez `Jenkinsfile` à la racine du projet :

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'localhost:5000'
        APP_NAME = 'monitoring-app'
        TERRAFORM_VERSION = '1.6.0'
        ANSIBLE_VERSION = '2.15'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log --oneline -5'
            }
        }
        
        stage('Security Scan - IaC') {
            parallel {
                stage('Checkov Terraform') {
                    steps {
                        sh '''
                            echo "Scanning Terraform with Checkov..."
                            checkov -d infrastructure/terraform \
                                --framework terraform \
                                --output junitxml \
                                --output-file-path . \
                                || true
                        '''
                        junit 'results_terraform.xml'
                    }
                }
                
                stage('Checkov Ansible') {
                    steps {
                        sh '''
                            echo "Scanning Ansible with Checkov..."
                            checkov -d configuration/ansible \
                                --framework ansible \
                                --output junitxml \
                                --output-file-path . \
                                || true
                        '''
                        junit 'results_ansible.xml'
                    }
                }
            }
        }
        
        stage('Build Application Container') {
            steps {
                script {
                    sh '''
                        echo "Building application container..."
                        cat > application/docker/Dockerfile << 'EOF'
FROM cgr.dev/chainguard/node:latest
WORKDIR /app
USER node
COPY --chown=node:node package*.json ./
RUN npm ci --only=production
COPY --chown=node:node . .
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js
CMD ["node", "server.js"]
EOF
                    '''
                }
            }
        }
        
        stage('Security Scan - Container') {
            steps {
                sh '''
                    echo "Scanning container with Trivy..."
                    trivy fs --severity HIGH,CRITICAL \
                        --format table \
                        --exit-code 0 \
                        application/docker/
                '''
            }
        }
        
        stage('Deploy Infrastructure') {
            steps {
                dir('infrastructure/terraform') {
                    sh '''
                        terraform init
                        terraform validate
                        terraform plan -out=tfplan
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }
        
        stage('Configure Services') {
            steps {
                dir('configuration/ansible') {
                    sh '''
                        ansible-playbook -i inventory.yml playbook.yml \
                            --extra-vars "environment=development"
                    '''
                }
            }
        }
        
        stage('Health Check') {
            steps {
                sh '''
                    echo "Checking services health..."
                    sleep 10
                    
                    # Check Prometheus
                    curl -f http://localhost:9090/-/healthy || exit 1
                    
                    # Check Grafana
                    curl -f http://localhost:3000/api/health || exit 1
                    
                    # Check Jenkins
                    curl -f http://localhost:8080/login || exit 1
                    
                    echo "All services are healthy!"
                '''
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh '''
                    echo "Running integration tests..."
                    
                    # Test Prometheus metrics
                    curl -s http://localhost:9090/api/v1/query?query=up | grep -q "success"
                    
                    # Test Grafana API
                    curl -s -u admin:gitops2024 http://localhost:3000/api/datasources | grep -q "prometheus"
                    
                    echo "Integration tests passed!"
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up workspace...'
            sh 'docker system prune -f || true'
        }
        success {
            echo 'Pipeline executed successfully!'
            emailext (
                subject: "GitOps Pipeline Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The GitOps pipeline has completed successfully.\n\nPrometheus: http://localhost:9090\nGrafana: http://localhost:3000",
                to: 'devops@techmonitor.corp'
            )
        }
        failure {
            echo 'Pipeline failed!'
            emailext (
                subject: "GitOps Pipeline Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "The GitOps pipeline has failed. Please check the logs.",
                to: 'devops@techmonitor.corp'
            )
        }
    }
}
```

### Étape 5.2 : Configuration Jenkins Job

Créez `scripts/setup-jenkins.sh` :

```bash
#!/bin/bash

echo "Setting up Jenkins for GitOps..."

# Wait for Jenkins to start
until curl -s http://localhost:8080/login > /dev/null; do
    echo "Waiting for Jenkins..."
    sleep 5
done

# Get initial admin password
JENKINS_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Jenkins initial password: $JENKINS_PASS"

# Create Jenkins CLI configuration
cat > jenkins-cli.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>GitOps Monitoring Pipeline</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <hudson.triggers.SCMTrigger>
          <spec>H/5 * * * *</spec>
        </hudson.triggers.SCMTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
    <scm class="hudson.plugins.git.GitSCM">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>file:///workspace/tp-gitops-local</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
  </definition>
</flow-definition>
EOF

echo "Jenkins setup complete!"
```

---

## 🧪 Partie 6 : Tests et Validation

### Étape 6.1 : Tests d'Infrastructure

Créez `tests/test_infrastructure.py` :

```python
#!/usr/bin/env python3

import requests
import docker
import json
import sys

def test_containers_running():
    """Test if all required containers are running"""
    client = docker.from_env()
    required_containers = ['prometheus', 'grafana', 'jenkins']
    
    for container_name in required_containers:
        try:
            container = client.containers.get(container_name)
            assert container.status == 'running', f"{container_name} is not running"
            print(f"✅ {container_name} is running")
        except docker.errors.NotFound:
            print(f"❌ {container_name} not found")
            return False
    return True

def test_services_health():
    """Test if services are responding"""
    services = {
        'Prometheus': 'http://localhost:9090/-/healthy',
        'Grafana': 'http://localhost:3000/api/health',
        'Jenkins': 'http://localhost:8080/login'
    }
    
    for service, url in services.items():
        try:
            response = requests.get(url, timeout=5)
            if response.status_code in [200, 401]:  # 401 for auth required
                print(f"✅ {service} is healthy")
            else:
                print(f"❌ {service} returned status {response.status_code}")
                return False
        except requests.exceptions.RequestException as e:
            print(f"❌ {service} is not responding: {e}")
            return False
    return True

def test_prometheus_metrics():
    """Test if Prometheus is collecting metrics"""
    try:
        response = requests.get('http://localhost:9090/api/v1/query?query=up')
        data = response.json()
        
        if data['status'] == 'success' and len(data['data']['result']) > 0:
            print(f"✅ Prometheus is collecting metrics")
            return True
        else:
            print(f"❌ Prometheus is not collecting metrics")
            return False
    except Exception as e:
        print(f"❌ Failed to query Prometheus: {e}")
        return False

def test_grafana_datasources():
    """Test if Grafana has Prometheus datasource configured"""
    try:
        response = requests.get(
            'http://localhost:3000/api/datasources',
            auth=('admin', 'gitops2024')
        )
        datasources = response.json()
        
        prometheus_configured = any(ds['type'] == 'prometheus' for ds in datasources)
        if prometheus_configured:
            print(f"✅ Grafana has Prometheus datasource")
            return True
        else:
            print(f"❌ Grafana missing Prometheus datasource")
            return False
    except Exception as e:
        print(f"❌ Failed to check Grafana datasources: {e}")
        return False

def main():
    """Run all tests"""
    print("🧪 Running Infrastructure Tests...\n")
    
    tests = [
        test_containers_running,
        test_services_health,
        test_prometheus_metrics,
        test_grafana_datasources
    ]
    
    results = []
    for test in tests:
        print(f"\nRunning {test.__name__}...")
        results.append(test())
    
    print("\n" + "="*50)
    if all(results):
        print("✅ All tests passed!")
        return 0
    else:
        print("❌ Some tests failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())
```

### Étape 6.2 : Script de Validation GitOps

Créez `scripts/validate-gitops.sh` :

```bash
#!/bin/bash

echo "=== GitOps Validation ==="

# Check Git status
echo "1. Checking Git status..."
if [ -z "$(git status --porcelain)" ]; then
    echo "✅ Working directory clean"
else
    echo "⚠️  Uncommitted changes detected"
    git status --short
fi

# Validate Terraform
echo "2. Validating Terraform..."
cd infrastructure/terraform
terraform fmt -check
terraform validate
cd ../..

# Validate Ansible
echo "3. Validating Ansible..."
ansible-playbook configuration/ansible/playbook.yml --syntax-check

# Check Docker resources
echo "4. Checking Docker resources..."
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker network ls | grep monitoring
docker volume ls | grep -E "prometheus|grafana"

echo "=== Validation Complete ==="
```

---

## 🎯 Partie 7 : Exercices Pratiques

### Exercice 1 : Ajouter un Service
**Objectif :** Ajouter Node Exporter au stack de monitoring

1. Modifier `infrastructure/terraform/main.tf` pour ajouter Node Exporter
2. Mettre à jour `configuration/ansible/playbook.yml` 
3. Ajouter la configuration Prometheus pour scraper Node Exporter
4. Valider avec les tests de sécurité

### Exercice 2 : Implémenter des Alertes
**Objectif :** Configurer des alertes Prometheus

1. Créer des règles d'alerte dans `monitoring/prometheus/rules/`
2. Configurer AlertManager
3. Intégrer avec Slack/Email
4. Tester les alertes

### Exercice 3 : Pipeline Multi-Environnement
**Objectif :** Étendre la pipeline pour dev/staging/prod

1. Paramétrer Terraform avec des workspaces
2. Créer des inventaires Ansible par environnement
3. Modifier le Jenkinsfile pour supporter les branches
4. Implémenter une stratégie de promotion

---

## 📊 Résultats Attendus

### Métriques de Succès
- ✅ Infrastructure déployée en < 5 minutes
- ✅ 0 vulnérabilité critique dans les scans
- ✅ 100% des tests passent
- ✅ Monitoring opérationnel avec dashboards

### URLs d'Accès
- **Prometheus :** http://localhost:9090
- **Grafana :** http://localhost:3000 (admin/gitops2024)
- **Jenkins :** http://localhost:8080

### Dashboards Grafana à Importer
- Docker Host : ID 1860
- Jenkins Performance : ID 9964
- Prometheus Stats : ID 2

---

## 🐛 Troubleshooting

### Problème : Containers ne démarrent pas
```bash
# Vérifier les logs
docker logs prometheus
docker logs grafana
docker logs jenkins

# Vérifier les permissions
ls -la /var/run/docker.sock
```

### Problème : Terraform échoue
```bash
# Nettoyer l'état
terraform destroy -auto-approve
rm -rf .terraform terraform.tfstate*
terraform init
```

### Problème : Checkov trouve des vulnérabilités
```bash
# Voir le détail
checkov -d . --framework all --output cli
# Appliquer les suppressions si justifiées
# checkov:skip=CKV_DOCKER_2:HEALTHCHECK not needed for this container
```

---

## 📚 Ressources et Documentation

### Documentation Officielle
- [GitOps Principles](https://www.gitops.tech/) - OpenGitOps 2024
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [Ansible Docker Module](https://docs.ansible.com/ansible/latest/collections/community/docker/index.html)
- [Chainguard Images](https://edu.chainguard.dev/chainguard/chainguard-images/reference/)
- [Checkov Documentation](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html)
- [Trivy Documentation](https://aquasecurity.github.io/trivy/latest/)

### Articles Récents (2024)
- "GitOps with Terraform and Kubernetes" - CNCF Blog, Oct 2024
- "Securing Your GitOps Pipeline" - DevSecOps Institute, Sep 2024
- "Chainguard Images for Production" - Container Journal, Nov 2024

### GitHub Repositories
- [Prometheus Operator](https://github.com/prometheus-operator/prometheus-operator)
- [Grafana Dashboards](https://github.com/grafana/dashboards)
- [Jenkins Configuration as Code](https://github.com/jenkinsci/configuration-as-code-plugin)

---

## ✅ Checklist de Validation Finale

- [ ] Tous les containers sont en état "running"
- [ ] Prometheus scrape tous les targets
- [ ] Grafana affiche les métriques
- [ ] Jenkins pipeline s'exécute sans erreur
- [ ] Pas de vulnérabilité HIGH/CRITICAL
- [ ] Tests d'intégration passent
- [ ] Documentation complète
- [ ] Code versionné dans Git

---

## 👨‍🏫 Notes pour l'Enseignant

### Timing Suggéré
- **Introduction & Setup :** 45 min
- **Terraform :** 45 min
- **Ansible :** 30 min
- **Security :** 45 min
- **Jenkins Pipeline :** 60 min
- **Tests & Validation :** 30 min
- **Exercices :** 45 min

### Points d'Évaluation
1. **Infrastructure (30%)** - Terraform fonctionnel
2. **Configuration (20%)** - Ansible correct
3. **Sécurité (25%)** - Scans passent
4. **Pipeline (25%)** - Jenkins automatisé

### Difficultés Communes
- Permissions Docker socket
- Conflits de ports
- Authentification Grafana
- Syntaxe Jenkinsfile

---

**Fin du TP**

*Ce TP a été conçu pour fournir une expérience pratique complète de l'implémentation GitOps avec les meilleures pratiques de sécurité et d'automatisation.*
