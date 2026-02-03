@{
    # Configuration centrale pour l'infrastructure AD EcoTech Solutions
    # Ce fichier est le SSOT (Single Source of Truth) pour toute la configuration
    
    DomainInfo = @{
        Name = "ecotech.local"
        DN = "DC=ecotech,DC=local"
        NetBIOS = "ECOTECH"
        EmailDomain = "ecotechsolutions.fr"
    }
    
    # Mot de passe par défaut (à changer à la première connexion)
    DefaultPassword = "EcoTech2026!"
    
    # Mapping des départements (SSOT)
    # FORMAT: "Nom complet du département" = "Code OU"
    DepartmentMapping = @{
        "Direction des Ressources Humaines" = "D01"
        "Service Commercial" = "D02"
        "Communication" = "D03"
        "Direction" = "D04"
        "Développement" = "D05"
        "Finance et Comptabilité" = "D06"
        "DSI" = "D07"
    }
    
    # Arborescence complète des OUs (basée sur OU.md)
    # STRUCTURE: Chaque OU a Name, Description, Parent (DN relatif)
    OUStructure = @(
        # ===== ECOTECH - BORDEAUX =====
        # Niveau 1 - Racine
        @{Name="ECOTECH"; Description="Racine de l'organisation EcoTech Solutions"; Parent=""}
        
        # Niveau 2 - Site
        @{Name="BDX"; Description="Site de Bordeaux"; Parent="OU=ECOTECH"}
        
        # Niveau 3 - Catégories fonctionnelles
        @{Name="GX"; Description="Administration & Tiering - Zone sensible"; Parent="OU=BDX,OU=ECOTECH"}
        @{Name="UX"; Description="Comptes Utilisateurs"; Parent="OU=BDX,OU=ECOTECH"}
        @{Name="SX"; Description="Security - Groupes et Ressources"; Parent="OU=BDX,OU=ECOTECH"}
        @{Name="WX"; Description="Postes de travail standard"; Parent="OU=BDX,OU=ECOTECH"}
        
        # Niveau 4 - Départements sous UX
        @{Name="D01"; Description="Direction des Ressources Humaines"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D02"; Description="Service Commercial"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D03"; Description="Communication"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D04"; Description="Direction"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D05"; Description="Développement"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D06"; Description="Finance et Comptabilité"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="D07"; Description="DSI"; Parent="OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D01 (RH)
        @{Name="S01"; Description="Formation"; Parent="OU=D01,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Recrutement"; Parent="OU=D01,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Administration du personnel"; Parent="OU=D01,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="Gestion des carrières"; Parent="OU=D01,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S05"; Description="Direction RH"; Parent="OU=D01,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D02 (Commercial)
        @{Name="S01"; Description="Gestion des comptes"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="B2B"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Prospection"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="ADV"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S05"; Description="Service Client"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S06"; Description="Service achat"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S07"; Description="Direction commerciale"; Parent="OU=D02,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D03 (Communication)
        @{Name="S01"; Description="Relation Médias"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Communication externe"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Communication interne"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="Événementiel"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S05"; Description="Gestion des réseaux sociaux"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S06"; Description="Direction Communication"; Parent="OU=D03,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D04 (Direction)
        @{Name="S01"; Description="Direction Générale"; Parent="OU=D04,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Direction adjoint"; Parent="OU=D04,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Responsable stratégie"; Parent="OU=D04,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="Assistant de direction"; Parent="OU=D04,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D05 (Développement)
        @{Name="S01"; Description="Frontend"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Backend"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Mobile"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="Analyse et conception"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S05"; Description="Recherche et Prototype"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S06"; Description="Direction Développement"; Parent="OU=D05,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D06 (Finance)
        @{Name="S01"; Description="Finance"; Parent="OU=D06,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Fiscalité"; Parent="OU=D06,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S03"; Description="Service Comptabilité"; Parent="OU=D06,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S04"; Description="Direction financière"; Parent="OU=D06,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Niveau 5 - Services D07 (DSI)
        @{Name="S01"; Description="Exploitation"; Parent="OU=D07,OU=UX,OU=BDX,OU=ECOTECH"}
        @{Name="S02"; Description="Direction SI"; Parent="OU=D07,OU=UX,OU=BDX,OU=ECOTECH"}
        
        # Structure SX (Groupes) - Départements
        @{Name="D01"; Description="Groupes RH"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D02"; Description="Groupes Commercial"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D03"; Description="Groupes Communication"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D04"; Description="Groupes Direction"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D05"; Description="Groupes Développement"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D06"; Description="Groupes Finance"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        @{Name="D07"; Description="Groupes DSI"; Parent="OU=SX,OU=BDX,OU=ECOTECH"}
        
        # Structure WX (Machines)
        @{Name="BX"; Description="Postes fixes"; Parent="OU=WX,OU=BDX,OU=ECOTECH"}
        @{Name="CX"; Description="Postes portables"; Parent="OU=WX,OU=BDX,OU=ECOTECH"}
        @{Name="EX"; Description="Serveurs"; Parent="OU=WX,OU=BDX,OU=ECOTECH"}
        @{Name="FX"; Description="Appliance"; Parent="OU=WX,OU=BDX,OU=ECOTECH"}
        @{Name="GX"; Description="Postes d'administration"; Parent="OU=WX,OU=BDX,OU=ECOTECH"}
        
        # ===== UBIHARD - PARIS =====
        @{Name="UBIHARD"; Description="Partenaire UBIHard"; Parent=""}
        @{Name="PAR"; Description="Site de Paris"; Parent="OU=UBIHARD"}
        @{Name="UX"; Description="Comptes Utilisateurs"; Parent="OU=PAR,OU=UBIHARD"}
        @{Name="SX"; Description="Security - Groupes et Ressources"; Parent="OU=PAR,OU=UBIHARD"}
        @{Name="D02"; Description="Développement"; Parent="OU=UX,OU=PAR,OU=UBIHARD"}
        @{Name="S01"; Description="Tests et qualité"; Parent="OU=D02,OU=UX,OU=PAR,OU=UBIHARD"}
        @{Name="D02"; Description="Groupes Développement"; Parent="OU=SX,OU=PAR,OU=UBIHARD"}
        
        # ===== SDLIGHT - NANTES =====
        @{Name="SDLIGHT"; Description="Partenaire Studio Dlight"; Parent=""}
        @{Name="NTE"; Description="Site de Nantes"; Parent="OU=SDLIGHT"}
        @{Name="UX"; Description="Comptes Utilisateurs"; Parent="OU=NTE,OU=SDLIGHT"}
        @{Name="SX"; Description="Security - Groupes et Ressources"; Parent="OU=NTE,OU=SDLIGHT"}
        @{Name="D06"; Description="Communication"; Parent="OU=UX,OU=NTE,OU=SDLIGHT"}
        @{Name="S01"; Description="Relation Médias"; Parent="OU=D06,OU=UX,OU=NTE,OU=SDLIGHT"}
        @{Name="D06"; Description="Groupes Communication"; Parent="OU=SX,OU=NTE,OU=SDLIGHT"}
    )
    
    # Mapping détaillé des services vers codes OU
    # FORMAT: "Nom du service" = @{Dept="Code département"; Code="Code service"}
    ServiceMapping = @{
        # D01 - RH
        "Formation" = @{Dept="D01"; Code="S01"}
        "Recrutement" = @{Dept="D01"; Code="S02"}
        "Administration du personnel" = @{Dept="D01"; Code="S03"}
        "Gestion des carrières" = @{Dept="D01"; Code="S04"}
        "Direction RH" = @{Dept="D01"; Code="S05"}
        
        # D02 - Service Commercial
        "Gestion des comptes" = @{Dept="D02"; Code="S01"}
        "B2B" = @{Dept="D02"; Code="S02"}
        "Prospection" = @{Dept="D02"; Code="S03"}
        "ADV" = @{Dept="D02"; Code="S04"}
        "Service client" = @{Dept="D02"; Code="S05"}
        "Service Client" = @{Dept="D02"; Code="S05"}
        "Service achat" = @{Dept="D02"; Code="S06"}
        "Direction commerciale" = @{Dept="D02"; Code="S07"}
        
        # D03 - Communication
        "Relation Médias" = @{Dept="D03"; Code="S01"}
        "Communication externe" = @{Dept="D03"; Code="S02"}
        "Communication interne" = @{Dept="D03"; Code="S03"}
        "Événementiel" = @{Dept="D03"; Code="S04"}
        "Gestion des réseaux sociaux" = @{Dept="D03"; Code="S05"}
        "Direction Communication" = @{Dept="D03"; Code="S06"}
        
        # D04 - Direction
        "Direction Générale" = @{Dept="D04"; Code="S01"}
        "Direction adjoint" = @{Dept="D04"; Code="S02"}
        "Responsable stratégie" = @{Dept="D04"; Code="S03"}
        "Assistant de direction" = @{Dept="D04"; Code="S04"}
        "" = @{Dept="D04"; Code="S01"} # Direction sans service
        
        # D05 - Développement
        "Développement fronted" = @{Dept="D05"; Code="S01"}
        "Développement frontend" = @{Dept="D05"; Code="S01"}
        "Frontend" = @{Dept="D05"; Code="S01"}
        "Développement backend" = @{Dept="D05"; Code="S02"}
        "Backend" = @{Dept="D05"; Code="S02"}
        "Développement mobile" = @{Dept="D05"; Code="S03"}
        "Mobile" = @{Dept="D05"; Code="S03"}
        "Analyse et conception" = @{Dept="D05"; Code="S04"}
        "Tests et qualité" = @{Dept="D05"; Code="S05"}
        "Recherche et prototype" = @{Dept="D05"; Code="S05"}
        "Recherche et Prototype" = @{Dept="D05"; Code="S05"}
        "Direction Développement" = @{Dept="D05"; Code="S06"}
        
        # D06 - Finance et Comptabilité
        "Finance" = @{Dept="D06"; Code="S01"}
        "Fiscalité" = @{Dept="D06"; Code="S02"}
        "Service Comptabilité" = @{Dept="D06"; Code="S03"}
        "Direction financière" = @{Dept="D06"; Code="S04"}
        
        # D07 - DSI
        "Exploitation" = @{Dept="D07"; Code="S01"}
        "Direction SI" = @{Dept="D07"; Code="S02"}
    }
    
    # Configuration des logs
    LogPath = "C:\Logs\EcoTech-AD"
}
