<#
.SYNOPSIS
    Module de fonctions communes pour la gestion AD EcoTech Solutions

.DESCRIPTION
    Ce module contient les fonctions utilitaires partagées par tous les autres modules :
    - Logging
    - Normalisation de chaînes
    - Chargement de la configuration
    - Génération de noms

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
#>

#region Variables globales du module
$Script:Config = $null
$Script:LogFile = $null
#endregion

#region Fonctions de configuration

function Import-EcoTechConfig {
    <#
    .SYNOPSIS
        Charge la configuration depuis le fichier .psd1
    
    .DESCRIPTION
        Importe le fichier de configuration central et le stocke en variable de script
    
    .PARAMETER ConfigPath
        Chemin vers le fichier Config-EcoTechAD.psd1
    
    .EXAMPLE
        Import-EcoTechConfig -ConfigPath "C:\Scripts\Config-EcoTechAD.psd1"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = "$PSScriptRoot\Config-EcoTechAD.psd1"
    )
    
    try {
        if (-not (Test-Path $ConfigPath)) {
            throw "Fichier de configuration introuvable : $ConfigPath"
        }
        
        $Script:Config = Import-PowerShellDataFile -Path $ConfigPath
        Write-Host "✅ Configuration chargée depuis : $ConfigPath" -ForegroundColor Green
        return $Script:Config
        
    } catch {
        Write-Host "❌ Erreur lors du chargement de la configuration : $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-EcoTechConfig {
    <#
    .SYNOPSIS
        Retourne la configuration actuelle
    
    .DESCRIPTION
        Retourne l'objet de configuration chargé en mémoire
    
    .EXAMPLE
        $config = Get-EcoTechConfig
    #>
    [CmdletBinding()]
    param()
    
    if ($null -eq $Script:Config) {
        throw "Configuration non chargée. Utilisez Import-EcoTechConfig d'abord."
    }
    
    return $Script:Config
}

#endregion

#region Fonctions de logging

function Initialize-LogFile {
    <#
    .SYNOPSIS
        Initialise le fichier de log
    
    .DESCRIPTION
        Crée le répertoire de logs si nécessaire et définit le chemin du fichier
    
    .PARAMETER LogPath
        Chemin du répertoire de logs
    
    .EXAMPLE
        Initialize-LogFile -LogPath "C:\Logs\EcoTech-AD"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$LogPath
    )
    
    if (-not $LogPath) {
        $config = Get-EcoTechConfig
        $LogPath = $config.LogPath
    }
    
    # Créer le répertoire si nécessaire
    if (-not (Test-Path $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
    
    # Définir le nom du fichier avec timestamp
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $Script:LogFile = Join-Path $LogPath "ADManager-$timestamp.log"
    
    Write-Host "📝 Logs : $Script:LogFile" -ForegroundColor Cyan
}

function Write-EcoLog {
    <#
    .SYNOPSIS
        Écrit un message dans le fichier de log et à l'écran
    
    .DESCRIPTION
        Écrit un message horodaté dans le log avec niveau de gravité
    
    .PARAMETER Message
        Message à enregistrer
    
    .PARAMETER Level
        Niveau : Info, Success, Warning, Error
    
    .EXAMPLE
        Write-EcoLog -Message "Utilisateur créé" -Level Success
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Info','Success','Warning','Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Écrire dans le fichier si initialisé
    if ($Script:LogFile) {
        Add-Content -Path $Script:LogFile -Value $logMessage
    }
    
    # Afficher à l'écran avec couleur
    $color = switch ($Level) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
        default   { 'White' }
    }
    
    Write-Host $logMessage -ForegroundColor $color
}

#endregion

#region Fonctions de normalisation

