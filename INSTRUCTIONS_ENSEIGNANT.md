# 📚 INSTRUCTIONS ENSEIGNANT - TP GitOps avec Correction Automatique

## 🎯 Contenu du Package

Ce package contient tout le nécessaire pour le TP GitOps avec correction automatique :

### 📁 Structure des Dossiers

```
TP_GitOps_Complete/
├── README.md                      # Documentation principale pour les étudiants
├── START_GITOPS_TP.bat           # Lanceur principal Windows (menu interactif)
├── Setup-GitOpsTP-QuickStart.ps1 # Script tout-en-un rapide
│
├── Documentation/
│   ├── TP_Enonce.md              # Énoncé complet du TP
│   ├── Guide_Etudiant.md         # Guide pour les étudiants
│   └── Architecture.md           # Description de l'architecture
│
├── Corrige/
│   ├── Corrige_Complet.md        # Solutions détaillées
│   ├── Solutions_Terraform/      # Fichiers Terraform corrigés
│   ├── Solutions_Ansible/        # Playbooks Ansible corrigés
│   └── Solutions_Jenkins/        # Jenkinsfile corrigé
│
├── Docker/
│   ├── docker-compose.yml        # Stack Docker complète
│   └── docker-compose.prod.yml   # Version production
│
├── Installation/
│   ├── Install-GitOpsTP.ps1      # Script d'installation complet
│   └── requirements.txt          # Dépendances Python
│
├── Scripts/
│   ├── Grade-GitOpsTP.ps1        # Système de correction automatique
│   └── Generate-Report.ps1       # Génération de rapports
│
├── Tests/
│   ├── Test-GitOpsTP.ps1         # Tests fonctionnels
│   └── test_scenarios.json       # Scénarios de test
│
└── Config/
    ├── prometheus/               # Configuration Prometheus
    ├── grafana/                 # Dashboards Grafana
    └── jenkins/                 # Jobs Jenkins
```

## 🚀 Guide de Déploiement pour l'Enseignant

### Étape 1 : Préparation (5 min)

1. **Décompresser** le fichier ZIP dans un dossier accessible
2. **Vérifier** que Docker Desktop est installé sur les machines
3. **Partager** le dossier avec les étudiants (réseau, USB, cloud)

### Étape 2 : Distribution aux Étudiants

**Option A : Réseau Partagé**
```powershell
# Créer un partage réseau
New-SmbShare -Name "TP_GitOps" -Path "C:\TP_GitOps_Complete" -ReadAccess "Everyone"
```

**Option B : Archive ZIP**
- Fournir le fichier `TP_GitOps_Complete.zip` via Moodle/Teams

### Étape 3 : Instructions pour les Étudiants

Les étudiants doivent :
1. Copier le dossier sur leur PC
2. Lancer `START_GITOPS_TP.bat` en administrateur
3. Choisir Option 1 pour installation complète
4. Attendre 5-10 minutes

## 📊 Système de Correction Automatique

### Lancer la Correction (30 secondes par étudiant)

**Méthode 1 : Interface Graphique**
```
1. Double-clic sur START_GITOPS_TP.bat
2. Option 6 : Run Automatic Grading
3. Entrer nom et ID de l'étudiant
4. Le rapport HTML s'ouvre automatiquement
```

**Méthode 2 : PowerShell Direct**
```powershell
cd C:\TP_GitOps_Complete\Scripts
.\Grade-GitOpsTP.ps1 -StudentName "Jean Dupont" -StudentID "2024001" -GenerateReport
```

**Méthode 3 : Correction en Lot**
```powershell
# Pour corriger plusieurs étudiants
$students = @(
    @{Name="Jean Dupont"; ID="2024001"; Path="C:\Submissions\Dupont"},
    @{Name="Marie Martin"; ID="2024002"; Path="C:\Submissions\Martin"}
)

foreach ($student in $students) {
    .\Grade-GitOpsTP.ps1 -ProjectPath $student.Path `
                         -StudentName $student.Name `
                         -StudentID $student.ID `
                         -GenerateReport
}
```

### Barème de Notation (100 points → Note/20)

| Catégorie | Points | Détails |
|-----------|--------|---------|
| **Infrastructure** | 20 | Docker, Containers, Networks, Volumes |
| **Configuration** | 15 | Prometheus, Grafana configs |
| **Sécurité** | 20 | Scanning, Best practices |
| **CI/CD** | 20 | Jenkins, Pipeline, IaC |
| **Monitoring** | 15 | Endpoints, Metrics |
| **Documentation** | 5 | README, Comments |
| **Best Practices** | 5 | Logs, Resources |

### Interprétation des Résultats

| Score | Note/20 | Grade | Appréciation |
|-------|---------|-------|--------------|
| 90-100 | 18-20 | A | Excellent - Maîtrise complète |
| 80-89 | 16-17.9 | B | Très bien - Compétences solides |
| 70-79 | 14-15.9 | C | Bien - Objectifs atteints |
| 60-69 | 12-13.9 | D | Satisfaisant - À consolider |
| < 60 | < 12 | F | Insuffisant - Reprise nécessaire |

## 📈 Rapports Générés

### 1. Rapport HTML (Principal)
- **Localisation** : `grading-report.html`
- **Contenu** :
  - Score détaillé par catégorie
  - Graphiques visuels
  - Feedback personnalisé
  - Recommandations

### 2. Rapport JSON (Intégration)
- **Localisation** : `grading-report.json`
- **Usage** : Import dans LMS/Excel

### 3. Export CSV (Option)
```powershell
# Exporter les résultats en CSV
$results | Export-Csv -Path "resultats_tp.csv" -NoTypeInformation
```

## 🔧 Personnalisation du TP

### Modifier la Difficulté

**Niveau Débutant** : Utiliser `docker-compose.simple.yml`
```yaml
# Version simplifiée avec moins de services
services:
  prometheus:
    image: prom/prometheus:latest
  grafana:
    image: grafana/grafana:latest
