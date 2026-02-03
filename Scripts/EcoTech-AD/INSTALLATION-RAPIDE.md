# 🚀 INSTALLATION RAPIDE - EcoTech AD Manager v2.0

## 📦 Étape 1 : Organisation des fichiers

Créer cette structure de dossiers sur votre serveur :

```
C:\Scripts\EcoTech-AD\
│
├── Start-ADManager.ps1          ← SCRIPT PRINCIPAL
├── Config-EcoTechAD.psd1        ← CONFIGURATION
│
├── Module-Common.psm1            ← Fonctions communes
├── Module-OU.psm1                ← Gestion OUs
├── Module-Groups.psm1            ← Gestion groupes
├── Module-Users.psm1             ← Gestion utilisateurs
├── Module-Computers.psm1         ← Gestion ordinateurs
│
├── README-MODULAIRE.md           ← Documentation complète
└── Fiche_personnels.csv          ← Votre fichier CSV
```

## ⚡ Étape 2 : Lancement

### Option A : Menu Interactif (Recommandé)

```powershell
# 1. Ouvrir PowerShell en Administrateur
# 2. Naviguer vers le dossier
cd C:\Scripts\EcoTech-AD

# 3. Lancer le menu
.\Start-ADManager.ps1

# 4. Utiliser l'option 5 pour le déploiement rapide !
```

### Option B : Ligne de commande directe

```powershell
# Importer les modules
Import-Module .\Module-Common.psm1
Import-Module .\Module-OU.psm1
Import-Module .\Module-Groups.psm1
Import-Module .\Module-Users.psm1
Import-Module .\Module-Computers.psm1

# Charger la config
Import-EcoTechConfig -ConfigPath .\Config-EcoTechAD.psd1
Initialize-LogFile

# Créer tout
New-EcoTechOUStructure
New-EcoTechSecurityGroups
Import-EcoTechUsers -CSVPath .\Fiche_personnels.csv
Import-EcoTechComputers -CSVPath .\Fiche_personnels.csv -ComputerType CX
```

## 🎯 Étape 3 : Vérification

```powershell
# Vérifier les OUs
Get-ADOrganizationalUnit -Filter * -SearchBase "OU=ECOTECH,DC=ecotech,DC=local" | 
    Select-Object Name | Sort-Object Name

# Vérifier les utilisateurs
Get-ADUser -Filter * -SearchBase "OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local" | 
    Select-Object Name, SamAccountName | Format-Table

# Vérifier les groupes
Get-ADGroup -Filter * -SearchBase "OU=SX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local" | 
    Select-Object Name

# Vérifier les ordinateurs
Get-ADComputer -Filter * -SearchBase "OU=WX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local" | 
    Select-Object Name | Sort-Object Name
```

## ⚙️ Personnalisation

### Changer le mot de passe par défaut

Éditer `Config-EcoTechAD.psd1` :
```powershell
DefaultPassword = "VotreMotDePasse2026!"
```

### Ajouter un service

Éditer `Config-EcoTechAD.psd1` :
```powershell
# Dans ServiceMapping
"Nom du Service" = @{Dept="D02"; Code="S08"}

# Dans OUStructure
@{Name="S08"; Description="Nom du Service"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
```

## 📝 Logs

Tous les logs sont dans : `C:\Logs\EcoTech-AD\`

Format : `ADManager-YYYYMMDD-HHmmss.log`

## ❓ Aide

### Menu interactif
```powershell
.\Start-ADManager.ps1
# Puis : I (Informations)
```

### Aide PowerShell
```powershell
Get-Help New-EcoTechOU -Full
Get-Help Import-EcoTechUsers -Examples
```

### Documentation
- `README-MODULAIRE.md` - Documentation complète
- `README-Script-AD.md` - Documentation v1.0 (référence)

## 🎉 C'est prêt !

Vous pouvez maintenant gérer votre Active Directory avec un menu interactif simple et des modules faciles à déboguer !

---

**Support** : Équipe Admin SI - EcoTech Solutions  
**Version** : 2.0 Modulaire  
**Date** : 2026-02-02
