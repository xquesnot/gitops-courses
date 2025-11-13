# 🚀 GitOps TP - Système de Correction Automatique

## 📋 Vue d'ensemble

Ce système fournit une infrastructure GitOps complète avec correction automatique pour le TP DevOps Master. Il inclut :

- **Stack complète** : Docker Compose avec 15+ services
- **Installation automatique** : Scripts PowerShell pour Windows
- **Correction automatique** : Système de notation sur 100 points (20/20)
- **Rapports détaillés** : HTML et JSON avec feedback personnalisé

## 🏗️ Architecture

```
GitOps TP Stack
├── Monitoring
│   ├── Prometheus (Metrics)
│   ├── Grafana (Visualization)
│   ├── AlertManager (Alerting)
│   ├── Node Exporter (System Metrics)
│   └── cAdvisor (Container Metrics)
├── CI/CD
│   ├── Jenkins (Automation)
│   ├── GitLab (Source Control)
│   └── SonarQube (Code Quality)
├── Security
│   ├── Trivy (Vulnerability Scanner)
│   └── Checkov (IaC Scanner)
├── Storage
│   ├── PostgreSQL (Database)
│   └── Redis (Cache)
└── Tools
    ├── Portainer (Container Management)
    └── Application (Sample App)
```

## 📦 Fichiers Fournis

| Fichier | Description | Utilisation |
|---------|-------------|------------|
| `docker-compose.yml` | Stack complète GitOps | Infrastructure principale |
| `Install-GitOpsTP.ps1` | Script d'installation PowerShell | Installation automatique |
| `Grade-GitOpsTP.ps1` | Script de correction automatique | Évaluation du TP |
| `START_GITOPS_TP.bat` | Lanceur Windows | Interface utilisateur simple |

## 🚀 Installation Rapide (Windows)

### Option 1 : Via le fichier Batch (Recommandé)

1. **Télécharger les fichiers** dans un dossier
2. **Clic droit** sur `START_GITOPS_TP.bat` → **Exécuter en tant qu'administrateur**
3. **Sélectionner option 1** pour installation complète
4. **Attendre** 5-10 minutes pour le téléchargement des images

### Option 2 : Via PowerShell

```powershell
# Ouvrir PowerShell en tant qu'administrateur
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Naviguer vers le dossier
cd C:\VotreDossier

# Lancer l'installation
.\Install-GitOpsTP.ps1 -AutoStart

# Ou avec paramètres personnalisés
.\Install-GitOpsTP.ps1 -InstallPath "D:\GitOps" -AutoStart -Verbose
```

### Option 3 : Manuel avec Docker Compose

```bash
# Créer le dossier projet
mkdir C:\GitOpsTP
cd C:\GitOpsTP

# Copier les fichiers de configuration
# (docker-compose.yml et dossiers config)

# Lancer la stack
docker-compose up -d

# Vérifier le statut
docker-compose ps
```

## 📊 Système de Notation Automatique

### Lancer la Correction

```powershell
# Correction simple
.\Grade-GitOpsTP.ps1

# Avec informations étudiant
.\Grade-GitOpsTP.ps1 -StudentName "Jean Dupont" -StudentID "ETU2024001"

# Avec chemin personnalisé
.\Grade-GitOpsTP.ps1 -ProjectPath "D:\MonProjet" -GenerateReport
```

### Catégories Évaluées

| Catégorie | Points | Critères |
|-----------|--------|----------|
| **Infrastructure** | 20 | Docker, Containers, Networks, Volumes |
| **Configuration** | 15 | Prometheus, Grafana, Services |
| **Security** | 20 | Scanning, Vulnerabilities, Best Practices |
| **CI/CD** | 20 | Jenkins, Pipeline, Terraform, Ansible |
| **Monitoring** | 15 | Endpoints, Metrics, Dashboards |
| **Documentation** | 5 | README, Comments |
| **Best Practices** | 5 | Logging, Resources, Backup |
| **TOTAL** | 100 | Converti en note /20 |

### Barème de Notation

| Points | Note /20 | Grade | Appréciation |
|--------|----------|-------|--------------|
| 90-100 | 18-20 | A | Excellent |
| 80-89 | 16-17.9 | B | Très bien |
| 70-79 | 14-15.9 | C | Bien |
| 60-69 | 12-13.9 | D | Satisfaisant |
| < 60 | < 12 | F | Insuffisant |

## 🔍 Tests Automatiques Effectués

### 1. Infrastructure (20 points)
- ✅ Docker daemon running (2 pts)
- ✅ Docker Compose installed (2 pts)
- ✅ docker-compose.yml exists (3 pts)
- ✅ Valid syntax (3 pts)
- ✅ Containers running (10 pts)

### 2. Configuration (15 points)
- ✅ Prometheus config (5 pts)
- ✅ Grafana datasources (5 pts)
- ✅ Service configurations (5 pts)

### 3. Security (20 points)
- ✅ Trivy scanner (3 pts)
- ✅ Checkov scanner (3 pts)
- ✅ Security reports (4 pts)
- ✅ No critical vulnerabilities (5 pts)
- ✅ Dockerfile best practices (5 pts)

### 4. CI/CD (20 points)
- ✅ Jenkinsfile exists (3 pts)
- ✅ Pipeline stages (12 pts)
- ✅ Jenkins accessible (5 pts)

