# Gestionnaire Active Directory - EcoTech Solutions v2.0
## Architecture Modulaire avec Menu Interactif

---

## 📦 Fichiers du projet

```
📁 EcoTech-AD-Manager/
│
├── 📄 Start-ADManager.ps1          # Script principal (POINT D'ENTRÉE)
├── 📄 Config-EcoTechAD.psd1        # Configuration centrale (SSOT)
│
├── 📦 Modules/
│   ├── Module-Common.psm1          # Fonctions communes
│   ├── Module-OU.psm1              # Gestion des OUs
│   ├── Module-Groups.psm1          # Gestion des groupes
│   ├── Module-Users.psm1           # Gestion des utilisateurs
│   └── Module-Computers.psm1       # Gestion des ordinateurs
│
└── 📚 Documentation/
    ├── README-MODULAIRE.md         # Ce fichier
    └── GUIDE-UTILISATION.md        # Guide rapide
```

---

## 🚀 Démarrage Rapide

### 1. Première utilisation

```powershell
# 1. Placer tous les fichiers dans un même répertoire
# 2. Ouvrir PowerShell en Administrateur
# 3. Se placer dans le répertoire
cd C:\Scripts\EcoTech-AD

# 4. Lancer le menu principal
.\Start-ADManager.ps1
```

### 2. Menu principal

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║     GESTIONNAIRE ACTIVE DIRECTORY - ECOTECH SOLUTIONS    ║
║                                                          ║
║                    Version 2.0                           ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝

┌────────────────────────────────────────────────────────┐
│                    MENU PRINCIPAL                      │
└────────────────────────────────────────────────────────┘

  1. 📁 Gestion des Unités d'Organisation (OUs)
  2. 👥 Gestion des Groupes de Sécurité
  3. 👤 Gestion des Utilisateurs
  4. 💻 Gestion des Ordinateurs

  5. ⚡ Déploiement rapide complet

  I. ℹ️  Informations
  Q. 🚪 Quitter

