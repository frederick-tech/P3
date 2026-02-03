<#
.SYNOPSIS
    Module de gestion des ordinateurs pour EcoTech Solutions

.DESCRIPTION
    Ce module permet de gérer les objets ordinateurs dans AD :
    - Importer depuis CSV et renommer selon nomenclature
    - Créer un ordinateur manuellement
    - Déplacer un ordinateur
    - Supprimer un ordinateur

.NOTES
    Auteur: Équipe Admin SI - EcoTech Solutions
    Version: 2.0
#>

# Importer le module commun
Import-Module "$PSScriptRoot\Module-Common.psm1" -Force

#region Importation depuis CSV

function Import-EcoTechComputers {
    <#
    .SYNOPSIS
        Importe les ordinateurs depuis le fichier CSV
    
    .DESCRIPTION
        Lit le CSV, détecte les PC des utilisateurs et les crée dans les bonnes OUs
        Format : ECO-BDX-CX001 (portables) ou ECO-BDX-BX001 (fixes)
    
    .PARAMETER CSVPath
        Chemin du fichier CSV
    
    .PARAMETER ComputerType
        Type de machines : CX (portables - par défaut) ou BX (fixes)
    
    .EXAMPLE
        Import-EcoTechComputers -CSVPath "C:\Import\Fiche_personnels.csv" -ComputerType CX
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$CSVPath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('BX','CX')]
        [string]$ComputerType = 'CX'
    )
    
    Write-EcoLog -Message "===== IMPORTATION DES ORDINATEURS =====" -Level Info
    Write-EcoLog -Message "Type : $ComputerType ($(if($ComputerType -eq 'CX'){'Portables'}else{'Postes fixes'}))" -Level Info
    
    try {
        $config = Get-EcoTechConfig
        
        # Lire le CSV
        $users = Import-Csv -Path $CSVPath -Delimiter ";" -Encoding UTF8
        Write-EcoLog -Message "Lignes dans le CSV : $($users.Count)" -Level Info
        
        # Trouver le prochain numéro disponible
        $nextNumber = Get-NextComputerNumber -Type $ComputerType
        
        $createdCount = 0
        $skippedCount = 0
        $errorCount = 0
        
        foreach ($user in $users) {
            try {
                # Vérifier qu'il y a un PC
                if (-not $user.'Nom de PC') {
                    $skippedCount++
                    continue
                }
                
                # Générer le nouveau nom selon nomenclature
                $newPCName = New-ComputerName -Type $ComputerType -NextNumber $nextNumber
                
                # Déterminer le département pour placer dans la bonne OU
                $deptCode = $config.DepartmentMapping[$user.Departement]
                if (-not $deptCode) {
                    $deptCode = "D04"
                }
                
                # Chemin OU : Les machines BX et CX ne sont PAS organisées par département
                # Elles sont toutes dans OU=CX ou OU=BX directement
                $ouPath = "OU=$ComputerType,OU=WX,OU=BDX,OU=ECOTECH"
                $fullOUPath = Get-OUPath -OUPath $ouPath
                
                # Vérifier si l'ordinateur existe déjà
                $existing = Get-ADComputer -Filter "Name -eq '$newPCName'" -ErrorAction SilentlyContinue
                
                if ($existing) {
                    Write-EcoLog -Message "Ordinateur déjà existant : $newPCName" -Level Warning
                    $skippedCount++
                    $nextNumber++
                    continue
                }
                
                # Créer l'ordinateur
                if ($PSCmdlet.ShouldProcess($newPCName, "Créer ordinateur")) {
                    $description = "PC de $($user.Prenom) $($user.Nom) - $($user.Departement)"
                    
                    New-ADComputer -Name $newPCName `
                        -Path $fullOUPath `
                        -Description $description `
                        -Enabled $true `
                        -ErrorAction Stop
                    
                    Write-EcoLog -Message "Ordinateur créé : $newPCName → $description" -Level Success
                    $createdCount++
                    $nextNumber++
                }
                
            } catch {
                Write-EcoLog -Message "Erreur création ordinateur : $($_.Exception.Message)" -Level Error
                $errorCount++
            }
        }
        
        Write-EcoLog -Message "=== RÉSUMÉ IMPORTATION ===" -Level Info
        Write-EcoLog -Message "Créés: $createdCount | Ignorés: $skippedCount | Erreurs: $errorCount" -Level Info
        
    } catch {
        Write-EcoLog -Message "Erreur fatale : $($_.Exception.Message)" -Level Error
    }
}