### 5. Monitoring (15 points)
- ✅ Service endpoints (15 pts)
  - Prometheus (3 pts)
  - Grafana (3 pts)
  - Jenkins (3 pts)
  - Application (3 pts)
  - Others (3 pts)

## 📈 Rapports Générés

### Rapport HTML
- **Localisation** : `C:\GitOpsTP\grading-report.html`
- **Contenu** :
  - Grade global avec visualisation
  - Breakdown par catégorie
  - Résultats détaillés des tests
  - Feedback personnalisé
  - Recommandations d'amélioration

### Rapport JSON
- **Localisation** : `C:\GitOpsTP\grading-report.json`
- **Utilisation** : Intégration avec systèmes de notation

## 🛠️ Configuration Avancée

### Variables d'Environnement

```powershell
# Modifier les mots de passe par défaut
$env:GRAFANA_PASSWORD = "MonMotDePasse"
$env:JENKINS_PASSWORD = "AutreMotDePasse"
$env:POSTGRES_PASSWORD = "PostgresPass"
```

### Personnaliser les Ports

Éditer `docker-compose.yml` :

```yaml
services:
  prometheus:
    ports:
      - "19090:9090"  # Changer le port externe
```

### Limiter les Ressources

```yaml
services:
  jenkins:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G
```

## 🔧 Commandes Utiles

### Docker Compose

```bash
# Statut des services
docker-compose ps

# Logs en temps réel
docker-compose logs -f [service]

# Redémarrer un service
docker-compose restart prometheus

# Mise à jour des images
docker-compose pull
docker-compose up -d

# Nettoyer tout
docker-compose down -v
```

### Debugging

```bash
# Vérifier la santé des containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Inspecter un container
docker inspect gitops-prometheus

# Exécuter une commande dans un container
docker exec -it gitops-jenkins bash

# Voir l'utilisation des ressources
docker stats
```

## 🚨 Troubleshooting

### Problème : "Docker daemon not running"
**Solution** :
```bash
# Démarrer Docker Desktop
"C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Ou via services Windows
net start com.docker.service
```

### Problème : "Port already in use"
**Solution** :
```powershell
# Identifier le processus
netstat -ano | findstr :9090

# Tuer le processus
taskkill /PID [PID] /F

# Ou changer le port dans docker-compose.yml
```

### Problème : "Container unhealthy"
**Solution** :
```bash
# Vérifier les logs
docker logs gitops-[service]

# Redémarrer le service
docker-compose restart [service]

# Recréer le container
docker-compose up -d --force-recreate [service]
```

### Problème : "Permission denied"
**Solution** :
```powershell
# Lancer PowerShell en administrateur
# Ou ajuster les permissions
icacls C:\GitOpsTP /grant Everyone:F /T
```

## 📚 Structure des Dossiers

```
C:\GitOpsTP\
├── config/
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── rules/
│   ├── grafana/
│   │   ├── provisioning/
│   │   └── dashboards/
│   ├── jenkins/
│   │   ├── jobs/
│   │   └── init.groovy.d/
│   ├── alertmanager/
│   ├── postgres/
│   └── redis/
├── application/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js
├── terraform/
├── ansible/
├── scripts/
├── tests/
├── docker-compose.yml
├── docker-compose.override.yml
├── Install-GitOpsTP.ps1
├── Grade-GitOpsTP.ps1
├── grading-report.html
└── grading-report.json
```

## 🔐 Sécurité

### Mots de Passe par Défaut

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | gitops2024 |
| Jenkins | admin | jenkins2024 |
| GitLab | root | gitlab2024root |
| SonarQube | admin | admin |
| PostgreSQL | postgres | postgres2024 |

⚠️ **Important** : Changer ces mots de passe en production !

### Bonnes Pratiques
- 🔒 Utiliser des secrets Docker
- 🔐 Activer HTTPS/TLS
- 🛡️ Implémenter RBAC
- 📝 Auditer les logs régulièrement
- 🔄 Maintenir les images à jour

## 📞 Support et Contact

### Ressources
- Documentation Docker : https://docs.docker.com
- Jenkins Docs : https://www.jenkins.io/doc/
- Prometheus : https://prometheus.io/docs/
- Grafana : https://grafana.com/docs/

### Problèmes Fréquents
1. **Windows** : WSL2 requis pour Docker Desktop
2. **Mémoire** : Minimum 8GB RAM recommandé
3. **Espace disque** : 20GB minimum requis
4. **Réseau** : Ports 3000, 8080, 8081, 9000, 9090 doivent être libres

## 📝 Licence

Ce projet est fourni à des fins éducatives dans le cadre du cours DevOps Master.

---

## 🎯 Checklist Étudiant

Avant de soumettre votre TP, vérifiez :

- [ ] Tous les containers sont en état "running"
- [ ] Prometheus collecte des métriques (http://localhost:9090)
- [ ] Grafana affiche les dashboards (http://localhost:3000)
- [ ] Jenkins pipeline s'exécute sans erreur
- [ ] Pas de vulnérabilités HIGH/CRITICAL (Trivy scan)
- [ ] Tests d'intégration passent
- [ ] Documentation README.md complète
- [ ] Code versionné dans Git
- [ ] Rapport de notation généré (> 14/20)

---

**Dernière mise à jour** : Novembre 2024  
**Version** : 1.0.0  
**Auteur** : DevOps Master Course Team