function Get-NormalizedString {
    <#
    .SYNOPSIS
        Normalise une chaîne de caractères
    
    .DESCRIPTION
        Supprime les accents, caractères spéciaux et convertit en minuscules
    
    .PARAMETER InputString
        Chaîne à normaliser
    
    .EXAMPLE
        Get-NormalizedString -InputString "Éléonore"
        # Retourne: "eleonore"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    
    # Supprimer les accents
    $normalized = $InputString.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object Text.StringBuilder
    
    foreach ($char in $normalized.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($char)
        }
    }
    
    # Supprimer caractères spéciaux et espaces
    $result = $sb.ToString()
    $result = $result -replace '[^a-zA-Z0-9]', ''
    
    return $result.ToLower()
}

#endregion

#region Fonctions de génération de noms

function New-SamAccountName {
    <#
    .SYNOPSIS
        Génère un SamAccountName unique
    
    .DESCRIPTION
        Crée un nom d'utilisateur au format prenom.nom avec gestion des doublons
    
    .PARAMETER Prenom
        Prénom de l'utilisateur
    
    .PARAMETER Nom
        Nom de l'utilisateur
    
    .EXAMPLE
        New-SamAccountName -Prenom "Jean" -Nom "Dupont"
        # Retourne: "jean.dupont" (ou "jean.dupont2" si doublon)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        
        [Parameter(Mandatory=$true)]
        [string]$Nom
    )
    
    $prenomClean = Get-NormalizedString -InputString $Prenom
    $nomClean = Get-NormalizedString -InputString $Nom
    
    $samBase = "$prenomClean.$nomClean"
    $samAccount = $samBase
    $counter = 2
    
    # Vérifier l'unicité
    while (Get-ADUser -Filter "SamAccountName -eq '$samAccount'" -ErrorAction SilentlyContinue) {
        $samAccount = "$samBase$counter"
        $counter++
    }
    
    return $samAccount
}

function New-EmailAddress {
    <#
    .SYNOPSIS
        Génère une adresse email
    
    .DESCRIPTION
        Crée une adresse au format <2lettres><nom>@ecotechsolutions.fr
    
    .PARAMETER Prenom
        Prénom de l'utilisateur
    
    .PARAMETER Nom
        Nom de l'utilisateur
    
    .EXAMPLE
        New-EmailAddress -Prenom "Jean" -Nom "Dupont"
        # Retourne: "jedupont@ecotechsolutions.fr"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        
        [Parameter(Mandatory=$true)]
        [string]$Nom
    )
    
    $config = Get-EcoTechConfig
    
    $prenomClean = Get-NormalizedString -InputString $Prenom
    $nomClean = Get-NormalizedString -InputString $Nom
    
    # Prendre les 2 premières lettres du prénom
    $prenomPrefix = $prenomClean.Substring(0, [Math]::Min(2, $prenomClean.Length))
    
    return "$prenomPrefix$nomClean@$($config.DomainInfo.EmailDomain)"
}

function New-ComputerName {
    <#
    .SYNOPSIS
        Génère un nom d'ordinateur selon la nomenclature
    
    .DESCRIPTION
        Crée un nom au format ECO-BDX-TYPE### (ex: ECO-BDX-CX001)
    
    .PARAMETER Type
        Type de machine : BX (fixe), CX (portable), EX (serveur), FX (appliance), GX (admin)
    
    .PARAMETER NextNumber
        Prochain numéro disponible (optionnel, sinon auto-détection)
    
    .EXAMPLE
        New-ComputerName -Type "CX"
        # Retourne: "ECO-BDX-CX001" (ou le prochain numéro disponible)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('BX','CX','EX','FX','GX')]
        [string]$Type,
        
        [Parameter(Mandatory=$false)]
        [int]$NextNumber
    )
    
    # Si le numéro n'est pas fourni, trouver le prochain disponible
    if (-not $NextNumber) {
        $prefix = "ECO-BDX-$Type"
        $existing = Get-ADComputer -Filter "Name -like '$prefix*'" -ErrorAction SilentlyContinue
        
        if ($existing) {
            # Extraire les numéros et trouver le maximum
            $numbers = $existing | ForEach-Object {
                if ($_.Name -match "$prefix(\d+)$") {
                    [int]$matches[1]
                }
            }
            $NextNumber = ($numbers | Measure-Object -Maximum).Maximum + 1
        } else {
            $NextNumber = 1
        }
    }
    
    # Formater avec 3 chiffres
    return "ECO-BDX-{0}{1:D3}" -f $Type, $NextNumber
}

