####################################################################################################
#                                                                                                  #
#    Company:        THE A.F.S. CORPORATION                                                        #
#    Department:     INFORMATION TECHNOLOGY                                                        #
#    Division:       PROGRAMMING AND DEVELOPMENT                                                   #
#    Group:                                                                                        #
#    Team:                                                                                         #
#                                                                                                  #
#    Level:          0                                                                             #
#    Classification: PUBLIC                                                                        #
#    Version:        24.0.2                                                                        #
#                                                                                                  #
#    Name:           PSXPEDITE                                                                     #
#    Title:          FILE-BASED POWERSHELL MODULE AND VERSION DISTRIBUTION SYSTEM                  #
#    Description:    PSXPEDITE IS A POWERSHELL MODULE THAT INTRODUCES A FILE-BASED MODULE AND      #
#                    VERSION DISTRIBUTION AND STORAGE SYSTEM.                                      #
#    Language:       POWERSHELL                                                                    #
#    Contributor(s): MDELAND002                                                                    #
#    Created:        2024-04-15                                                                    #
#    Updated:        2024-04-18                                                                    #
#                                                                                                  #
#    SNAF:           [PSXPEDITE24.0.2 ¦ LEVEL-0] - FILE-BASED POWERSHELL MODULE AND VERSION        #
#                    DISTRIBUTION SYSTEM                                                           #
#    DRL:            DRL://AFS/IT/DPD/PSXPEDITE                                                    #
#    DID:            UDIS-0000000000000000000Z                                                     #
#    Location:                                                                                     #
#                                                                                                  #
#    2024 (c) THE A.F.S. CORPORATION. All rights reserved.                                         #
#                                                                                                  #
####################################################################################################

$Script:PSXConfiguration = @{
    Root                = $PSScriptRoot
    Modules             = "$PSScriptRoot\Modules"
    STVPRegEx           = '^(?<year>\d{1,2})\.(?<major>\d+)\.(?<minor>\d+)(?:\-(?<language>[a-zA-Z]{2}))?$'
    STVPIncompleteRegEx = '^(?<year>\d{1,2}|\*)\.(?<major>\d+|\*)\.(?<minor>\d+|\*)(?:\-(?<language>[a-zA-Z]{2}))?$'
    Name                = 'PSXPEDITE:24.0.2'
}

function Get-PSXConfiguration {
    param(
        [Alias('Name', 'Config', 'Setting')]
        [string] $Key
    )

    if ($Key) {
        if ($Script:PSXConfiguration.ContainsKey($Key)) {
            return $Script:PSXConfiguration[$Key]
        }
        else {
            return $null
        }
    }
    else {
        return $Script:PSXConfiguration
    }
}

function Import-PSXModule {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module,

        [parameter(Position = 1)]
        [string] $Version = 'latest',

        [Alias("NoReqs", "Solo", "Only")]
        [switch] $NoRequirements,

        [switch] $Global,

        [switch] $Paths
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
        $Version = $IsFormal.Version    
    }

    if ($Version -eq 'latest') {
        $Version = Get-PSXModuleLatest -Module $Module

        if ($Version -eq $false) {
            return $false
        }
    }

    $File = Get-PSXModuleFile -Module $Module -Version $Version

    if ($File) {
        if ($Paths) {
            $Files = @($File)
        }

        if (!($NoRequirements)) {
            if ($null -eq $Script:ImportedModules) {
                $Script:ImportedModules = @((Get-PSXFormal -Module $Module -Version $Version))
            }

            $Requirements = Get-PSXModuleRequirements -Module $Module -Version $Version

            if ($Requirements) {
                $Requirements.GetEnumerator() | ForEach-Object {
                    if ($Script:ImportedModules -notcontains (Get-PSXFormal -Module $_.Key -Version $_.Value)) {
                        $Script:ImportedModules += $(Get-PSXFormal -Module $_.Key -Version $_.Value)

                        if ($Paths) {
                            $Files += @(Import-PSXModule -Module $_.Key -Version $_.Value -Paths)
                        }
                        else {
                            Import-PSXModule -Module $_.Key -Version $_.Value
                        }
                    }
                }
            }

            $Script:ImportedModules = $null
        }

        if ($Paths) {
            return $Files | Select-Object -Unique
        }
        else {
            try {
                Import-Module $File -Force -Global:$Global
            }
            catch {
                Write-Warning "Failed to Import Module '$(Get-PSXFormal -Module $Module -Version $Version)'."        
                return $false
            }
        }
    }
}