Votre choix : _
```

---

## 📋 Fonctionnalités par Module

### 📁 Module 1 : Gestion des OUs

**Fonctions disponibles :**

1. **Créer toute l'arborescence** - Crée TOUTES les OUs depuis la configuration
2. **Ajouter une OU** - Ajouter une OU manuellement
3. **Modifier une OU** - Changer la description
4. **Supprimer une OU** - Supprimer avec confirmation
5. **Lister les OUs** - Voir la structure complète

**Exemple d'utilisation :**
```powershell
# Dans le menu : 1 → 1
# Crée automatiquement :
# - ECOTECH/BDX/UX/D01-D07/S01-S07
# - ECOTECH/BDX/GX
# - ECOTECH/BDX/SX/D01-D07
# - ECOTECH/BDX/WX/BX/CX/EX/FX/GX
# + UBIHARD et SDLIGHT
```

---

### 👥 Module 2 : Gestion des Groupes

**Fonctions disponibles :**

1. **Créer tous les groupes** - Crée les 12 groupes de sécurité
2. **Ajouter un groupe** - Créer un groupe personnalisé
3. **Ajouter un membre** - Ajouter utilisateur/ordinateur à un groupe
4. **Retirer un membre** - Retirer d'un groupe
5. **Lister les membres** - Voir qui est dans un groupe

**Groupes créés automatiquement :**
- `GRP_D01_RH`
- `GRP_D02_COMMERCIAL`
- `GRP_D03_COMMUNICATION`
- `GRP_D04_DIRECTION`
- `GRP_D05_DEVELOPPEMENT`
- `GRP_D06_FINANCE`
- `GRP_D07_DSI`
- `GRP_TOUS_UTILISATEURS`
- `GRP_MANAGERS`
- `GRP_DEVELOPPEURS`
- `GRP_ADMINS_SI`

---

### 👤 Module 3 : Gestion des Utilisateurs

**Fonctions disponibles :**

1. **Importer depuis CSV (créer)** - Créer nouveaux utilisateurs
2. **Importer depuis CSV (MAJ)** - Mettre à jour existants
3. **Créer manuellement** - Ajouter un utilisateur sans CSV
4. **Désactiver un utilisateur** - Désactiver le compte

**Format CSV attendu :**
```csv
Civilité;Prenom;Nom;Societe;Site;Departement;Service;fonction;Manager-Prenom;Manager-Nom;Nom de PC;Marque PC;Date de naissance;Telephone fixe;Telephone portable
M.;Jean;Dupont;EcoTechSolutions;Bordeaux;Service Commercial;B2B;Commercial;Marie;Martin;PA12345;DELL;01/01/1990;0501020304;0601020304
```

**Traitement automatique :**
- ✅ SamAccountName : `jean.dupont` (avec gestion doublons)
- ✅ Email : `jedupont@ecotechsolutions.fr`
- ✅ Placement dans la bonne OU selon département/service
- ✅ Ajout aux groupes départementaux
- ✅ Mot de passe par défaut : `EcoTech2026!` (à changer)

---

### 💻 Module 4 : Gestion des Ordinateurs

**Fonctions disponibles :**

1. **Importer portables (CX)** - Depuis CSV avec format ECO-BDX-CX###
2. **Importer postes fixes (BX)** - Depuis CSV avec format ECO-BDX-BX###
3. **Créer manuellement** - Ajouter BX/CX/EX/FX/GX
4. **Déplacer** - Changer d'OU
5. **Supprimer** - Retirer de l'AD

**Nomenclature automatique :**
- `ECO-BDX-BX001`, `ECO-BDX-BX002`, ... (Postes fixes)
- `ECO-BDX-CX001`, `ECO-BDX-CX002`, ... (Portables)
- `ECO-BDX-EX001`, ... (Serveurs - création manuelle)
- `ECO-BDX-FX001`, ... (Appliances)
- `ECO-BDX-GX001`, ... (Postes admin)

**⚠️ Important :** Les machines sont dans `OU=CX` ou `OU=BX` directement (pas de sous-OUs par département pour les machines)

---

## ⚡ Déploiement Rapide (Option 5)

Cette option **tout-en-un** exécute automatiquement :

1. ✅ Création de l'arborescence OU complète
2. ✅ Création des groupes de sécurité
3. ✅ Importation des utilisateurs depuis CSV
4. ✅ Importation des ordinateurs depuis CSV

**Utilisation :**
```powershell
# Dans le menu principal : 5
# Suivre les instructions à l'écran
# Fournir le chemin du CSV quand demandé
```

**⏱️ Temps estimé :** 2-5 minutes pour 243 utilisateurs

---

## 🔧 Configuration

### Fichier Config-EcoTechAD.psd1

**C'est le SSOT (Single Source of Truth)** - Toute la configuration est ici !

```powershell
@{
    # Domaine
    DomainInfo = @{
        Name = "ecotech.local"
        DN = "DC=ecotech,DC=local"
        EmailDomain = "ecotechsolutions.fr"
    }
    
    # Mot de passe par défaut
    DefaultPassword = "EcoTech2026!"
    
    # Mapping départements (RESPECTÉ SELON VOTRE DEMANDE)
    DepartmentMapping = @{
        "Direction des Ressources Humaines" = "D01"
        "Service Commercial" = "D02"
        "Communication" = "D03"
        "Direction" = "D04"
        "Développement" = "D05"
        "Finance et Comptabilité" = "D06"
        "DSI" = "D07"
    }
    
    # Arborescence complète (basée sur OU.md)
    OUStructure = @(
        # ... Toutes les OUs définies
    )
    
    # Mapping services → codes
    ServiceMapping = @{
        # ... Tous les services
    }
}
```

**Pour modifier :**
1. Ouvrir `Config-EcoTechAD.psd1` dans un éditeur
2. Modifier les valeurs
3. Sauvegarder
4. Relancer `Start-ADManager.ps1`

---

## 📊 Arborescence Créée

Basée sur **OU.md** (votre SSOT) :

```
ecotech.local
└── ECOTECH
    └── BDX
        ├── GX (Administration Tiering)
        ├── UX (Utilisateurs)
        │   ├── D01 (RH)
        │   │   ├── S01 (Formation)
        │   │   ├── S02 (Recrutement)
        │   │   ├── S03 (Administration du personnel)
        │   │   ├── S04 (Gestion des carrières)
        │   │   └── S05 (Direction RH)
        │   ├── D02 (Commercial)
        │   │   ├── S01 (Gestion des comptes)
        │   │   ├── S02 (B2B)
        │   │   ├── S03 (Prospection)
        │   │   ├── S04 (ADV)
        │   │   ├── S05 (Service Client)
        │   │   ├── S06 (Service achat)
        │   │   └── S07 (Direction commerciale)
        │   ├── D03-D07...
        │
        ├── SX (Groupes)
        │   ├── D01-D07 (Groupes par département)
        │
        └── WX (Machines)
            ├── BX (Postes fixes)
            ├── CX (Portables)
            ├── EX (Serveurs)
            ├── FX (Appliances)
            └── GX (Postes admin)
