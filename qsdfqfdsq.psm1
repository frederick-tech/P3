<#
.SYNOPSIS
    Module de gestion des OUs (Architecture).
.NOTES
    Version : V6 (Débogage avancé + Protection contre les parents manquants)
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
        $domainDN = $config.DomainInfo.DN.Trim() # Sécurité : On retire les espaces inutiles
        
        Write-Host "Domaine cible : $domainDN" -ForegroundColor Gray

        # --- PHASE 1 : Structure de base (OUs définies dans le PSD1) ---
        # Tri intelligent : On traite d'abord les parents (chemin court), puis les enfants
        $SortedOUs = $config.OUStructure | Sort-Object { 
            if ($_.Parent) { $_.Parent.Length } else { 0 } 
        }

        $total = $SortedOUs.Count
        $i = 0

        foreach ($ou in $SortedOUs) {
            $i++
            Write-Progress -Activity "Architecture de base" -Status "Traitement : $($ou.Name)" -PercentComplete (($i / $total) * 100)

            # 1. Construction du chemin parent
            # Si Parent est vide = Racine du domaine
            if ([string]::IsNullOrWhiteSpace($ou.Parent)) { 
                $Path = $domainDN 
            } else { 
                # Si le Parent contient déjà "DC=", c'est un chemin absolu (erreur config), sinon on ajoute le domaine
                if ($ou.Parent -match "DC=") {
                    $Path = $ou.Parent
                } else {
                    $Path = "$($ou.Parent),$domainDN"
                }
            }

            $TargetOU = "OU=$($ou.Name),$Path"
            
            # 2. Vérification CRITIQUE : Le dossier parent existe-t-il ?
            if (-not (Get-ADObject -Identity $Path -ErrorAction SilentlyContinue)) {
                Write-Host "  [ERREUR] Parent introuvable pour '$($ou.Name)'" -ForegroundColor Red
                Write-Host "           Chemin cherché : $Path" -ForegroundColor Red
                Write-EcoLog -Message "Echec création $($ou.Name) : Parent introuvable ($Path)" -Level Error -LogOnly
                continue # On passe au suivant pour ne pas tout bloquer
            }

            # 3. Création de l'OU
            if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
                try {
                    New-ADOrganizationalUnit -Name $ou.Name -Path $Path -Description $ou.Description -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                    Write-EcoLog -Message "OU Base Créée : $($ou.Name)" -Level Success -LogOnly
                } catch {
                    Write-Host "  [ERREUR] Echec création '$($ou.Name)' : $($_.Exception.Message)" -ForegroundColor Red
                    Write-EcoLog -Message "Erreur API sur $($ou.Name) : $($_.Exception.Message)" -Level Error -LogOnly
                }
            }
        }
        Write-Progress -Activity "Architecture de base" -Completed

        # --- PHASE 2 : Création dynamique des Services (Sxx) via CSV ---
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
                    # Recherche du vrai chemin du Département (Dxx) dans tout l'AD
                    # Cela évite les erreurs si le Dxx a été déplacé ou si le chemin théorique est faux
                    $DeptOU = Get-ADOrganizationalUnit -Filter "Name -eq '$CodeDept'" -Properties DistinguishedName -ErrorAction SilentlyContinue
                    
                    if ($DeptOU) {
                        $ParentPath = $DeptOU.DistinguishedName
                        $TargetSxx = "OU=$CodeService,$ParentPath"
                        
                        if (-not (Get-ADOrganizationalUnit -Identity $TargetSxx -ErrorAction SilentlyContinue)) {
                            try {
                                New-ADOrganizationalUnit -Name $CodeService -Path $ParentPath -Description $item.Service -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                                Write-EcoLog -Message "OU Service Créée : $CodeService ($($item.Service))" -Level Success -LogOnly
                            } catch {
                                Write-EcoLog -Message "Erreur création Service $CodeService : $($_.Exception.Message)" -Level Error -LogOnly
                            }
                        }
                    } else {
                        # Log silencieux si le département parent n'existe pas encore (peut arriver si Phase 1 a échoué)
                        Write-EcoLog -Message "Impossible de créer Sxx : Le département $CodeDept est introuvable." -Level Warning -LogOnly
                    }
                }
            }
            Write-Progress -Activity "Architecture Services" -Completed
        } else {
            Write-Warning "Fichier CSV introuvable."
        }
        
        Write-Host "Opération terminée." -ForegroundColor Green

    } catch {
        Write-Host "Erreur globale Module-OU : $($_.Exception.Message)" -ForegroundColor Red
        Write-EcoLog -Message "Crash Module-OU : $($_.Exception.Message)" -Level Error
    }
}

function Remove-EcoTechEntireInfrastructure {
    param()
    Write-Host "ATTENTION : Suppression totale..." -ForegroundColor Red
    $confirm = Read-Host "Confirmez-vous ? (OUI)"
    if ($confirm -eq "OUI") {
        $config = Get-EcoTechConfig
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
