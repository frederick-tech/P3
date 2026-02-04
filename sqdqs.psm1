<#
.SYNOPSIS
    Module de fonctions communes pour la gestion Active Directory d'EcoTech Solutions.
.NOTES
    Correction : Syntaxe Write-EcoLog réparée + Ajout Get-CSVDelimiter
#>

#region Variables globales du module

$Script:Config = $null
$Script:LogFile = $null

#endregion

#region 1. FONCTIONS DE MANIPULATION DE TEXTE

function Get-CleanString {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }

    # 1. Remplacement manuel des ligatures
    $Text = $Text -replace 'œ', 'oe' -replace 'Œ', 'OE' `
                  -replace 'æ', 'ae' -replace 'Æ', 'AE' `
                  -replace 'ß', 'ss' -replace 'ø', 'o' `
                  -replace 'Ø', 'O' `
                  -replace 'ł', 'l' -replace 'Ł', 'L'

    # 2. Normalisation Unicode
    $Text = $Text.Normalize([System.Text.NormalizationForm]::FormD)

    # 3. Suppression des accents
    $Text = $Text -replace '\p{Mn}', ''

    # 4. Nettoyage final (alphanumérique uniquement)
    $Text = $Text -replace '[^a-zA-Z0-9]', ''

    return $Text.ToLower()
}

function Get-CalculatedLogin {
    <#
    .DESCRIPTION
        Génère la BASE du login (2 lettres prénom + nom).
    #>
    param(
        [string]$Prenom, 
        [string]$Nom
    )
    
    $CleanP = Get-CleanString -Text $Prenom
    $CleanN = Get-CleanString -Text $Nom
    
    # Si prénom trop court, on prend tout
    $P2 = if ($CleanP.Length -ge 2) { $CleanP.Substring(0,2) } else { $CleanP }
    
    $BaseLogin = $P2 + $CleanN
    
    # Limitation longueur AD (20 caractères max, on garde une marge)
    if ($BaseLogin.Length -gt 19) {
        $BaseLogin = $BaseLogin.Substring(0, 19)
    }

    return $BaseLogin
}

function Get-CSVDelimiter {
    param([string]$Path)
    # Lit la première ligne pour deviner si c'est ; ou ,
    if (Test-Path $Path) {
        $firstLine = Get-Content $Path -TotalCount 1
        if ($firstLine -match ";") { return ";" } else { return "," }
    }
    return "," # Par défaut
}

#endregion

#region 2. FONCTIONS DE CONFIGURATION

function Import-EcoTechConfig {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        throw "Fichier de configuration introuvable : $ConfigPath"
    }

    try {
        Write-Host "Chargement de la configuration..." 
        
        $RawContent = Get-Content -Path $ConfigPath -Raw -Encoding UTF8
        $Script:Config = Invoke-Expression $RawContent
        
        if (-not ($Script:Config -is [hashtable])) {
            throw "Le fichier n'est pas valide."
        }

        # Détection dynamique du domaine
        try {
            $CurrentAD = Get-ADDomain
            $Script:Config.DomainInfo.Name    = $CurrentAD.DNSRoot 
            $Script:Config.DomainInfo.DN      = $CurrentAD.DistinguishedName
            $Script:Config.DomainInfo.NetBIOS = $CurrentAD.NetBIOSName        
            $Script:Config.DomainInfo.EmailDomain = $CurrentAD.DNSRoot
        } catch {
            Write-Host "Info : Utilisation des valeurs du fichier config (AD non détecté)." -ForegroundColor Gray
        }

        return $Script:Config

    } catch {
        throw "ERREUR FATALE CONFIG : $($_.Exception.Message)"
    }
}

function Get-EcoTechConfig {
    if ($null -eq $Script:Config) {
        throw "La configuration n'a pas été chargée. Lancez Import-EcoTechConfig d'abord."
    }
    return $Script:Config
}
#endregion

#region 3. FONCTION DE LOGGING

function Initialize-LogFile {
    param([string]$LogPath)
    $Script:LogFile = $LogPath
    $Dir = Split-Path -Parent $LogPath
    
    if (-not (Test-Path $Dir)) { 
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null 
    }
    if (-not (Test-Path $LogPath)) { 
        "Date;Level;Message" | Out-File $LogPath -Encoding UTF8 
    }
}

function Write-EcoLog {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [switch]$LogOnly
    )

    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # 1. Écriture Fichier
    if ($Script:LogFile) {
        "$Date;$Level;$Message" | Out-File $Script:LogFile -Append -Encoding UTF8
    }

    # 2. Affichage Console (CORRIGÉ ICI)
    if (-not $LogOnly) {
        $Color = switch ($Level) {
            'Error'   { 'Red' }
            'Success' { 'Green' }
            'Warning' { 'Yellow' }
            Default   { 'Gray' }
        }
        # Cette ligne manquait dans votre version :
        Write-Host "[$Level] $Message" -ForegroundColor $Color
    } # <-- Cette accolade manquait dans votre version

    # 3. Observateur d'événements
    try {
        $EntryType = switch ($Level) { 'Error' { 'Error' } 'Warning' { 'Warning' } Default { 'Information' } }
        Write-EventLog -LogName Application -Source "EcoTechAD" -EntryType $EntryType -EventId 1000 -Message $Message -ErrorAction SilentlyContinue
    } catch {}
}

function Show-EcoTechStatus {
    Write-Host "Domaine: $env:USERDNSDOMAIN | User: $env:USERNAME" 
}

#endregion

# Exporter toutes les fonctions pour qu'elles soient visibles
Export-ModuleMember -Function @(
    'Get-CleanString',
    'Get-CalculatedLogin',
    'Get-CSVDelimiter',
    'Import-EcoTechConfig',
    'Get-EcoTechConfig',
    'Initialize-LogFile',
    'Write-EcoLog',
    'Show-EcoTechStatus'
)
