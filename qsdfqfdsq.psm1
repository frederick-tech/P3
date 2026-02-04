<#
.SYNOPSIS
    Module de gestion des OUs (Architecture).
.NOTES
    Version : V5 (Correctif "Directory object not found" - Tri automatique)
#>

if (-not (Get-Module Module-Common)) {
    Import-Module "$PSScriptRoot\Module-Common.psm1" -ErrorAction Stop
}

function New-EcoTechOUStructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    
    Clear-Host
    Write-Host "Initialisation de l'architecture Active Directory..." -ForegroundColor Cyan
    
    try {
        $config = Get-EcoTechConfig
        $domainDN = $config.DomainInfo.DN
        
        # --- PHASE 1 : Structure de base (Avec TRI) ---
        # CORRECTIF : On trie par la longueur du Parent. 
        # Les parents (courts ou vides) seront traités AVANT les enfants (longs).
        $SortedOUs = $config.OUStructure | Sort-Object { $_.Parent.Length }

        $total = $SortedOUs.Count
        $i = 0

        foreach ($ou in $SortedOUs) {
            $i++
            Write-Progress -Activity "Architecture de base" -Status "Traitement : $($ou.Name)" -PercentComplete (($i / $total) * 100)

            # Construction du chemin parent
            # Si le parent est vide dans le config, on tape à la racine du domaine
            $Path = if ([string]::IsNullOrWhiteSpace($ou.Parent)) { $domainDN } else { "$($ou.Parent),$domainDN" }
            $TargetOU = "OU=$($ou.Name),$Path"
            
            # Vérification de sécurité : Le Parent existe-t-il ?
            if (-not (Get-ADObject -Identity $Path -ErrorAction SilentlyContinue)) {
                Write-EcoLog -Message "ERREUR : Impossible de créer '$($ou.Name)' car le parent '$Path' n'existe pas encore." -Level Error -LogOnly
                continue
            }

            if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
                try {
                    New-ADOrganizationalUnit -Name $ou.Name -Path $Path -Description $ou.Description -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                    Write-EcoLog -Message "OU Base Créée : $($ou.Name)" -Level Success -LogOnly
                } catch {
                    Write-EcoLog -Message "Erreur création $($ou.Name) : $($_.Exception.Message)" -Level Error -LogOnly
                }
            }
        }
        Write-Progress -Activity "Architecture de base" -Completed

        # --- PHASE 2 : Création dynamique des Services (Sxx) ---
        Write-Host "Vérification des Services (Sxx)..." -ForegroundColor Cyan
        
        $CSVPath = "$PSScriptRoot\Fiche_personnels.csv"
        
        if (Test-Path $CSVPath) {
            $delim = Get-CSVDelimiter $CSVPath
            $csv = Import-Csv $CSVPath -Delimiter $delim -Encoding UTF8
            $structure = $csv | Select-Object Departement, Service -Unique
            $totalS = $structure.Count
            $j = 0

            foreach ($item in $structure) {
                $j++
                Write-Progress -Activity "Architecture Services" -Status "$($item.Service)" -PercentComplete (($j / $totalS) * 100)

                # Récupération des codes
                $CodeDept = $config.DepartmentMapping[$item.Departement]
                $ValService = $config.ServiceMapping[$item.Service]
                $CodeService = if ($ValService -is [hashtable]) { $ValService.Code } else { $ValService }
                
                if ($CodeDept -and $CodeService) {
                    # ON CHERCHE OÙ EST LE DÉPARTEMENT (Dxx)
                    # Astuce : On cherche l'OU Dxx n'importe où dans le domaine pour trouver son vrai chemin
                    $DeptOU = Get-ADOrganizationalUnit -Filter "Name -eq '$CodeDept'" -Properties DistinguishedName -ErrorAction SilentlyContinue
                    
                    if ($DeptOU) {
                        $ParentPath = $DeptOU.DistinguishedName
                        $TargetSxx = "OU=$CodeService,$ParentPath"
                        
                        if (-not (Get-ADOrganizationalUnit -Identity $TargetSxx -ErrorAction SilentlyContinue)) {
                            New-ADOrganizationalUnit -Name $CodeService -Path $ParentPath -Description $item.Service -ProtectedFromAccidentalDeletion $true
                            Write-EcoLog -Message "OU Service Créée : $CodeService ($($item.Service)) dans $CodeDept" -Level Success -LogOnly
                        }
                    } else {
                        Write-EcoLog -Message "Impossible de créer Sxx : Le département $CodeDept est introuvable." -Level Warning -LogOnly
                    }
                }
            }
            Write-Progress -Activity "Architecture Services" -Completed
        } else {
            Write-Warning "Fichier CSV introuvable."
        }
        
        Write-Host "Architecture mise à jour avec succès." -ForegroundColor Green
        Write-EcoLog -Message "Mise à jour architecture terminée." -Level Info -LogOnly

    } catch {
        Write-Host "Erreur critique : $($_.Exception.Message)" -ForegroundColor Red
        Write-EcoLog -Message "Erreur Structure OU : $($_.Exception.Message)" -Level Error
    }
}

function Remove-EcoTechEntireInfrastructure {
    # ... (Garder votre fonction de suppression existante ou celle que je vous avais donnée précédemment) ...
    # Je remets la version sécurisée pour être sûr :
    param()
    
    Write-Host "ATTENTION : Suppression totale..." -ForegroundColor Red
    $confirm = Read-Host "Confirmez-vous ? (OUI)"
    if ($confirm -eq "OUI") {
        $config = Get-EcoTechConfig
        # On cible les racines probables
        $Roots = @("ECOTECH", "UBIHARD", "STUDIODLIGHT") 
        foreach ($root in $Roots) {
            $Target = "OU=$root,$($config.DomainInfo.DN)"
            if (Get-ADOrganizationalUnit -Identity $Target -ErrorAction SilentlyContinue) {
                Get-ADOrganizationalUnit -SearchBase $Target -Filter * | Set-ADObject -ProtectedFromAccidentalDeletion $false
                Remove-ADOrganizationalUnit -Identity $Target -Recursive -Confirm:$false
                Write-Host "$root supprimé." -ForegroundColor Yellow
            }
        }
    }
}

function Show-OUMenu {
    do {
        Clear-Host
        Write-Host "=== GESTION OUs (ARCHITECTURE) ==="
        Write-Host "1. Initialiser/Mettre à jour l'infrastructure"
        Write-Host "2. [DANGER] Supprimer toute l'infrastructure" -ForegroundColor Red
        Write-Host ""
        Write-Host "Appuyez sur Entrée pour retourner" -ForegroundColor Gray
        
        $c = Read-Host "Choix"
        
        switch ($c) {
            '1' { New-EcoTechOUStructure; Pause }
            '2' { Remove-EcoTechEntireInfrastructure; Pause }
            ''  { return } 
        }
    } while ($c -ne '')
}

Export-ModuleMember -Function 'New-EcoTechOUStructure','Remove-EcoTechEntireInfrastructure','Show-OUMenu'