function Get-PSXModuleRequirements {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module,

        [parameter(Position = 1)]
        [string] $Version = 'latest'
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
        $Version = $IsFormal.Version
    }

    if ($Version -eq 'latest') {
        $Version = Get-PSXModuleLatest -Module $Module

        if ($Version -eq $false) {
            return $false
        }
    }

    if (Test-PSXVersionPath -Module $Module -Version $Version) {
        $RequirementsFile = Join-Path -Path (Join-Path -Path (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module) -ChildPath $Version) -ChildPath '.requirements'
        
        if (Test-Path -LiteralPath $RequirementsFile -PathType Leaf) {
            $Lines = @(Get-Content -LiteralPath $RequirementsFile)

            $Requirements = @{}

            foreach ($Line in $Lines) {
                $Line = $Line.Trim()

                if ($Line -match "^(?<module>[\w\-_]+)(?:\s*=\s*(?<version>$((Get-PSXConfiguration 'STVPIncompleteRegEx').Trim('^$'))|latest))?$") {
                    $ReqModule = $Matches.Module

                    if ($Matches.Version) {
                        $ReqVersion = $Matches.Version
                    }
                    else {
                        $ReqVersion = 'latest'
                    }

                    if ($ReqVersion -eq 'latest') {
                        $ReqVersion = Get-PSXModuleLatest -Module $ReqModule

                        if ($ReqVersion -eq $false) {
                            continue
                        }
                    }
                    
                    if ($ReqVersion.contains("*")) {
                        $MatchingVersions = Get-PSXVersions -Module $ReqModule -Pattern $ReqVersion
                        $ReqVersion = Get-PSXLatestVersion -Versions @($MatchingVersions.$ReqModule)
                    }

                    if (($ReqModule -eq $Module) -and ($ReqVersion -eq $Version)) {
                        Write-Warning "Module '$(Get-PSXFormal -Module $Module -Version $Version)' cannot require itself."
                        continue
                    }
                    else {
                        if ($Requirements.ContainsKey($ReqModule)) {
                            $MostRecentVersion = Get-PSXLatestVersion @($ReqVersion, $Requirements.$ReqModule)
                            if ($MostRecentVersion -eq $ReqVersion) {
                                $ReqVersion = $MostRecentVersion
                            }
                        }

                        if (Test-PSXVersion -Module $ReqModule -Version $ReqVersion) {
                            $Requirements.$ReqModule = $ReqVersion
                        }
                    }
                }
            }

            return $Requirements
        }
        else {
            return @{}
        }
    }
    else {
        Write-Warning "The Module '$(Get-PSXFormal -Module $Module -Version $Version)' does not exist."
        return @{}
    }
}

function Get-PSXVersions {
    param(
        [parameter(Position = 1)]
        [Alias('Name')]
        [string] $Module,

        [parameter(Position = 0)]
        [Alias('Incomplete', 'Partial', 'Expression', 'Filter')]
        [string] $Pattern = '*.*.*'
    )

    $Filters = @{
        Year  = '*'
        Major = '*'
        Minor = '*'
    }

    if ($Pattern -match (Get-PSXConfiguration 'STVPIncompleteRegEx')) {
        $Filters.Year = $Matches.year
        $Filters.Major = $Matches.major
        $Filters.Minor = $Matches.minor
    }
    else {
        Write-Warning "The Pattern '$Pattern' is not in the correct format (S.T.V.P.24.2.4 'Incomplete Representation')."
        return @()
    }

    $Versions = @{}

    $Modules = Get-PSXModules

    if ($Module) {
        $Modules = $Modules | Where-Object { $_ -eq $Module }
    }

    foreach ($Module in $Modules) {
        $Folders = Get-ChildItem -LiteralPath (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module) -Directory | Where-Object -Property Name -Match (Get-PSXConfiguration 'STVPRegEx')

        foreach ($Folder in $Folders) {
            $Components = Get-PSXVersionComponents -Version $Folder.Name

            if (($Components.Year -like $Filters.Year) -and ($Components.Major -like $Filters.Major) -and ($Components.Minor -like $Filters.Minor)) {
                $Versions.$Module += @($Folder.Name)
            }
        }
    }

    return $Versions
}

function Get-PSXModules {
    $Folders = Get-ChildItem -LiteralPath (Get-PSXConfiguration 'Modules') -Directory

    $Modules = @()

    foreach ($Folder in $Folders) {
        if (Get-ChildItem -LiteralPath $Folder.FullName -Directory | Where-Object -Property Name -Match (Get-PSXConfiguration 'STVPRegEx')) {
            $Modules += $Folder.Name
        }
    }

    return $Modules
}