function Get-NextComputerNumber {
    <#
    .SYNOPSIS
        Trouve le prochain numéro disponible pour un type de machine
    
    .PARAMETER Type
        Type de machine (BX, CX, EX, FX, GX)
    
    .EXAMPLE
        Get-NextComputerNumber -Type CX
        # Retourne: 24 (si ECO-BDX-CX023 existe)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('BX','CX','EX','FX','GX')]
        [string]$Type
    )
    
    $prefix = "ECO-BDX-$Type"
    $existing = Get-ADComputer -Filter "Name -like '$prefix*'" -ErrorAction SilentlyContinue
    
    if ($existing) {
        # Extraire les numéros
        $numbers = $existing | ForEach-Object {
            if ($_.Name -match "$prefix(\d+)$") {
                [int]$matches[1]
            }
        }
        
        if ($numbers) {
            return ($numbers | Measure-Object -Maximum).Maximum + 1
        }
    }
    
    return 1
}

#endregion

#region Gestion individuelle

function New-EcoTechComputer {
    <#
    .SYNOPSIS
        Crée un ordinateur manuellement
    
    .DESCRIPTION
        Crée un objet ordinateur avec auto-génération du nom
    
    .PARAMETER Type
        Type : BX (fixe), CX (portable), EX (serveur), FX (appliance), GX (admin)
    
    .PARAMETER Description
        Description de la machine
    
    .EXAMPLE
        New-EcoTechComputer -Type CX -Description "PC portable du service RH"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('BX','CX','EX','FX','GX')]
        [string]$Type,
        
        [Parameter(Mandatory=$false)]
        [string]$Description
    )
    
    try {
        # Générer le nom
        $computerName = New-ComputerName -Type $Type
        
        # Chemin OU
        $ouPath = "OU=$Type,OU=WX,OU=BDX,OU=ECOTECH"
        $fullOUPath = Get-OUPath -OUPath $ouPath
        
        # Créer
        if ($PSCmdlet.ShouldProcess($computerName, "Créer ordinateur")) {
            New-ADComputer -Name $computerName `
                -Path $fullOUPath `
                -Description $Description `
                -Enabled $true `
                -ErrorAction Stop
            
            Write-EcoLog -Message "Ordinateur créé : $computerName" -Level Success
            return $computerName
        }
        
    } catch {
        Write-EcoLog -Message "Erreur création ordinateur : $($_.Exception.Message)" -Level Error
        return $null
    }
}

