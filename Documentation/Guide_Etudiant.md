# 🚀 Guide Étudiant - TP GitOps

## 📋 Objectifs du TP

Dans ce TP, vous allez :
- ✅ Déployer une infrastructure GitOps complète avec Docker
- ✅ Configurer un pipeline CI/CD avec Jenkins
- ✅ Mettre en place un monitoring avec Prometheus/Grafana
- ✅ Implémenter des scans de sécurité
- ✅ Automatiser le déploiement avec Terraform et Ansible

## 🎯 Démarrage Rapide (10 minutes)

### Étape 1 : Installation Automatique

1. **Ouvrir** le dossier `TP_GitOps_Complete`
2. **Clic droit** sur `START_GITOPS_TP.bat`
3. **Sélectionner** "Exécuter en tant qu'administrateur"
4. **Choisir** Option 1 : "Complete Installation"
5. **Attendre** 5-10 minutes ☕

### Étape 2 : Vérification

Une fois l'installation terminée, vérifiez que tout fonctionne :

| Service | URL | Credentials |
|---------|-----|-------------|
| 📊 Prometheus | http://localhost:9090 | - |
| 📈 Grafana | http://localhost:3000 | admin / gitops2024 |
| 🔧 Jenkins | http://localhost:8081 | admin / jenkins2024 |
| 🌐 Application | http://localhost:3001 | - |

## 📝 Travail à Réaliser (3 heures)

### Partie 1 : Infrastructure (45 min)

1. **Explorer** le fichier `Docker/docker-compose.yml`
2. **Ajouter** un nouveau service (ex: Nginx, Redis)
3. **Configurer** les réseaux et volumes
4. **Tester** avec `docker-compose ps`

### Partie 2 : Configuration (45 min)

1. **Modifier** `Config/prometheus/prometheus.yml`
   - Ajouter une nouvelle target
   - Configurer les scrape intervals

2. **Créer** un dashboard Grafana
   - Importer le dashboard ID: 1860 (Docker)
   - Créer un dashboard personnalisé

### Partie 3 : CI/CD (45 min)

1. **Créer** un `Jenkinsfile` dans votre projet
```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
        stage('Test') {
            steps {
                echo 'Testing...'
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
            }
        }
    }
}
```

2. **Configurer** un job Jenkins
3. **Exécuter** le pipeline

### Partie 4 : Sécurité (45 min)

1. **Installer** Trivy (si pas déjà fait)
```bash
# Windows (PowerShell)
choco install trivy
# ou télécharger depuis GitHub
```

2. **Scanner** vos images Docker
```bash
trivy image grafana/grafana:latest
```

3. **Documenter** les vulnérabilités trouvées

## 🔍 Points d'Évaluation

Votre travail sera évalué sur :

| Critère | Points | Ce qu'on regarde |
|---------|--------|------------------|
| **Infrastructure** | /20 | Containers running, network configuré |
| **Configuration** | /15 | Prometheus et Grafana configurés |
| **Sécurité** | /20 | Scans effectués, best practices |
| **CI/CD** | /20 | Pipeline fonctionnel |
| **Monitoring** | /15 | Métriques collectées |
| **Documentation** | /5 | README.md créé |
| **Best Practices** | /5 | Code propre, logs |

## 🛠️ Commandes Utiles

### Docker
```bash
# Voir les containers
docker ps

# Voir les logs
docker logs gitops-prometheus

# Redémarrer un service
docker-compose restart prometheus

# Tout arrêter
docker-compose down

# Tout relancer
docker-compose up -d
```

### Tests
```powershell
# Tester votre travail
.\Tests\Test-GitOpsTP.ps1

# Voir votre note estimée
.\Scripts\Grade-GitOpsTP.ps1
```

## 🐛 Troubleshooting

### Problème : "Port already in use"
```bash
# Trouver le processus
netstat -ano | findstr :9090

# Le tuer
taskkill /PID [numero] /F
```

### Problème : "Container unhealthy"
```bash
# Voir les logs
docker logs gitops-[service]

# Redémarrer
docker-compose restart [service]
```

### Problème : "Docker daemon not running"
1. Ouvrir Docker Desktop
2. Attendre qu'il démarre
3. Réessayer

## 📚 Ressources

- 📖 [Documentation Docker](https://docs.docker.com)
- 📖 [Prometheus Getting Started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- 📖 [Grafana Tutorials](https://grafana.com/tutorials/)
- 📖 [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)

## ✅ Checklist Avant de Rendre

Avant de soumettre votre travail, vérifiez :

- [ ] Tous les containers sont "running"
- [ ] Prometheus collecte des métriques
- [ ] Grafana a au moins 1 dashboard
- [ ] Jenkins pipeline s'exécute
- [ ] Pas de vulnérabilités CRITICAL
- [ ] README.md documenté
- [ ] Code dans Git

## 💡 Tips pour Réussir

1. **Commencez simple** : Faites fonctionner les bases avant d'ajouter des features
2. **Testez souvent** : Utilisez `docker-compose ps` régulièrement
3. **Documentez** : Notez ce que vous faites dans README.md
4. **Demandez de l'aide** : N'hésitez pas si vous êtes bloqué
5. **Sauvegardez** : Commitez votre travail dans Git

## 🎯 Auto-Évaluation

Pour voir votre note estimée :
```powershell
# Lancer la correction automatique
.\Scripts\Grade-GitOpsTP.ps1

# Un rapport HTML sera généré
```

## 🏆 Challenges Bonus (+2 points)

Si vous finissez en avance :

1. **Monitoring Avancé** : Ajouter AlertManager avec des règles
2. **Security++ ** : Implémenter Checkov pour scanner l'IaC
3. **Automation** : Créer des playbooks Ansible
4. **Documentation** : Créer des diagrammes d'architecture

---

**Bon courage !** 💪

*N'oubliez pas : L'objectif est d'apprendre, pas juste d'avoir une bonne note. Explorez, testez, cassez des choses et apprenez de vos erreurs !*

---

**Support** : Votre enseignant est là pour vous aider
**Durée** : 4 heures
**Rendu** : Fin de séance