function Get-PSXModuleFile {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module,

        [parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('V')]
        [string] $Version = 'latest'
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
        $Version = $IsFormal.Version
    }

    if ($Version -eq 'latest') {
        $Version = Get-PSXModuleLatest -Module $Module

        if ($Version -eq $false) {
            return $false
        }
    }

    if (Test-PSXVersionPath -Module $Module -Version $Version) {
        $Files = Get-ChildItem -LiteralPath (Join-Path -Path (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module) -ChildPath $Version)

        $Manifests = @($Files | Where-Object { $_.Extension -eq '.psd1' })
        if ($Manifests.Count -eq 1) {
            return $Manifests[0].FullName
        }
        elseif ($Manifests.Count -gt 1) {
            $AutoManifest = $Manifests | Where-Object { $_.BaseName -eq $Module }
            if ($AutoManifest) {
                return $AutoManifest.FullName
            }
        }

        $Scripts = @($Files | Where-Object { $_.Extension -eq '.psm1' })
        if ($Scripts.Count -eq 1) {
            return $Scripts[0].FullName
        }
        elseif ($Scripts.Count -gt 1) {
            $AutoScript = $Scripts | Where-Object { $_.BaseName -eq $Module }
            if ($AutoScript) {
                return $AutoScript.FullName
            }
        }

        $RemoteSource = @($Files | Where-Object { $_.name -eq '.src' })
        if ($RemoteSource.Count -eq 1) {
            $RemotePath = Get-Content -LiteralPath $RemoteSource[0].FullName -Raw
            if (Test-Path -LiteralPath $RemotePath -PathType Leaf) {
                return $RemotePath
            }
            else {
                Write-Warning "The Remote Source file listed in Module '$(Get-PSXFormal -Module $Module -Version $Version)' is inaccessible."
            }
        }
        elseif ($RemoteSource.Count -gt 1) {
            Write-Warning "There must only be one .SRC file per Version Found more than one in Module '$(Get-PSXFormal -Module $Module -Version $Version)'."        
        }

        Write-Warning "No Manifest, Script, or Remote Source file found for Module '$(Get-PSXFormal -Module $Module -Version $Version)'."
        return $false
    }
    else {
        Write-Warning "The Module '$(Get-PSXFormal -Module $Module -Version $Version)' does not exist."
        return $false
    }
}

function Test-PSXVersion {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module,

        [parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Version = 'latest'
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
        $Version = $IsFormal.Version
    }

    if ($Version -eq 'latest') {
        $Version = Get-PSXModuleLatest -Module $Module

        if ($Version -eq $false) {
            return $false
        }
    }

    if (Get-PSXModuleFile -Module $Module -Version $Version) {
        return $true
    }
    else {
        return $false
    }
}

function Test-PSXVersionPath {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Version
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
        $Version = $IsFormal.Version
    }

    return Test-Path -LiteralPath (Join-Path -Path (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module) -ChildPath $Version)
}

function Test-PSXModulePath {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Formal')]
        [string] $Module
    )

    $IsFormal = Test-PSXModuleIsFormal -Module $Module
    if ($IsFormal) {
        $Module = $IsFormal.Module
    }

    return Test-Path -LiteralPath (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module)
}

function Test-PSXModuleIsFormal {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'Module')]
        [string] $Formal
    )

    if ($Formal -match "^(?<module>[\w_\-]+):(?<version>$((Get-PSXConfiguration 'STVPRegEx').Trim('^$')))$") {
        return $Matches
    }
    else {
        return $false
    }
}

function Get-PSXLatestVersion {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [Alias("Version")]
        [string[]] $Versions
    )

    $Latest = $Versions | Sort-Object {
        $Components = Get-PSXVersionComponents -Version $_
        try {
            return [double]::Parse("$($Components.Major).$($Components.Minor)")
        }
        catch {
            return 0
        }
    } -Descending | Select-Object -First 1

    return $Latest
}

function Get-PSXModuleLatest {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $Module
    )

    if (Test-PSXModulePath -Module $Module) {
        $Versions = (Get-ChildItem -LiteralPath (Join-Path -Path (Get-PSXConfiguration 'Modules') -ChildPath $Module) -Directory).Name

        if ($null -eq $Versions) {
            Write-Warning "No Versions found for Module '$(Get-PSXFormal -Module $Module)'."
            return $false
        }
        
        $Latest = $Versions | Sort-Object {
            $Components = Get-PSXVersionComponents -Version $_
            try {
                return [double]::Parse("$($Components.Major).$($Components.Minor)")
            }
            catch {
                return 0
            }
        } -Descending | Select-Object -First 1

        return $Latest
    }
    else {
        Write-Warning "The Module '$(Get-PSXFormal -Module $Module)' does not exist."
        return $false
    }
}

function Get-PSXVersionComponents {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('V')]
        [string] $Version
    )

    if ($Version -match (Get-PSXConfiguration 'STVPRegEx')) {
        $Components = @{
            Year  = $Matches.year
            Major = $Matches.major
            Minor = $Matches.minor
        }

        if ($Matches.language) {
            $Components.Language = $Matches.language
        }

        return $Components
    }
    elseif ($Version -notmatch (Get-PSXConfiguration 'STVPRegEx')) {
        Write-Warning "The Version '$Version' is not in the correct format (S.T.V.P.24.2.4 'Syntax')."
        return $false
    }
}

function Get-PSXFormal {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string] $Module,

        [parameter(Position = 1)]
        [string] $Version
    )

    if (Test-PSXModuleIsFormal -Module $Module) {
        return $Module
    }

    $Formal = $Module.ToUpper()

    if ($Version -and ($Version -match (Get-PSXConfiguration 'STVPRegEx'))) {
        $Formal += ":$($Version.ToUpper())"
    }

    return $Formal
}