function Move-EcoTechComputer {
    <#
    .SYNOPSIS
        Déplace un ordinateur vers une autre OU
    
    .PARAMETER ComputerName
        Nom de l'ordinateur
    
    .PARAMETER TargetOUPath
        Chemin de l'OU cible
    
    .EXAMPLE
        Move-EcoTechComputer -ComputerName "ECO-BDX-CX001" -TargetOUPath "OU=GX,OU=WX,OU=BDX,OU=ECOTECH"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory=$true)]
        [string]$TargetOUPath
    )
    
    try {
        $computer = Get-ADComputer -Filter "Name -eq '$ComputerName'" -ErrorAction Stop
        $fullOUPath = Get-OUPath -OUPath $TargetOUPath
        
        if ($PSCmdlet.ShouldProcess($ComputerName, "Déplacer vers $TargetOUPath")) {
            Move-ADObject -Identity $computer -TargetPath $fullOUPath
            Write-EcoLog -Message "Ordinateur déplacé : $ComputerName → $TargetOUPath" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur déplacement ordinateur : $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Remove-EcoTechComputer {
    <#
    .SYNOPSIS
        Supprime un ordinateur
    
    .PARAMETER ComputerName
        Nom de l'ordinateur
    
    .EXAMPLE
        Remove-EcoTechComputer -ComputerName "ECO-BDX-CX001"
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ComputerName
    )
    
    try {
        $computer = Get-ADComputer -Filter "Name -eq '$ComputerName'" -ErrorAction Stop
        
        Write-Host ""
        Write-Host "ATTENTION : Suppression de l'ordinateur" -ForegroundColor Red
        Write-Host "Nom : $ComputerName"
        
        $confirm = Read-Host "Confirmez-vous ? (O/N)"
        
        if ($confirm -ne 'O') {
            Write-EcoLog -Message "Suppression annulée" -Level Warning
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess($ComputerName, "Supprimer ordinateur")) {
            Remove-ADComputer -Identity $computer -Confirm:$false
            Write-EcoLog -Message "Ordinateur supprimé : $ComputerName" -Level Success
            return $true
        }
        
    } catch {
        Write-EcoLog -Message "Erreur suppression ordinateur : $($_.Exception.Message)" -Level Error
        return $false
    }
}

#endregion

#region Menu interactif

function Show-ComputerMenu {
    <#
    .SYNOPSIS
        Affiche le menu de gestion des ordinateurs
    #>
    [CmdletBinding()]
    param()
    
    do {
        Clear-Host
        Show-Banner
        
        Write-Host "┌────────────────────────────────────────────────────────┐" 
        Write-Host "│              GESTION DES ORDINATEURS                   │" 
        Write-Host "└────────────────────────────────────────────────────────┘" 
        Write-Host ""
        Write-Host "  1. Importer les portables depuis le fichier .csv (CX)" 
        Write-Host "  2. Importer les postes fixes depuis le fichier .csv (BX)" 
        Write-Host "  3. Créer un ordinateur manuellement" 
        Write-Host "  4. Déplacer un ordinateur" 
        Write-Host "  5. Supprimer un ordinateur" 
        Write-Host "  Q. Retour au menu principal" 
        Write-Host ""
        
        $choice = Read-Choice -Prompt "Votre choix" -ValidChoices @('1','2','3','4','5','Q')
        
        switch ($choice) {
            '1' {
                Write-Host ""
                $csvPath = Read-Host "Chemin du fichier CSV"
                if (Test-Path $csvPath) {
                    Import-EcoTechComputers -CSVPath $csvPath -ComputerType CX
                } else {
                    Write-Host "Fichier introuvable" -ForegroundColor Red
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '2' {
                Write-Host ""
                $csvPath = Read-Host "Chemin du fichier CSV"
                if (Test-Path $csvPath) {
                    Import-EcoTechComputers -CSVPath $csvPath -ComputerType BX
                } else {
                    Write-Host "Fichier introuvable" -ForegroundColor Red
                }
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '3' {
                Write-Host ""
                Write-Host "=== CRÉATION MANUELLE ===" 
                Write-Host "Types disponibles :" 
                Write-Host "  BX = Poste fixe" 
                Write-Host "  CX = Portable" 
                Write-Host "  EX = Serveur" 
                Write-Host "  FX = Appliance" 
                Write-Host "  GX = Poste d'administration" 
                Write-Host ""
                
                $type = Read-Host "Type (BX/CX/EX/FX/GX)"
                $description = Read-Host "Description (optionnel)"
                
                if ($type -in @('BX','CX','EX','FX','GX')) {
                    $name = New-EcoTechComputer -Type $type -Description $description
                    if ($name) {
                        Write-Host ""
                        Write-Host "Ordinateur créé : $name" 
                    }
                } else {
                    Write-Host "Type invalide" -ForegroundColor Red
                }
                
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '4' {
                Write-Host ""
                $computerName = Read-Host "Nom de l'ordinateur"
                $targetOU = Read-Host "OU cible (ex: OU=GX,OU=WX,OU=BDX,OU=ECOTECH)"
                
                Move-EcoTechComputer -ComputerName $computerName -TargetOUPath $targetOU
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
            
            '5' {
                Write-Host ""
                $computerName = Read-Host "Nom de l'ordinateur"
                Remove-EcoTechComputer -ComputerName $computerName
                Read-Host "`nAppuyez sur Entrée pour continuer"
            }
        }
        
    } while ($choice -ne 'Q')
}

#endregion

# Exporter les fonctions
Export-ModuleMember -Function @(
    'Import-EcoTechComputers',
    'New-EcoTechComputer',
    'Move-EcoTechComputer',
    'Remove-EcoTechComputer',
    'Show-ComputerMenu'
)
