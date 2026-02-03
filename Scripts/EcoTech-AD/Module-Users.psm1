<#
.SYNOPSIS
    Module de gestion des utilisateurs pour EcoTech Solutions

.DESCRIPTION
    Ce module permet de gérer les comptes utilisateurs :
    - Importer depuis CSV
    - Créer un utilisateur
    - Modifier un utilisateur
    - Désactiver/Supprimer un utilisateur
    - Mettre à jour depuis CSV

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
#>

# Importer le module commun
Import-Module "$PSScriptRoot\Module-Common.psm1" -Force

#region Importation depuis CSV

function Import-EcoTechUsers {
    <#
    .SYNOPSIS
        Importe les utilisateurs depuis un fichier CSV
    
    .DESCRIPTION
        Lit le CSV et crée tous les utilisateurs dans les bonnes OUs
    
    .PARAMETER CSVPath
        Chemin du fichier CSV
    
    .PARAMETER UpdateExisting
        Si présent, met à jour les utilisateurs existants
    
    .EXAMPLE
        Import-EcoTechUsers -CSVPath "C:\Import\Fiche_personnels.csv"
    
    .EXAMPLE
        Import-EcoTechUsers -CSVPath "C:\Import\Fiche_personnels.csv" -UpdateExisting
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$CSVPath,
        
        [Parameter(Mandatory=$false)]
        [switch]$UpdateExisting
    )
    
    Write-EcoLog -Message "===== IMPORTATION DES UTILISATEURS =====" -Level Info
    Write-EcoLog -Message "Fichier : $CSVPath" -Level Info
    
    try {
        # Lire la configuration
        $config = Get-EcoTechConfig
        $defaultPassword = ConvertTo-SecureString $config.DefaultPassword -AsPlainText -Force
        
        # Importer le CSV
        $users = Import-Csv -Path $CSVPath -Delimiter ";" -Encoding UTF8
        Write-EcoLog -Message "Nombre d'utilisateurs dans le CSV : $($users.Count)" -Level Info
        
        $createdCount = 0
        $updatedCount = 0
        $skippedCount = 0
        $errorCount = 0
        
        foreach ($user in $users) {
            try {
                # Validation des données
                if (-not $user.Prenom -or -not $user.Nom) {
                    Write-EcoLog -Message "Ligne ignorée : Prénom ou Nom manquant" -Level Warning
                    $skippedCount++
                    continue
                }
                
                # Générer les identifiants
                $samAccountName = New-SamAccountName -Prenom $user.Prenom -Nom $user.Nom
                $emailAddress = New-EmailAddress -Prenom $user.Prenom -Nom $user.Nom
                $displayName = "$($user.Prenom) $($user.Nom)"
                $userPrincipalName = "$samAccountName@$($config.DomainInfo.Name)"
                
                # Déterminer le département
                $deptCode = $config.DepartmentMapping[$user.Departement]
                if (-not $deptCode) {
                    Write-EcoLog -Message "Département non trouvé pour $displayName : $($user.Departement)" -Level Warning
                    $deptCode = "D04"  # Par défaut Direction
                }
                
                # Déterminer le service
                $serviceInfo = $config.ServiceMapping[$user.Service]
                if ($serviceInfo) {
                    $serviceCode = $serviceInfo.Code
                } else {
                    Write-EcoLog -Message "Service non trouvé pour $displayName : $($user.Service)" -Level Warning
                    $serviceCode = "S01"
                }
                
                # Construire le chemin OU
                $ouPath = "OU=$serviceCode,OU=$deptCode,OU=UX,OU=BDX,OU=ECOTECH"
                $fullOUPath = Get-OUPath -OUPath $ouPath
                
                # Vérifier si l'utilisateur existe
                $existingUser = Get-ADUser -Filter "SamAccountName -eq '$samAccountName'" -ErrorAction SilentlyContinue
                
                if ($existingUser) {
                    if ($UpdateExisting) {
                        # Mise à jour
                        if ($PSCmdlet.ShouldProcess($samAccountName, "Mettre à jour utilisateur")) {
                            Set-ADUser -Identity $samAccountName `
                                -EmailAddress $emailAddress `
                                -Department $user.Departement `
                                -Title $user.fonction `
                                -OfficePhone $user.'Telephone fixe' `
                                -MobilePhone $user.'Telephone portable' `
                                -ErrorAction Stop
                            
                            Write-EcoLog -Message "Utilisateur mis à jour : $samAccountName" -Level Success
                            $updatedCount++
                        }
                    } else {
                        Write-EcoLog -Message "Utilisateur déjà existant : $samAccountName" -Level Warning
                        $skippedCount++
                    }
                    continue
                }
                
                # Créer le nouvel utilisateur
                if ($PSCmdlet.ShouldProcess($samAccountName, "Créer utilisateur")) {
                    $userParams = @{
                        Name = $displayName
                        GivenName = $user.Prenom
                        Surname = $user.Nom
                        SamAccountName = $samAccountName
                        UserPrincipalName = $userPrincipalName
                        EmailAddress = $emailAddress
                        DisplayName = $displayName
                        Path = $fullOUPath
                        AccountPassword = $defaultPassword
                        ChangePasswordAtLogon = $true
                        Enabled = $true
                        Department = $user.Departement
                        Title = $user.fonction
                        Company = "EcoTech Solutions"
                        Office = $user.Site
                    }
                    
                    # Ajouter téléphones si présents
                    if ($user.'Telephone fixe') {
                        $userParams.OfficePhone = $user.'Telephone fixe'
                    }
                    if ($user.'Telephone portable') {
                        $userParams.MobilePhone = $user.'Telephone portable'
                    }
                    
                    New-ADUser @userParams -ErrorAction Stop
                    Write-EcoLog -Message "Utilisateur créé : $samAccountName ($displayName)" -Level Success
                    $createdCount++
                    
                    # Ajouter aux groupes
                    Add-UserToGroups -SamAccountName $samAccountName -DepartmentCode $deptCode
                }
                
            } catch {
                Write-EcoLog -Message "Erreur traitement $($user.Prenom) $($user.Nom) : $($_.Exception.Message)" -Level Error
                $errorCount++
            }
        }
        
        Write-EcoLog -Message "=== RÉSUMÉ IMPORTATION ===" -Level Info
        Write-EcoLog -Message "Créés: $createdCount | Mis à jour: $updatedCount | Ignorés: $skippedCount | Erreurs: $errorCount" -Level Info
        
    } catch {
        Write-EcoLog -Message "Erreur fatale : $($_.Exception.Message)" -Level Error
    }
}

