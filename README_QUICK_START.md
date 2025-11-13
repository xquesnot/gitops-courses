# 📦 TP GitOps Complete - Package All-in-One

## 🚀 Démarrage Ultra-Rapide

### Pour Windows (Recommandé)
```cmd
1. Décompresser le ZIP
2. Double-clic sur START_GITOPS_TP.bat (en admin)
3. Choisir Option 1
4. C'est parti ! 🎉
```

### Pour PowerShell
```powershell
# Installation complète en 1 commande
.\Setup-GitOpsTP-QuickStart.ps1
```

## 📁 Contenu du Package

```
TP_GitOps_Complete.zip (68 KB)
│
├── 🚀 START_GITOPS_TP.bat         # Lanceur principal avec menu
├── 📄 README.md                    # Ce fichier
├── 📚 INSTRUCTIONS_ENSEIGNANT.md   # Guide pour l'enseignant
│
├── 📂 Installation/
│   ├── Install-GitOpsTP.ps1       # Script d'installation complet
│   └── Setup-QuickStart.ps1       # Installation rapide
│
├── 📂 Scripts/
│   └── Grade-GitOpsTP.ps1         # Correction automatique
│
├── 📂 Docker/
│   └── docker-compose.yml         # Stack GitOps complète
│
├── 📂 Documentation/
│   └── Guide_Etudiant.md          # Guide pour les étudiants
│
├── 📂 Corrige/                    # Solutions (enseignant only)
│   ├── Solutions_Jenkins/
│   ├── Solutions_Terraform/
│   └── Solutions_Ansible/
│
└── 📂 Config/                      # Configurations de base
    ├── prometheus/
    ├── grafana/
    └── jenkins/
```

## 🎯 Objectifs du TP

- ✅ Déployer une infrastructure GitOps
- ✅ Configurer CI/CD avec Jenkins
- ✅ Monitoring avec Prometheus/Grafana
- ✅ Security scanning avec Trivy
- ✅ IaC avec Terraform et Ansible

## 📊 Système de Notation Automatique

- **100 points** convertis en note **/20**
- **7 catégories** évaluées
- **Rapport HTML** généré automatiquement
- **30 secondes** pour corriger un étudiant

## 💻 Prérequis

- Windows 10/11
- Docker Desktop installé
- 8 GB RAM minimum
- 20 GB espace disque
- PowerShell 5.1+

## 🔧 Commandes Essentielles

```powershell
# Installer tout
.\Installation\Install-GitOpsTP.ps1

# Lancer la correction
.\Scripts\Grade-GitOpsTP.ps1

# Tester l'installation
.\Tests\Test-GitOpsTP.ps1

# Voir les services
docker-compose ps
```

## 🌐 URLs des Services

| Service | URL | Login |
|---------|-----|-------|
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin / gitops2024 |
| Jenkins | http://localhost:8081 | admin / jenkins2024 |
| App | http://localhost:3001 | - |

## 📝 Pour les Étudiants

1. Suivre le guide dans `Documentation/Guide_Etudiant.md`
2. Compléter les 4 parties du TP
3. Lancer l'auto-évaluation
4. Soumettre le rapport généré

## 👨‍🏫 Pour les Enseignants

1. Lire `INSTRUCTIONS_ENSEIGNANT.md`
2. Distribuer le ZIP aux étudiants
3. Lancer la correction automatique
4. Récupérer les rapports HTML

## 🆘 Support

### Problème Docker ?
```powershell
# Vérifier Docker
docker version

# Redémarrer Docker
Restart-Service docker
```

### Problème Ports ?
```powershell
# Libérer les ports
netstat -ano | findstr :9090
taskkill /PID [numero] /F
```

### Problème Installation ?
```powershell
# Reset complet
docker system prune -af
.\Installation\Install-GitOpsTP.ps1 -Force
```

## ✨ Features

- ✅ Installation **1-click**
- ✅ Correction **automatique**
- ✅ Interface **Windows native**
- ✅ **15+ services** Docker
- ✅ **Security scanning** intégré
- ✅ **Best practices** appliquées
- ✅ Documentation **complète**
- ✅ Support **multi-étudiants**

## 📈 Workflow

```
Étudiant          Système              Enseignant
    |                |                      |
    |-- Install ---> |                      |
    |                |-- Deploy Stack -->   |
    |-- Work ------> |                      |
    |                |-- Auto Grade --->    |
    |                |                      |
    |                |<-- HTML Report --    |
    |                |                      |
    |----------------|-- Submit --------->  |
```

## 🏆 Barème

| Score | Note/20 | Grade |
|-------|---------|-------|
| 90-100 | 18-20 | A |
| 80-89 | 16-18 | B |
| 70-79 | 14-16 | C |
| 60-69 | 12-14 | D |
| < 60 | < 12 | F |

## 📅 Planning Suggéré (4h)

- **0h30** : Installation
- **1h00** : Infrastructure Docker
- **1h00** : Configuration Services
- **1h00** : CI/CD Pipeline
- **0h30** : Tests et Correction

## 🔒 Sécurité

Tous les mots de passe par défaut sont dans `.env.example`
**⚠️ À changer en production !**

## 📄 License

Usage éducatif uniquement - DevOps Master Course 2024

---

**Version** : 1.0.0  
**Date** : Novembre 2024  
**Support** : devops@university.edu

---

## 🎉 Ready to Start?

```powershell
# Let's Go!
.\START_GITOPS_TP.bat
```

*Bon TP et bonne correction automatique !* 🚀
