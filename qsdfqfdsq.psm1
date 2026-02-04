<#
.SYNOPSIS
    Module de gestion des OUs (Architecture).
.NOTES
    Version : Classique (Lecture séquentielle du Config + Mode Silencieux)
#>

if (-not (Get-Module Module-Common)) {
    Import-Module "$PSScriptRoot\Module-Common.psm1" -ErrorAction Stop
}

function New-EcoTechOUStructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    
    Clear-Host
    Write-Host "Mise à jour de l'architecture (Lecture Config)..." -ForegroundColor Cyan
    
    try {
        $config = Get-EcoTechConfig
        $domainDN = $config.DomainInfo.DN
        
        $total = $config.OUStructure.Count
        $i = 0

        # On parcourt simplement la liste définie dans le fichier de config.
        # Si le fichier est bien ordonné (Parents en premier), aucune erreur ne surviendra.
        foreach ($ou in $config.OUStructure) {
            $i++
            Write-Progress -Activity "Architecture OU" -Status "$($ou.Name)" -PercentComplete (($i / $total) * 100)

            # 1. Définition du chemin Parent
            if ([string]::IsNullOrWhiteSpace($ou.Parent)) {
                # C'est une racine (ex: ECOTECH)
                $Path = $domainDN
            } else {
                # C'est un enfant (ex: UX dans PAR, ou S01 dans D01)
                # On gère le cas où le Parent est déjà écrit en format complet ou relatif
                if ($ou.Parent -match "DC=") {
                    $Path = $ou.Parent
                } else {
                    $Path = "$($ou.Parent),$domainDN"
                }
            }
            
            # 2. Vérification et Création
            $TargetOU = "OU=$($ou.Name),$Path"
            
            # On vérifie d'abord si le PARENT existe pour éviter le crash "Directory object not found"
            if (Get-ADObject -Identity $Path -ErrorAction SilentlyContinue) {
                
                if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
                    try {
                        New-ADOrganizationalUnit -Name $ou.Name -Path $Path -Description $ou.Description -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                        # Succès : On loggue dans le fichier mais PAS à l'écran
                        Write-EcoLog -Message "OU Créée : $($ou.Name)" -Level Success -LogOnly
                    } catch {
                        # Erreur technique précise
                        Write-EcoLog -Message "Echec création $($ou.Name) : $($_.Exception.Message)" -Level Error -LogOnly
                    }
                } else {
                    # L'OU existe déjà, on ne fait rien (ou on met à jour la description si besoin)
                    # Write-EcoLog -Message "OU Existant : $($ou.Name)" -Level Info -LogOnly
                }

            } else {
                # Si le parent n'existe pas, c'est une erreur de configuration (ordre des lignes)
                Write-Host "  [ALERTE] Parent introuvable pour '$($ou.Name)'" -ForegroundColor Yellow
                Write-EcoLog -Message "Parent introuvable ($Path) pour l'OU $($ou.Name)" -Level Warning -LogOnly
            }
        }
        
        Write-Progress -Activity "Architecture OU" -Completed
        Write-Host "Architecture vérifiée." -ForegroundColor Green
        Write-Host "Consultez les logs pour les détails." -ForegroundColor Gray

    } catch {
        Write-Host "Erreur globale : $($_.Exception.Message)" -ForegroundColor Red
        Write-EcoLog -Message "Crash Module-OU : $($_.Exception.Message)" -Level Error
    }
}

function Remove-EcoTechEntireInfrastructure {
    param()
    Write-Host "ATTENTION : Suppression totale de l'infra ECOTECH..." -ForegroundColor Red
    $confirm = Read-Host "Tapez OUI pour confirmer"
    
    if ($confirm -eq "OUI") {
        $config = Get-EcoTechConfig
        # On supprime les racines principales
        $Roots = @("ECOTECH", "UBIHARD", "STUDIODLIGHT") 
        foreach ($root in $Roots) {
            $Target = "OU=$root,$($config.DomainInfo.DN)"
            if (Get-ADOrganizationalUnit -Identity $Target -ErrorAction SilentlyContinue) {
                try {
                    # Déprotection récursive
                    Get-ADOrganizationalUnit -SearchBase $Target -Filter * | Set-ADObject -ProtectedFromAccidentalDeletion $false
                    # Suppression
                    Remove-ADOrganizationalUnit -Identity $Target -Recursive -Confirm:$false
                    Write-Host "$root supprimé." -ForegroundColor Yellow
                    Write-EcoLog -Message "Infra $root supprimée" -Level Warning -LogOnly
                } catch {
                    Write-Host "Erreur suppression $root : $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
}

function Show-OUMenu {
    do {
        Clear-Host
        Write-Host "=== GESTION OUs (ARCHITECTURE) ==="
        Write-Host "1. Initialiser/Mettre à jour l'infrastructure (Config)"
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