function Add-UserToGroups {
    <#
    .SYNOPSIS
        Ajoute un utilisateur aux groupes appropriés
    
    .PARAMETER SamAccountName
        SamAccountName de l'utilisateur
    
    .PARAMETER DepartmentCode
        Code du département (D01-D07)
    
    .EXAMPLE
        Add-UserToGroups -SamAccountName "jean.dupont" -DepartmentCode "D01"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName,
        
        [Parameter(Mandatory=$true)]
        [string]$DepartmentCode
    )
    
    $deptGroupMapping = @{
        "D01" = "GRP_D01_RH"
        "D02" = "GRP_D02_COMMERCIAL"
        "D03" = "GRP_D03_COMMUNICATION"
        "D04" = "GRP_D04_DIRECTION"
        "D05" = "GRP_D05_DEVELOPPEMENT"
        "D06" = "GRP_D06_FINANCE"
        "D07" = "GRP_D07_DSI"
    }
    
    try {
        # Ajouter au groupe départemental
        $deptGroup = $deptGroupMapping[$DepartmentCode]
        if ($deptGroup) {
            Add-ADGroupMember -Identity $deptGroup -Members $SamAccountName -ErrorAction SilentlyContinue
            Write-EcoLog -Message "  → Ajouté au groupe : $deptGroup" -Level Info
        }
        
        # Ajouter au groupe "Tous les utilisateurs"
        Add-ADGroupMember -Identity "GRP_TOUS_UTILISATEURS" -Members $SamAccountName -ErrorAction SilentlyContinue
        
    } catch {
        Write-EcoLog -Message "Erreur ajout aux groupes : $($_.Exception.Message)" -Level Warning
    }
}

#endregion

#region Gestion individuelle