#endregion

#region Fonctions de navigation AD

function Get-OUPath {
    <#
    .SYNOPSIS
        Construit le DN complet d'une OU
    
    .DESCRIPTION
        Génère le Distinguished Name complet pour une OU
    
    .PARAMETER OUPath
        Chemin relatif de l'OU (ex: "OU=S01,OU=D01,OU=UX,OU=BDX,OU=ECOTECH")
    
    .EXAMPLE
        Get-OUPath -OUPath "OU=S01,OU=D01,OU=UX,OU=BDX,OU=ECOTECH"
        # Retourne: "OU=S01,OU=D01,OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OUPath
    )
    
    $config = Get-EcoTechConfig
    
    if ($OUPath) {
        return "$OUPath,$($config.DomainInfo.DN)"
    } else {
        return $config.DomainInfo.DN
    }
}

#endregion

#region Fonctions d'affichage

function Show-Banner {
    <#
    .SYNOPSIS
        Affiche la bannière du programme
    
    .DESCRIPTION
        Affiche une bannière stylisée pour l'application
    
    .EXAMPLE
        Show-Banner
    #>
    [CmdletBinding()]
    param()
    
    Clear-Host
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║     GESTIONNAIRE ACTIVE DIRECTORY - ECOTECH SOLUTIONS    ║" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "║                    Version 2.0                           ║" -ForegroundColor Cyan
    Write-Host "║                                                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-StatusBar {
    <#
    .SYNOPSIS
        Affiche une barre de statut
    
    .DESCRIPTION
        Affiche les informations de connexion au domaine
    
    .EXAMPLE
        Show-StatusBar
    #>
    [CmdletBinding()]
    param()
    
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        $config = Get-EcoTechConfig
        
        Write-Host "┌────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
        Write-Host "│ Domaine : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$($domain.DNSRoot)" -NoNewline -ForegroundColor Green
        Write-Host (" " * (41 - $domain.DNSRoot.Length)) -NoNewline
        Write-Host "│" -ForegroundColor DarkGray
        
        Write-Host "│ Utilisateur : " -NoNewline -ForegroundColor DarkGray
        Write-Host "$env:USERNAME" -NoNewline -ForegroundColor Yellow
        Write-Host (" " * (37 - $env:USERNAME.Length)) -NoNewline
        Write-Host "│" -ForegroundColor DarkGray
        
        Write-Host "└────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
        Write-Host ""
        
    } catch {
        Write-Host "⚠️  Non connecté au domaine" -ForegroundColor Red
        Write-Host ""
    }
}

function Read-Choice {
    <#
    .SYNOPSIS
        Lit un choix utilisateur
    
    .DESCRIPTION
        Affiche un prompt et attend la saisie utilisateur
    
    .PARAMETER Prompt
        Message à afficher
    
    .PARAMETER ValidChoices
        Tableau des choix valides
    
    .EXAMPLE
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','Q')
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ValidChoices
    )
    
    do {
        Write-Host ""
        Write-Host $Prompt -NoNewline -ForegroundColor Cyan
        Write-Host " : " -NoNewline
        $choice = Read-Host
        
        if ($ValidChoices -and $choice -notin $ValidChoices) {
            Write-Host "❌ Choix invalide. Veuillez réessayer." -ForegroundColor Red
        }
    } while ($ValidChoices -and $choice -notin $ValidChoices)
    
    return $choice
}

#endregion

# Exporter les fonctions
Export-ModuleMember -Function @(
    'Import-EcoTechConfig',
    'Get-EcoTechConfig',
    'Initialize-LogFile',
    'Write-EcoLog',
    'Get-NormalizedString',
    'New-SamAccountName',
    'New-EmailAddress',
    'New-ComputerName',
    'Get-OUPath',
    'Show-Banner',
    'Show-StatusBar',
    'Read-Choice'
)
