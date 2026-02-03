<#
.SYNOPSIS
    Gestionnaire Active Directory - EcoTech Solutions

.DESCRIPTION
    Menu principal pour la gestion complète de l'Active Directory :
    - Gestion des OUs (arborescence)
    - Gestion des groupes de sécurité
    - Gestion des utilisateurs (importation CSV, création manuelle)
    - Gestion des ordinateurs (nomenclature ECO-BDX-XX###)

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
    
.EXAMPLE
    .\Start-ADManager.ps1
#>

[CmdletBinding()]
param()

# Définir le chemin du répertoire des scripts
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Importer tous les modules
try {
    Import-Module "$ScriptRoot\Module-Common.psm1" -Force -ErrorAction Stop
    Import-Module "$ScriptRoot\Module-OU.psm1" -Force -ErrorAction Stop
    Import-Module "$ScriptRoot\Module-Groups.psm1" -Force -ErrorAction Stop
    Import-Module "$ScriptRoot\Module-Users.psm1" -Force -ErrorAction Stop
    Import-Module "$ScriptRoot\Module-Computers.psm1" -Force -ErrorAction Stop
} catch {
    Write-Host "Erreur lors du chargement des modules : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Vérifiez que tous les fichiers .psm1 sont présents dans : $ScriptRoot" 
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

#region Fonctions d'initialisation

function Initialize-ADManager {
    <#
    .SYNOPSIS
        Initialise le gestionnaire AD
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Charger la configuration
        $configPath = Join-Path $ScriptRoot "Config-EcoTechAD.psd1"
        Import-EcoTechConfig -ConfigPath $configPath | Out-Null
        
        # Initialiser le logging
        Initialize-LogFile
        
        # Vérifier le module ActiveDirectory
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            throw "Le module ActiveDirectory n'est pas installé. Installez les outils RSAT."
        }
        
        Import-Module ActiveDirectory -ErrorAction Stop
        
        # Vérifier la connexion au domaine
        try {
            $domain = Get-ADDomain -ErrorAction Stop
            Write-EcoLog -Message "Connecté au domaine : $($domain.DNSRoot)" -Level Success
        } catch {
            Write-Host "Attention : Non connecté au domaine AD" 
            Write-Host "Certaines fonctionnalités ne seront pas disponibles." 
            Write-Host ""
        }
        
        return $true
        
    } catch {
        Write-Host "Erreur d'initialisation : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

#endregion

#region Menu principal

function Show-MainMenu {
    <#
    .SYNOPSIS
        Affiche le menu principal
    #>
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Show-Banner
        Show-StatusBar
        
        Write-Host "┌────────────────────────────────────────────────────────┐" 
        Write-Host "│                    MENU PRINCIPAL                      │" 
        Write-Host "└────────────────────────────────────────────────────────┘" 
        Write-Host ""
        Write-Host "  1. Gestion des Unités Organisationnelles" 
        Write-Host "  2. Gestion des Groupes de Sécurité" 
        Write-Host "  3. Gestion des Utilisateurs" 
        Write-Host "  4. Gestion des Ordinateurs" 
        Write-Host "  5. Déploiement rapide" 
        Write-Host "  I. Informations" 
        Write-Host "  Q. Quitter" 
        Write-Host ""
        
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','4','5','I','Q')
        
        switch ($choice) {
            '1' {
                Show-OUMenu
            }
            
            '2' {
                Show-GroupMenu
            }
            
            '3' {
                Show-UserMenu
            }
            
            '4' {
                Show-ComputerMenu
            }
            
            '5' {
                Show-QuickDeployMenu
            }
            
            'I' {
                Show-InfoMenu
            }
        }
        
    } while ($choice -ne 'Q')
    
    Write-Host ""
    Write-Host "Au revoir !" 
    Write-Host ""
}

function Show-QuickDeployMenu {
    <#
    .SYNOPSIS
        Menu de déploiement rapide complet
    #>
    [CmdletBinding()]
    param()
    
    Clear-Host
    Show-Banner
    
    Write-Host "┌────────────────────────────────────────────────────────┐" 
    Write-Host "│                DÉPLOIEMENT RAPIDE COMPLET              │" 
    Write-Host "└────────────────────────────────────────────────────────┘" 
    Write-Host ""
    Write-Host "Cette option va exécuter dans l'ordre :"
    Write-Host ""
    Write-Host "  1️.  Création de l'arborescence OU complète"
    Write-Host "  2️.  Création des groupes de sécurité"
    Write-Host "  3️.  Importation des utilisateurs depuis le fichier .csv"
    Write-Host "  4️.  Importation des ordinateurs depuis le fichier .csv"
    Write-Host ""
    Write-Host "ATTENTION : Cette opération est irréversible !"
    Write-Host ""
    
    $confirm = Read-Host "Continuer ? (Tapez 'OUI' pour confirmer)"
    
    if ($confirm -ne 'OUI') {
        Write-Host "Opération annulée" -ForegroundColor Yellow
        Read-Host "`nAppuyez sur Entrée pour continuer"
        return
    }
    
    # Demander le chemin du CSV
    Write-Host ""
    $csvPath = Read-Host "Chemin du fichier CSV des utilisateurs"
    
    if (-not (Test-Path $csvPath)) {
        Write-Host "Fichier introuvable : $csvPath"
        Read-Host "`nAppuyez sur Entrée pour continuer"
        return
    }
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════" 
    Write-Host "               DÉMARRAGE DU DÉPLOIEMENT" 
    Write-Host "════════════════════════════════════════════════════════" 
    Write-Host ""
    
    # Étape 1 : OUs
    Write-Host "Étape 1/4 : Création de l'arborescence OU..." 
    New-EcoTechOUStructure
    Start-Sleep -Seconds 2
    
    # Étape 2 : Groupes
    Write-Host ""
    Write-Host "Étape 2/4 : Création des groupes de sécurité..." 
    New-EcoTechSecurityGroups
    Start-Sleep -Seconds 2
    
    # Étape 3 : Utilisateurs
    Write-Host ""
    Write-Host "Étape 3/4 : Importation des utilisateurs..." 
    Import-EcoTechUsers -CSVPath $csvPath
    Start-Sleep -Seconds 2
    
    # Étape 4 : Ordinateurs
    Write-Host ""
    Write-Host "Étape 4/4 : Importation des ordinateurs..." 
    Import-EcoTechComputers -CSVPath $csvPath -ComputerType CX
    
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════" 
    Write-Host "           DÉPLOIEMENT TERMINÉ AVEC SUCCÈS" 
    Write-Host "════════════════════════════════════════════════════════" 
    Write-Host ""
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

function Show-InfoMenu {
    <#
    .SYNOPSIS
        Affiche les informations sur l'application
    #>
    [CmdletBinding()]
    param()
    
    Clear-Host
    Show-Banner
    
    Write-Host "┌────────────────────────────────────────────────────────┐" 
    Write-Host "│                    INFORMATIONS                        │" 
    Write-Host "└────────────────────────────────────────────────────────┘" 
    Write-Host ""
    
    try {
        $config = Get-EcoTechConfig
        
        Write-Host "CONFIGURATION" 
        Write-Host "  Domaine : " -NoNewline
        Write-Host "$($config.DomainInfo.Name)" 
        Write-Host "  Email : " -NoNewline
        Write-Host "@$($config.DomainInfo.EmailDomain)"
        Write-Host ""
        
        Write-Host "MODULES CHARGÉS" 
        Write-Host "  Module-Common.psm1 (Fonctions utilitaires)"
        Write-Host "  Module-OU.psm1 (Gestion OUs)"
        Write-Host "  Module-Groups.psm1 (Gestion groupes)"
        Write-Host "  Module-Users.psm1 (Gestion utilisateurs)"
        Write-Host "  Module-Computers.psm1 (Gestion ordinateurs)"
        Write-Host ""
        
        Write-Host "STATISTIQUES AD" -ForegroundColor Yellow
        try {
            $ouCount = (Get-ADOrganizationalUnit -Filter * -SearchBase "OU=ECOTECH,$($config.DomainInfo.DN)").Count
            Write-Host "  OUs : " -NoNewline
            Write-Host "$ouCount" 
        } catch {
            Write-Host "  OUs : Non disponible" 
        }
        
        try {
            $userCount = (Get-ADUser -Filter * -SearchBase "OU=UX,OU=BDX,OU=ECOTECH,$($config.DomainInfo.DN)").Count
            Write-Host "  Utilisateurs : " -NoNewline
            Write-Host "$userCount" 
        } catch {
            Write-Host "  Utilisateurs : Non disponible" 
        }
        
        try {
            $groupCount = (Get-ADGroup -Filter * -SearchBase "OU=SX,OU=BDX,OU=ECOTECH,$($config.DomainInfo.DN)").Count
            Write-Host "  Groupes : " -NoNewline
            Write-Host "$groupCount" 
        } catch {
            Write-Host "  Groupes : Non disponible" 
        }
        
        try {
            $computerCount = (Get-ADComputer -Filter * -SearchBase "OU=WX,OU=BDX,OU=ECOTECH,$($config.DomainInfo.DN)").Count
            Write-Host "  Ordinateurs : " -NoNewline
            Write-Host "$computerCount" 
        } catch {
            Write-Host "  Ordinateurs : Non disponible" 
        }
        
        Write-Host ""
        Write-Host "LOGS" 
        Write-Host "  Fichier actuel : " 
        Write-Host "  $Script:LogFile" 
        Write-Host ""
        
        Write-Host "AIDE" 
        Write-Host "  Pour plus d'informations, consultez :"
        Write-Host "  - README-Script-AD.md" 
        Write-Host "  - GUIDE-UTILISATION.md" 
        Write-Host ""
        
    } catch {
        Write-Host "Erreur lors de la récupération des informations" -ForegroundColor Red
    }
    
    Read-Host "Appuyez sur Entrée pour continuer"
}

#endregion

#region Point d'entrée principal

# Initialiser
if (-not (Initialize-ADManager)) {
    Write-Host ""
    Write-Host "Impossible de démarrer le gestionnaire AD" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

# Afficher le menu principal
Show-MainMenu

#endregion
