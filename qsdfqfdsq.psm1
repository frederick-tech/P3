<#
.SYNOPSIS
    Module de gestion des OUs.
.NOTES
    Retour à la logique originale (stable) + Mode Silencieux
#>

if (-not (Get-Module Module-Common)) {
    Import-Module "$PSScriptRoot\Module-Common.psm1" -ErrorAction Stop
}

function New-EcoTechOUStructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    
    # On affiche juste un titre propre
    Clear-Host
    Write-Host "Vérification de l'arborescence OU..." -ForegroundColor Cyan
    
    try {
        $config = Get-EcoTechConfig
        $domainDN = $config.DomainInfo.DN
        
        $created = 0
        $updated = 0
        $totalOUs = $config.OUStructure.Count
        $i = 0
        
        foreach ($ou in $config.OUStructure) {
            $i++
            # Barre de progression (ne pollue pas le log)
            Write-Progress -Activity "Configuration des OUs" -Status "$($ou.Name)" -PercentComplete (($i / $totalOUs) * 100)

            # Construction du chemin
            $Path = if ([string]::IsNullOrWhiteSpace($ou.Parent)) { $domainDN } else { "$($ou.Parent),$domainDN" }
            
            # Recherche de l'OU existante (au niveau spécifié uniquement) - VOTRE LOGIQUE
            # Note : Si le parent n'existe pas encore, cette commande échouera et ira dans le Catch.
            # Assurez-vous que le fichier Config est dans le bon ordre (Parents avant Enfants).
            try {
                $existing = Get-ADOrganizationalUnit -Filter "Name -eq '$($ou.Name)'" -SearchBase $Path -SearchScope OneLevel -ErrorAction Stop
            } catch {
                $existing = $null
            }

            if ($existing) {
                # L'OU existe : on vérifie la description
                if ($existing.Description -ne $ou.Description) {
                    Set-ADOrganizationalUnit -Identity $existing.DistinguishedName -Description $ou.Description
                    $updated++
                    # Log silencieux
                    Write-EcoLog -Message "OU Mise à jour : $($ou.Name)" -Level Info -LogOnly
                }
            } else {
                # L'OU n'existe pas : création
                try {
                    New-ADOrganizationalUnit -Name $ou.Name -Path $Path -Description $ou.Description -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
                    $created++
                    # Log silencieux
                    Write-EcoLog -Message "OU Créée : $($ou.Name)" -Level Success -LogOnly
                } catch {
                    # Si ça plante ici, c'est souvent que le Parent n'existe pas
                    Write-EcoLog -Message "Echec création $($ou.Name) (Parent absent ?) : $($_.Exception.Message)" -Level Error -LogOnly
                }
            }
        }
        
        Write-Progress -Activity "Configuration des OUs" -Completed
        
        # Bilan propre à la fin
        Write-Host ""
        Write-Host "=== BILAN INFRASTRUCTURE ===" -ForegroundColor Cyan
        Write-Host "  OUs créées       : $created"
        Write-Host "  OUs mises à jour : $updated"
        Write-Host "  Total traitées   : $totalOUs"
        Write-Host ""
        Write-Host "Appuyez sur Entrée pour continuer..." -ForegroundColor Gray
        
    } catch {
        # En cas de gros crash (ex: Config non chargée)
        Write-Host "Erreur critique : $($_.Exception.Message)" -ForegroundColor Red
        Write-EcoLog -Message "Crash Module-OU : $($_.Exception.Message)" -Level Error
    }
}

function Remove-EcoTechEntireInfrastructure {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param()
    
    Write-Host "ATTENTION : Suppression totale de l'infrastructure..." -ForegroundColor Red
    $confirm = Read-Host "Confirmez-vous ? (Tapez OUI)"
    
    if ($confirm -eq "OUI") {
        $config = Get-EcoTechConfig
        $racines = @("ECOTECH", "UBIHARD", "STUDIODLIGHT")
        
        foreach ($name in $racines) {
            $Target = "OU=$name,$($config.DomainInfo.DN)"
            if (Get-ADOrganizationalUnit -Identity $Target -ErrorAction SilentlyContinue) {
                try {
                    # Déverrouillage
                    Get-ADOrganizationalUnit -SearchBase $Target -Filter * | Set-ADObject -ProtectedFromAccidentalDeletion $false
                    # Suppression
                    Remove-ADOrganizationalUnit -Identity $Target -Recursive -Confirm:$false
                    
                    Write-Host "$name supprimé." -ForegroundColor Yellow
                    Write-EcoLog -Message "Infra $name supprimée." -Level Warning -LogOnly
                } catch {
                    Write-Host "Erreur suppression $name : $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
}


function Show-OUMenu {
    do {
        Clear-Host
        Write-Host "=== GESTION OU ==="
        Write-Host "1. Initialiser/Mettre à jour toute l'infrastructure"
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
