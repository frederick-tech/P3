<#
.SYNOPSIS
    Module de gestion des groupes de sécurité pour EcoTech Solutions

.DESCRIPTION
    Ce module permet de gérer les groupes de sécurité :
    - Créer les groupes départementaux
    - Ajouter un groupe
    - Modifier un groupe
    - Supprimer un groupe
    - Gérer les membres

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
#>

# Importer le module commun
Import-Module "$PSScriptRoot\Module-Common.psm1" -Force

#region Création des groupes

function New-EcoTechSecurityGroups {
    <#
    .SYNOPSIS
        Crée tous les groupes de sécurité
    
    .DESCRIPTION
        Crée les groupes par département dans la structure SX
    
    .PARAMETER WhatIf
        Mode simulation
    
    .EXAMPLE
        New-EcoTechSecurityGroups
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$WhatIf
    )
    
    Write-EcoLog -Message "===== CRÉATION DES GROUPES DE SÉCURITÉ =====" -Level Info
    
    try {
        $config = Get-EcoTechConfig
        
        # Définir les groupes à créer
        $groups = @(
            # Groupes départementaux
            @{Name="GRP_D01_RH"; Path="OU=D01,OU=SX,OU=BDX,OU=ECOTECH"; Description="Ressources Humaines"}
            @{Name="GRP_D02_COMMERCIAL"; Path="OU=D02,OU=SX,OU=BDX,OU=ECOTECH"; Description="Service Commercial"}
            @{Name="GRP_D03_COMMUNICATION"; Path="OU=D03,OU=SX,OU=BDX,OU=ECOTECH"; Description="Communication"}
            @{Name="GRP_D04_DIRECTION"; Path="OU=D04,OU=SX,OU=BDX,OU=ECOTECH"; Description="Direction"}
            @{Name="GRP_D05_DEVELOPPEMENT"; Path="OU=D05,OU=SX,OU=BDX,OU=ECOTECH"; Description="Développement"}
            @{Name="GRP_D06_FINANCE"; Path="OU=D06,OU=SX,OU=BDX,OU=ECOTECH"; Description="Finance et Comptabilité"}
            @{Name="GRP_D07_DSI"; Path="OU=D07,OU=SX,OU=BDX,OU=ECOTECH"; Description="DSI"}
            
            # Groupes fonctionnels
            @{Name="GRP_TOUS_UTILISATEURS"; Path="OU=SX,OU=BDX,OU=ECOTECH"; Description="Tous les utilisateurs"}
            @{Name="GRP_MANAGERS"; Path="OU=SX,OU=BDX,OU=ECOTECH"; Description="Tous les managers"}
            @{Name="GRP_DEVELOPPEURS"; Path="OU=SX,OU=BDX,OU=ECOTECH"; Description="Tous les développeurs"}
            @{Name="GRP_ADMINS_SI"; Path="OU=SX,OU=BDX,OU=ECOTECH"; Description="Administrateurs SI"}
        )
        
        $createdCount = 0
        $skippedCount = 0
        
        foreach ($group in $groups) {
            try {
                # Construire le chemin complet
                $fullPath = Get-OUPath -OUPath $group.Path
                
                # Vérifier si le groupe existe
                $existing = Get-ADGroup -Filter "Name -eq '$($group.Name)'" -ErrorAction SilentlyContinue
                
                if ($existing) {
                    Write-EcoLog -Message "Groupe déjà existant : $($group.Name)" -Level Warning
                    $skippedCount++
                    continue
                }
                
                if ($PSCmdlet.ShouldProcess($group.Name, "Créer groupe")) {
                    if (-not $WhatIf) {
                        New-ADGroup -Name $group.Name `
                            -GroupScope Global `
                            -GroupCategory Security `
                            -Path $fullPath `
                            -Description $group.Description `
                            -ErrorAction Stop
                    }
                    
                    Write-EcoLog -Message "Groupe créé : $($group.Name)" -Level Success
                    $createdCount++
                }
                
            } catch {
                Write-EcoLog -Message "Erreur création groupe $($group.Name) : $($_.Exception.Message)" -Level Error
            }
        }
        
        Write-EcoLog -Message "Groupes - Créés: $createdCount | Ignorés: $skippedCount" -Level Info
        
    } catch {
        Write-EcoLog -Message "Erreur fatale : $($_.Exception.Message)" -Level Error
    }
}

function New-EcoTechGroup {
    <#
    .SYNOPSIS
        Crée un nouveau groupe
    
    .DESCRIPTION
        Crée un groupe de sécurité avec les paramètres spécifiés
    
    .PARAMETER Name
        Nom du groupe
    
    .PARAMETER Description
        Description du groupe
    
    .PARAMETER ParentPath
        Chemin parent (ex: "OU=D01,OU=SX,OU=BDX,OU=ECOTECH")
    
    .EXAMPLE
        New-EcoTechGroup -Name "GRP_TEST" -Description "Groupe de test" -ParentPath "OU=SX,OU=BDX,OU=ECOTECH"
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
        
        # Vérifier si existe
        $existing = Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue
        if ($existing) {
            Write-EcoLog -Message "Groupe déjà existant : $Name" -Level Warning
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess($Name, "Créer groupe")) {
            New-ADGroup -Name $Name `
                -GroupScope Global `
                -GroupCategory Security `
                -Path $fullPath `
                -Description $Description
            
            Write-EcoLog -Message "Groupe créé : $Name" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur création groupe : $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Gestion des membres

function Add-EcoTechGroupMember {
    <#
    .SYNOPSIS
        Ajoute un membre à un groupe
    
    .DESCRIPTION
        Ajoute un utilisateur ou ordinateur à un groupe
    
    .PARAMETER GroupName
        Nom du groupe
    
    .PARAMETER MemberName
        SamAccountName du membre à ajouter
    
    .EXAMPLE
        Add-EcoTechGroupMember -GroupName "GRP_D01_RH" -MemberName "jean.dupont"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$MemberName
    )
    
    try {
        # Vérifier que le groupe existe
        $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
        
        # Vérifier que le membre existe
        $member = Get-ADUser -Filter "SamAccountName -eq '$MemberName'" -ErrorAction SilentlyContinue
        if (-not $member) {
            $member = Get-ADComputer -Filter "Name -eq '$MemberName'" -ErrorAction SilentlyContinue
        }
        
        if (-not $member) {
            Write-EcoLog -Message "Membre introuvable : $MemberName" -Level Error
            return $false
        }
        
        # Ajouter au groupe
        Add-ADGroupMember -Identity $group -Members $member -ErrorAction Stop
        Write-EcoLog -Message "Membre ajouté : $MemberName → $GroupName" -Level Success
        return $true
        
    } catch {
        Write-EcoLog -Message "Erreur ajout membre : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-EcoTechGroupMember {
    <#
    .SYNOPSIS
        Retire un membre d'un groupe
    
    .DESCRIPTION
        Retire un utilisateur ou ordinateur d'un groupe
    
    .PARAMETER GroupName
        Nom du groupe
    
    .PARAMETER MemberName
        SamAccountName du membre à retirer
    
    .EXAMPLE
        Remove-EcoTechGroupMember -GroupName "GRP_D01_RH" -MemberName "jean.dupont"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$MemberName
    )
    
    try {
        $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
        $member = Get-ADUser -Filter "SamAccountName -eq '$MemberName'" -ErrorAction SilentlyContinue
        
        if (-not $member) {
            $member = Get-ADComputer -Filter "Name -eq '$MemberName'" -ErrorAction SilentlyContinue
        }
        
        if (-not $member) {
            Write-EcoLog -Message "Membre introuvable : $MemberName" -Level Error
            return $false
        }
        
        Remove-ADGroupMember -Identity $group -Members $member -Confirm:$false
        Write-EcoLog -Message "Membre retiré : $MemberName ← $GroupName" -Level Success
        return $true
        
    } catch {
        Write-EcoLog -Message "Erreur retrait membre : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-EcoTechGroupMembers {
    <#
    .SYNOPSIS
        Liste les membres d'un groupe
    
    .DESCRIPTION
        Affiche tous les membres d'un groupe
    
    .PARAMETER GroupName
        Nom du groupe
    
    .EXAMPLE
        Get-EcoTechGroupMembers -GroupName "GRP_D01_RH"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    try {
        $group = Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction Stop
        $members = Get-ADGroupMember -Identity $group | Select-Object Name, SamAccountName, objectClass
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════" 
        Write-Host "   MEMBRES DU GROUPE : $GroupName"
        Write-Host "═══════════════════════════════════════" 
        Write-Host ""
        
        if ($members) {
            Write-Host "Nombre de membres : $($members.Count)" 
            Write-Host ""
            $members | Format-Table -AutoSize
        } else {
            Write-Host "Aucun membre" 
        }
        
        return $members
        
    } catch {
        Write-EcoLog -Message "Erreur liste membres : $($_.Exception.Message)" -Level Error
        return $null
    }
}

#endregion

#region Menu interactif

function Show-GroupMenu {
    <#
    .SYNOPSIS
        Affiche le menu de gestion des groupes
    
    .EXAMPLE
        Show-GroupMenu
    #>
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Show-Banner
        
        Write-Host "┌────────────────────────────────────────────────────────┐" 
        Write-Host "│              GESTION DES GROUPES DE SÉCURITÉ           │" 
        Write-Host "└────────────────────────────────────────────────────────┘" 
        Write-Host ""
        Write-Host "  1. Créer tous les groupes de sécurité"
        Write-Host "  2. Ajouter un groupe" 
        Write-Host "  3. Ajouter un membre à un groupe" 
        Write-Host "  4. Retirer un membre d'un groupe" 
        Write-Host "  5. Lister les membres d'un groupe" 
        Write-Host ""
        Write-Host "  Q. Retour au menu principal" 
        Write-Host ""
        
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','4','5','Q')
        
        switch ($choice) {
            '1' {
                Write-Host ""
                Write-Host "Création de tous les groupes..." 
                $confirm = Read-Host "Confirmer ? (O/N)"
                if ($confirm -eq 'O') {
                    New-EcoTechSecurityGroups
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '2' {
                Write-Host ""
                Write-Host "=== AJOUT D'UN GROUPE ===" 
                $name = Read-Host "Nom du groupe (ex: GRP_TEST)"
                $description = Read-Host "Description"
                $parent = Read-Host "Chemin parent (ex: OU=SX,OU=BDX,OU=ECOTECH)"
                
                New-EcoTechGroup -Name $name -Description $description -ParentPath $parent
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '3' {
                Write-Host ""
                Write-Host "=== AJOUT D'UN MEMBRE ===" 
                $groupName = Read-Host "Nom du groupe"
                $memberName = Read-Host "SamAccountName du membre"
                
                Add-EcoTechGroupMember -GroupName $groupName -MemberName $memberName
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '4' {
                Write-Host ""
                Write-Host "=== RETRAIT D'UN MEMBRE ===" 
                $groupName = Read-Host "Nom du groupe"
                $memberName = Read-Host "SamAccountName du membre"
                
                Remove-EcoTechGroupMember -GroupName $groupName -MemberName $memberName
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '5' {
                Write-Host ""
                Write-Host "=== LISTE DES MEMBRES ===" 
                $groupName = Read-Host "Nom du groupe"
                
                Get-EcoTechGroupMembers -GroupName $groupName
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
        }
        
    } while ($choice -ne 'Q')
}

#endregion

# Exporter les fonctions
Export-ModuleMember -Function @(
    'New-EcoTechSecurityGroups',
    'New-EcoTechGroup',
    'Add-EcoTechGroupMember',
    'Remove-EcoTechGroupMember',
    'Get-EcoTechGroupMembers',
    'Show-GroupMenu'
)