function New-EcoTechUser {
    <#
    .SYNOPSIS
        Crée un utilisateur manuellement
    
    .DESCRIPTION
        Crée un utilisateur avec les paramètres spécifiés
    
    .PARAMETER Prenom
        Prénom de l'utilisateur
    
    .PARAMETER Nom
        Nom de l'utilisateur
    
    .PARAMETER Departement
        Département (ex: "Service Commercial")
    
    .PARAMETER Service
        Service (ex: "B2B")
    
    .EXAMPLE
        New-EcoTechUser -Prenom "Jean" -Nom "Dupont" -Departement "Service Commercial" -Service "B2B"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prenom,
        
        [Parameter(Mandatory=$true)]
        [string]$Nom,
        
        [Parameter(Mandatory=$true)]
        [string]$Departement,
        
        [Parameter(Mandatory=$false)]
        [string]$Service,
        
        [Parameter(Mandatory=$false)]
        [string]$Fonction
    )
    
    try {
        $config = Get-EcoTechConfig
        
        # Générer identifiants
        $samAccountName = New-SamAccountName -Prenom $Prenom -Nom $Nom
        $emailAddress = New-EmailAddress -Prenom $Prenom -Nom $Nom
        $displayName = "$Prenom $Nom"
        $userPrincipalName = "$samAccountName@$($config.DomainInfo.Name)"
        $defaultPassword = ConvertTo-SecureString $config.DefaultPassword -AsPlainText -Force
        
        # Déterminer département et service
        $deptCode = $config.DepartmentMapping[$Departement]
        if (-not $deptCode) {
            Write-EcoLog -Message "Département invalide : $Departement" -Level Error
            return $false
        }
        
        $serviceInfo = $config.ServiceMapping[$Service]
        $serviceCode = if ($serviceInfo) { $serviceInfo.Code } else { "S01" }
        
        # Chemin OU
        $ouPath = "OU=$serviceCode,OU=$deptCode,OU=UX,OU=BDX,OU=ECOTECH"
        $fullOUPath = Get-OUPath -OUPath $ouPath
        
        # Créer l'utilisateur
        if ($PSCmdlet.ShouldProcess($samAccountName, "Créer utilisateur")) {
            $userParams = @{
                Name = $displayName
                GivenName = $Prenom
                Surname = $Nom
                SamAccountName = $samAccountName
                UserPrincipalName = $userPrincipalName
                EmailAddress = $emailAddress
                DisplayName = $displayName
                Path = $fullOUPath
                AccountPassword = $defaultPassword
                ChangePasswordAtLogon = $true
                Enabled = $true
                Department = $Departement
                Title = $Fonction
                Company = "EcoTech Solutions"
            }
            
            New-ADUser @userParams -ErrorAction Stop
            Write-EcoLog -Message "Utilisateur créé : $samAccountName" -Level Success
            
            # Ajouter aux groupes
            Add-UserToGroups -SamAccountName $samAccountName -DepartmentCode $deptCode
            
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur création utilisateur : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Disable-EcoTechUser {
    <#
    .SYNOPSIS
        Désactive un utilisateur
    
    .PARAMETER SamAccountName
        SamAccountName de l'utilisateur
    
    .EXAMPLE
        Disable-EcoTechUser -SamAccountName "jean.dupont"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SamAccountName
    )
    
    try {
        $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($SamAccountName, "Désactiver utilisateur")) {
            Disable-ADAccount -Identity $user
            Write-EcoLog -Message "Utilisateur désactivé : $SamAccountName" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur désactivation : $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Menu interactif

function Show-UserMenu {
    <#
    .SYNOPSIS
        Affiche le menu de gestion des utilisateurs
    #>
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Show-Banner
        
        Write-Host "┌────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│              GESTION DES UTILISATEURS                  │" -ForegroundColor Cyan
        Write-Host "└────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Importer depuis CSV (créer nouveaux)" -ForegroundColor White
        Write-Host "  2. Importer depuis CSV (mettre à jour existants)" -ForegroundColor White
        Write-Host "  3. Créer un utilisateur manuellement" -ForegroundColor White
        Write-Host "  4. Désactiver un utilisateur" -ForegroundColor White
        Write-Host ""
        Write-Host "  Q. Retour au menu principal" -ForegroundColor Yellow
        Write-Host ""
        
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','4','Q')
        
        switch ($choice) {
            '1' {
                Write-Host ""
                $csvPath = Read-Host "Chemin du fichier CSV"
                if (Test-Path $csvPath) {
                    Import-EcoTechUsers -CSVPath $csvPath
                } else {
                    Write-Host "❌ Fichier introuvable" -ForegroundColor Red
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '2' {
                Write-Host ""
                $csvPath = Read-Host "Chemin du fichier CSV"
                if (Test-Path $csvPath) {
                    Import-EcoTechUsers -CSVPath $csvPath -UpdateExisting
                } else {
                    Write-Host "❌ Fichier introuvable" -ForegroundColor Red
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '3' {
                Write-Host ""
                Write-Host "=== CRÉATION MANUELLE ===" -ForegroundColor Cyan
                $prenom = Read-Host "Prénom"
                $nom = Read-Host "Nom"
                $dept = Read-Host "Département (ex: Service Commercial)"
                $service = Read-Host "Service (optionnel)"
                $fonction = Read-Host "Fonction (optionnel)"
                
                New-EcoTechUser -Prenom $prenom -Nom $nom -Departement $dept -Service $service -Fonction $fonction
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '4' {
                Write-Host ""
                $sam = Read-Host "SamAccountName de l'utilisateur"
                Disable-EcoTechUser -SamAccountName $sam
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
        }
        
    } while ($choice -ne 'Q')
}

#endregion

# Exporter les fonctions
Export-ModuleMember -Function @(
    'Import-EcoTechUsers',
    'New-EcoTechUser',
    'Disable-EcoTechUser',
    'Show-UserMenu'
)