```

---

## 🐛 Déboguer facilement

### Logs automatiques

Tous les logs sont dans : `C:\Logs\EcoTech-AD\`

Exemple :
```
C:\Logs\EcoTech-AD\ADManager-20260202-143025.log
```

Chaque action est tracée :
```
[2026-02-02 14:30:25] [Success] OU créée : S01 - Formation
[2026-02-02 14:30:26] [Success] Utilisateur créé : jean.dupont
[2026-02-02 14:30:27] [Warning] Groupe déjà existant : GRP_D01_RH
[2026-02-02 14:30:28] [Error] OU introuvable : OU=TEST
```

### Tester sans modifier

Tous les modules supportent `-WhatIf` :

```powershell
# Tester la création d'OUs sans les créer
Import-Module .\Module-OU.psm1
New-EcoTechOUStructure -WhatIf

# Tester l'import utilisateurs
Import-Module .\Module-Users.psm1
Import-EcoTechUsers -CSVPath "C:\Import\users.csv" -WhatIf
```

### Vérifier les modules

```powershell
# Lister les fonctions exportées
Get-Command -Module Module-Common
Get-Command -Module Module-OU
Get-Command -Module Module-Groups
Get-Command -Module Module-Users
Get-Command -Module Module-Computers

# Obtenir l'aide
Get-Help New-EcoTechOU -Full
Get-Help Import-EcoTechUsers -Examples
```

---

## 🔐 Sécurité

### Mot de passe par défaut

⚠️ **MODIFIER dans Config-EcoTechAD.psd1** :

```powershell
DefaultPassword = "VotreMotDePasseComplexe2026!"
```

### Confirmations de sécurité

Les opérations dangereuses demandent confirmation :
- ❌ Suppression d'OU → Taper "SUPPRIMER"
- ❌ Suppression d'ordinateur → Confirmer O/N
- ⚡ Déploiement rapide → Taper "OUI"

---

## 💡 Conseils d'utilisation

### 1. Ordre recommandé (première fois)

```
1. Créer l'arborescence OU (Module 1 → Option 1)
2. Créer les groupes (Module 2 → Option 1)
3. Importer les utilisateurs (Module 3 → Option 1)
4. Importer les ordinateurs (Module 4 → Option 1)
```

**OU utiliser le Déploiement Rapide (Option 5 du menu principal)**

### 2. Ajouts ponctuels

```
# Nouvel utilisateur
Menu Principal → 3 → 3 (Créer manuellement)

# Nouvel ordinateur
Menu Principal → 4 → 3 (Créer manuellement)

# Nouveau groupe
Menu Principal → 2 → 2 (Ajouter un groupe)
```

### 3. Mises à jour depuis CSV

```
# Le CSV a été modifié avec de nouveaux employés
Menu Principal → 3 → 1 (Importer depuis CSV - créer)

# Mettre à jour les téléphones/emails des utilisateurs existants
Menu Principal → 3 → 2 (Importer depuis CSV - MAJ)
```

---

## ❓ FAQ

### Q: Comment ajouter un nouveau service dans un département ?

**R:** Modifier `Config-EcoTechAD.psd1` :

```powershell
# Dans ServiceMapping
"Nouveau Service" = @{Dept="D02"; Code="S08"}

# Dans OUStructure
@{Name="S08"; Description="Nouveau Service"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
```

Puis : Menu → 1 → 2 (Ajouter une OU)

### Q: Que faire si un utilisateur change de service ?

**R:** 
1. Mettre à jour le CSV
2. Menu → 3 → 2 (Importer avec mise à jour)
3. OU déplacer manuellement avec PowerShell :
```powershell
$user = Get-ADUser -Filter "SamAccountName -eq 'jean.dupont'"
Move-ADObject -Identity $user -TargetPath "OU=S02,OU=D03,OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local"
```

### Q: Comment voir tous les utilisateurs d'un département ?

**R:** Utiliser PowerShell :
```powershell
Get-ADUser -Filter * -SearchBase "OU=D02,OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local" |
    Select-Object Name, SamAccountName, EmailAddress
```

### Q: Les ordinateurs doivent-ils être dans des sous-OUs par département ?

**R:** **NON**. Selon la conception, tous les portables sont dans `OU=CX` directement, tous les fixes dans `OU=BX`, etc. Il n'y a **pas** de sous-OUs par département pour les machines.

---

## 📞 Support

Pour toute question :
1. Consulter les logs : `C:\Logs\EcoTech-AD\`
2. Lire l'aide des fonctions : `Get-Help NomFonction -Full`
3. Contacter l'équipe Admin SI

---

## 📝 Crédits

**Auteur** : Équipe Admin SI - EcoTech Solutions  
**Version** : 2.0 (Architecture Modulaire)  
**Date** : 2026-02-02  

**Basé sur les cours PowerShell :**
- Partie 1 : Introduction
- Partie 2 : Logique de Scripting
- Partie 3 : Structuration du Code

---

**🎉 Bon déploiement !**
