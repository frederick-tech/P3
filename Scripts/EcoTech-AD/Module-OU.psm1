<#
.SYNOPSIS
    Module de gestion des Unités d'Organisation (OU) pour EcoTech Solutions

.DESCRIPTION
    Ce module permet de gérer l'arborescence complète des OUs :
    - Créer toute l'arborescence depuis la configuration
    - Ajouter une OU individuelle
    - Modifier les propriétés d'une OU
    - Supprimer une OU
    - Lister les OUs

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
#>

# Importer le module commun
Import-Module "$PSScriptRoot\Module-Common.psm1" -Force

#region Fonction principale - Créer l'arborescence complète

function New-EcoTechOUStructure {
    <#
    .SYNOPSIS
        Crée toute l'arborescence OU depuis la configuration
    
    .DESCRIPTION
        Lit la configuration et crée toutes les OUs définies dans OUStructure
    
    .PARAMETER WhatIf
        Mode simulation sans modification réelle
    
    .EXAMPLE
        New-EcoTechOUStructure
    
    .EXAMPLE
        New-EcoTechOUStructure -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    Write-EcoLog -Message "===== CRÉATION DE L'ARBORESCENCE OU =====" -Level Info
    
    try {
        $config = Get-EcoTechConfig
        $ouStructure = $config.OUStructure
        
        $createdCount = 0
        $skippedCount = 0
        $errorCount = 0
        
        foreach ($ou in $ouStructure) {
            try {
                # Construire le DN complet
                if ($ou.Parent) {
                    $fullPath = Get-OUPath -OUPath $ou.Parent
                } else {
                    $fullPath = $config.DomainInfo.DN
                }
                
                # Vérifier si l'OU existe déjà
                $ouDN = if ($ou.Parent) {
                    "OU=$($ou.Name),$($ou.Parent),$($config.DomainInfo.DN)"
                } else {
                    "OU=$($ou.Name),$($config.DomainInfo.DN)"
                }
                
                $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue
                
                if ($existingOU) {
                    Write-EcoLog -Message "OU déjà existante : $($ou.Name)" -Level Warning
                    $skippedCount++
                    continue
                }
                
                # Créer l'OU
                if ($PSCmdlet.ShouldProcess("$($ou.Name) dans $fullPath", "Créer OU")) {
                    if (-not $WhatIf) {
                        New-ADOrganizationalUnit -Name $ou.Name -Path $fullPath `
                            -Description $ou.Description `
                            -ProtectedFromAccidentalDeletion $true `
                            -ErrorAction Stop
                    }
                    
                    Write-EcoLog -Message "OU créée : $($ou.Name) - $($ou.Description)" -Level Success
                    $createdCount++
                }
                
            } catch {
                Write-EcoLog -Message "Erreur création OU $($ou.Name) : $($_.Exception.Message)" -Level Error
                $errorCount++
            }
        }
        
        Write-EcoLog -Message "=== RÉSUMÉ ===" -Level Info
        Write-EcoLog -Message "Créées: $createdCount | Ignorées: $skippedCount | Erreurs: $errorCount" -Level Info
        
    } catch {
        Write-EcoLog -Message "Erreur fatale : $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

#region Gestion individuelle des OUs

function New-EcoTechOU {
    <#
    .SYNOPSIS
        Crée une nouvelle OU
    
    .DESCRIPTION
        Crée une OU avec le nom, description et chemin parent spécifiés
    
    .PARAMETER Name
        Nom de l'OU
    
    .PARAMETER Description
        Description de l'OU
    
    .PARAMETER ParentPath
        Chemin du parent (ex: "OU=UX,OU=BDX,OU=ECOTECH")
    
    .EXAMPLE
        New-EcoTechOU -Name "S08" -Description "Nouveau service" -ParentPath "OU=D02,OU=UX,OU=BDX,OU=ECOTECH"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Description,
        
        [Parameter(Mandatory=$true)]
        [string]$ParentPath
    )
    
    try {
        $fullPath = Get-OUPath -OUPath $ParentPath
        
        # Vérifier si l'OU existe déjà
        $ouDN = "OU=$Name,$fullPath"
        $existing = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue
        
        if ($existing) {
            Write-EcoLog -Message "OU déjà existante : $Name" -Level Warning
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess("$Name dans $fullPath", "Créer OU")) {
            New-ADOrganizationalUnit -Name $Name -Path $fullPath `
                -Description $Description `
                -ProtectedFromAccidentalDeletion $true
            
            Write-EcoLog -Message "OU créée : $Name" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur création OU $Name : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Set-EcoTechOU {
    <#
    .SYNOPSIS
        Modifie une OU existante
    
    .DESCRIPTION
        Permet de modifier la description d'une OU
    
    .PARAMETER Identity
        DN complet de l'OU
    
    .PARAMETER Description
        Nouvelle description
    
    .EXAMPLE
        Set-EcoTechOU -Identity "OU=S01,OU=D01,OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local" -Description "Nouvelle description"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity,
        
        [Parameter(Mandatory=$false)]
        [string]$Description
    )
    
    try {
        $ou = Get-ADOrganizationalUnit -Identity $Identity -ErrorAction Stop
        
        if ($PSCmdlet.ShouldProcess($Identity, "Modifier OU")) {
            if ($Description) {
                Set-ADOrganizationalUnit -Identity $Identity -Description $Description
                Write-EcoLog -Message "OU modifiée : $Identity" -Level Success
            }
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur modification OU : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-EcoTechOU {
    <#
    .SYNOPSIS
        Supprime une OU
    
    .DESCRIPTION
        Supprime une OU après confirmation et désactivation de la protection
    
    .PARAMETER Identity
        DN complet de l'OU
    
    .PARAMETER Recursive
        Supprimer récursivement le contenu
    
    .EXAMPLE
        Remove-EcoTechOU -Identity "OU=S08,OU=D02,OU=UX,OU=BDX,OU=ECOTECH,DC=ecotech,DC=local"
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Identity,
        
        [Parameter(Mandatory=$false)]
        [switch]$Recursive
    )
    
    try {
        $ou = Get-ADOrganizationalUnit -Identity $Identity -Properties ProtectedFromAccidentalDeletion -ErrorAction Stop
        
        # Demander confirmation
        Write-Host ""
        Write-Host "⚠️  ATTENTION : Suppression de l'OU" -ForegroundColor Red
        Write-Host "DN : $Identity" -ForegroundColor Yellow
        
        if ($Recursive) {
            Write-Host "Mode récursif : TOUT le contenu sera supprimé !" -ForegroundColor Red
        }
        
        $confirm = Read-Host "Confirmez-vous la suppression ? (Tapez 'SUPPRIMER' pour confirmer)"
        
        if ($confirm -ne "SUPPRIMER") {
            Write-EcoLog -Message "Suppression annulée par l'utilisateur" -Level Warning
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess($Identity, "Supprimer OU")) {
            # Désactiver la protection
            if ($ou.ProtectedFromAccidentalDeletion) {
                Set-ADOrganizationalUnit -Identity $Identity -ProtectedFromAccidentalDeletion $false
            }
            
            # Supprimer
            if ($Recursive) {
                Remove-ADOrganizationalUnit -Identity $Identity -Recursive -Confirm:$false
            } else {
                Remove-ADOrganizationalUnit -Identity $Identity -Confirm:$false
            }
            
            Write-EcoLog -Message "OU supprimée : $Identity" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur suppression OU : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-EcoTechOUList {
    <#
    .SYNOPSIS
        Liste les OUs
    
    .DESCRIPTION
        Affiche la liste des OUs avec leur hiérarchie
    
    .PARAMETER SearchBase
        Base de recherche (optionnel)
    
    .EXAMPLE
        Get-EcoTechOUList
    
    .EXAMPLE
        Get-EcoTechOUList -SearchBase "OU=ECOTECH,DC=ecotech,DC=local"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$SearchBase
    )
    
    try {
        if (-not $SearchBase) {
            $config = Get-EcoTechConfig
            $SearchBase = "OU=ECOTECH,$($config.DomainInfo.DN)"
        }
        
        $ous = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -Properties CanonicalName, Description |
            Select-Object Name, Description, CanonicalName, DistinguishedName |
            Sort-Object CanonicalName
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " LISTE DES UNITÉS D'ORGANISATION" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Nombre total d'OUs : $($ous.Count)" -ForegroundColor Green
        Write-Host ""
        
        $ous | Format-Table -Property Name, Description, CanonicalName -AutoSize
        
        return $ous
        
    } catch {
        Write-EcoLog -Message "Erreur liste OUs : $($_.Exception.Message)" -Level Error
        return $null
    }
}

#endregion

#region Menu interactif

function Show-OUMenu {
    <#
    .SYNOPSIS
        Affiche le menu de gestion des OUs
    
    .DESCRIPTION
        Menu interactif pour toutes les opérations sur les OUs
    
    .EXAMPLE
        Show-OUMenu
    #>
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Show-Banner
        
        Write-Host "┌────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "│              GESTION DES UNITÉS D'ORGANISATION         │" -ForegroundColor Cyan
        Write-Host "└────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. Créer toute l'arborescence OU" -ForegroundColor White
        Write-Host "  2. Ajouter une OU" -ForegroundColor White
        Write-Host "  3. Modifier une OU" -ForegroundColor White
        Write-Host "  4. Supprimer une OU" -ForegroundColor White
        Write-Host "  5. Lister les OUs" -ForegroundColor White
        Write-Host ""
        Write-Host "  Q. Retour au menu principal" -ForegroundColor Yellow
        Write-Host ""
        
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','4','5','Q')
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Création de l'arborescence complète..." -ForegroundColor Cyan
                $confirm = Read-Host "Confirmer ? (O/N)"
                if ($confirm -eq 'O') {
                    New-EcoTechOUStructure
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '2' {
                Write-Host ""
                Write-Host "=== AJOUT D'UNE OU ===" -ForegroundColor Cyan
                $name = Read-Host "Nom de l'OU"
                $description = Read-Host "Description"
                $parent = Read-Host "Chemin parent (ex: OU=D02,OU=UX,OU=BDX,OU=ECOTECH)"
                
                New-EcoTechOU -Name $name -Description $description -ParentPath $parent
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '3' {
                Write-Host ""
                Write-Host "=== MODIFICATION D'UNE OU ===" -ForegroundColor Cyan
                $identity = Read-Host "DN complet de l'OU"
                $description = Read-Host "Nouvelle description"
                
                Set-EcoTechOU -Identity $identity -Description $description
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '4' {
                Write-Host ""
                Write-Host "=== SUPPRESSION D'UNE OU ===" -ForegroundColor Cyan
                $identity = Read-Host "DN complet de l'OU"
                $recursive = Read-Host "Suppression récursive ? (O/N)"
                
                if ($recursive -eq 'O') {
                    Remove-EcoTechOU -Identity $identity -Recursive
                } else {
                    Remove-EcoTechOU -Identity $identity
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '5' {
                Get-EcoTechOUList
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
        }
        
    } while ($choice -ne 'Q')
}

#endregion

# Exporter les fonctions
Export-ModuleMember -Function @(
    'New-EcoTechOUStructure',
    'New-EcoTechOU',
    'Set-EcoTechOU',
    'Remove-EcoTechOU',
    'Get-EcoTechOUList',
    'Show-OUMenu'
)