```

**Niveau Avancé** : Ajouter des challenges
- Kubernetes au lieu de Docker Compose
- Multi-environnements (dev/staging/prod)
- Pipeline GitLab CI/CD

### Adapter le Barème

Modifier dans `Grade-GitOpsTP.ps1` :
```powershell
$GradeCategories = @{
    "Infrastructure" = 25  # Augmenter pour plus de focus
    "Security" = 25        # sur la sécurité
    "CICD" = 15
    # etc...
}
```

## 🚨 Troubleshooting Enseignant

### Problème : "Étudiants ont des erreurs Docker"

**Solution 1** : Vérifier Docker Desktop
```powershell
# Script de diagnostic
docker version
docker-compose version
docker ps
```

**Solution 2** : Reset Docker
```powershell
# Nettoyer Docker
docker system prune -af
docker volume prune -f
# Relancer l'installation
```

### Problème : "La correction ne fonctionne pas"

**Vérifications** :
1. Les services sont-ils démarrés ?
2. Les ports sont-ils disponibles ?
3. PowerShell est-il en mode administrateur ?

### Problème : "Manque de ressources"

**Optimisation** :
```powershell
# Limiter les ressources Docker
docker update --memory="1g" --cpus="1" [container]
```

## 📋 Checklist Pré-TP

### Une Semaine Avant
- [ ] Tester l'installation complète sur une machine type
- [ ] Vérifier les prérequis (Docker, RAM, espace disque)
- [ ] Préparer les supports de cours

### Jour J
- [ ] Distribuer les fichiers 30 min avant
- [ ] Lancer un exemple de démo
- [ ] Avoir une machine de secours prête

### Après le TP
- [ ] Collecter tous les rapports HTML
- [ ] Générer un rapport consolidé
- [ ] Archiver les soumissions

## 📊 Statistiques et Métriques

### Générer un Rapport Global

```powershell
# Script pour statistiques de classe
$reports = Get-ChildItem -Path ".\Reports" -Filter "*grading-report.json"
$stats = @()

foreach ($report in $reports) {
    $data = Get-Content $report | ConvertFrom-Json
    $stats += [PSCustomObject]@{
        Student = $data.StudentName
        Grade = $data.Grade
        Percentage = $data.Percentage
    }
}

# Calculer les moyennes
$average = ($stats | Measure-Object -Property Grade -Average).Average
$median = ($stats | Sort-Object Grade)[[Math]::Floor($stats.Count/2)].Grade

Write-Host "Moyenne de classe : $average / 20"
Write-Host "Médiane : $median / 20"
```

## 💡 Tips Pédagogiques

### Points d'Attention
1. **Temps** : Prévoir 4h minimum (1h install, 2h travail, 1h debug)
2. **Groupes** : Possibilité de travail en binômes
3. **Évaluation** : 70% automatique + 30% soutenance

### Bonus Possibles (+2 points)
- Implémentation de monitoring avancé
- Ajout de tests de sécurité
- Documentation exceptionnelle
- Pipeline multi-branches

### Exercices Complémentaires
1. Ajouter AlertManager avec Slack
2. Implémenter Kubernetes au lieu de Docker
3. Créer un dashboard Grafana personnalisé
4. Ajouter SonarQube pour l'analyse de code

## 📞 Support

### Ressources en Ligne
- Documentation Docker : https://docs.docker.com
- Prometheus Docs : https://prometheus.io/docs
- Jenkins Tutorials : https://www.jenkins.io/doc/tutorials

### FAQ Rapide

**Q : Combien de temps pour la correction ?**
R : 30 secondes par étudiant en automatique

**Q : Peut-on personnaliser les tests ?**
R : Oui, modifier Grade-GitOpsTP.ps1

**Q : Compatible Mac/Linux ?**
R : Docker oui, scripts PowerShell à adapter

---

## ✅ Validation Finale

Avant de distribuer, vérifier :
- [ ] Tous les fichiers sont présents
- [ ] Docker Desktop fonctionne
- [ ] Le script de correction fonctionne
- [ ] Les rapports sont générés correctement
- [ ] La documentation est à jour

---

**Version** : 1.0.0  
**Date** : Novembre 2024  
**Support** : devops-master@university.edu

*Ce package a été conçu pour simplifier au maximum la gestion du TP tout en garantissant une évaluation objective et automatisée.*
