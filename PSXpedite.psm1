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
#    Version:        24.1.0                                                                        #
#                                                                                                  #
#    Name:           PSXPEDITE                                                                     #
#    Title:          FILE-BASED POWERSHELL MODULE AND VERSION DISTRIBUTION SYSTEM                  #
#    Description:    PSXPEDITE IS A POWERSHELL MODULE THAT INTRODUCES A FILE-BASED MODULE AND      #
#                    VERSION DISTRIBUTION AND STORAGE SYSTEM.                                      #
#    Language:       POWERSHELL                                                                    #
#    Contributor(s): MDELAND002                                                                    #
#    Created:        2024-04-15                                                                    #
#    Updated:        2024-05-06                                                                    #
#                                                                                                  #
#    SNAF:           [PSXPEDITE24.1.0 ¦ LEVEL-0] - FILE-BASED POWERSHELL MODULE AND VERSION        #
#                    DISTRIBUTION SYSTEM                                                           #
#    DRL:            DRL://AFS/IT/DPD/PSXPEDITE                                                    #
#    DID:            UDIS-0000000000000000000Z                                                     #
#    Location:                                                                                     #
#                                                                                                  #
#    2024 (c) THE A.F.S. CORPORATION. All rights reserved.                                         #
#                                                                                                  #
####################################################################################################

# ========== Configuration ========== #
$Script:PSXConfiguration = @{
    ModulesRoot            = "$PSScriptRoot\Modules"
    VersionRegEx           = '^(?<year>\d{1,2})\.(?<major>\d+)\.(?<minor>\d+)(?:\.(?<build>\d+))?(?:\-(?<language>[a-zA-Z]{2}))?$'
    VersionIncompleteRegEx = '^(?<year>\d{1,2}|\*)\.(?<major>\d+|\*)\.(?<minor>\d+|\*)(?:\.(?<build>\d+|\*))?(?:\-(?<language>[a-zA-Z]{2}))?$'
    Name                   = 'PSXPEDITE:24.1.0'
    Version                = '24.1.0'
    VersionFilterRegEx     = "^(?<year>\d{1,2}|\*)\.(?<major>\d+|\*)\.(?<minor>\d+|\*)$"
    ModuleFileExtensions   = @("psd1", "psm1", "dll")
    MaxRequirementsDepth   = 10
    AllowedModuleNameChars = "[a-zA-Z_\-\.]"
}

function Get-PsxConf {
    param(
        [Alias("Name", "Setting")]
        [string] $Key,

        [Alias("Default", "Value")]
        [object] $Fallback
    )

    if ($Key) {
        if ($Script:PSXConfiguration.ContainsKey($Key)) {
            return $Script:PSXConfiguration[$Key]
        }
        else {
            if ($Fallback) {
                return $Fallback
            }
            else {
                return $null
            }
        }
    }
    else {
        return $Script:PSXConfiguration
    }
}

function Set-PsxConf {
    param(
        [parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SetAll')]
        [Alias("Configuration", "Settings")]
        [hashtable] $Conf,

        [parameter(Mandatory = $true, Position = 0, ParameterSetName = 'SetOne')]
        [Alias("Name", "Setting")]
        [string] $Key,

        [parameter(Mandatory = $true, Position = 1, ParameterSetName = 'SetOne')]
        [object] $Value
    )

    if ($PSCmdlet.ParameterSetName -eq 'SetAll') {
        $Script:PSXConfiguration = $Conf
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'SetOne') {
        $Script:PSXConfiguration[$Key] = $Value
    }
    else {
        throw 'Unable to determine parameter set'
    }
}
# =================================== #

<#
.SYNOPSIS
Imports a Module and its requirements.

.DESCRIPTION
This function imports a Module and its requirements.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.PARAMETER Local
Whether to import the Module locally.

.PARAMETER Global
Whether to import the Module globally.

.PARAMETER NoRequirements
Whether to import the Module without its requirements.

.EXAMPLE
Get-PsxModule -Module "CoolHat" -Version "22.0.10" -Local

.NOTES
If neither Local nor Global is specified, the function will return the paths to the Module files.
#>
function Get-PsxModule {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version = "latest",

        [Alias("Locally")]
        [switch] $Local,

        [Alias("Globally")]
        [switch] $Global,

        [Alias("Solo", "Single")]
        [switch] $NoRequirements
    )

    if (Test-PsxModulePath -Module $Module) {
        if ($Version -eq "latest") {
            try {
                $Version = Get-PsxModuleLatest -Module $Module
            }
            catch {
                throw "Failed to get latest Version for Module '$Module': $_"
            }
        }
        
        $ModuleFiles = @()
        if (!($NoRequirements)) {
            $ModuleFiles += @(Get-PsxVersionRequirementFiles -Module $Module -Version $Version)
        }
        $ModuleFiles += (Get-PsxVersionFile -Module $Module -Version $Version)

        if ($Local) {
            Import-Module -LiteralPath $ModuleFiles -Force
        }
        elseif ($Global) {
            Import-Module -LiteralPath $ModuleFiles -Global -Force
        }
        else {
            return $ModuleFiles
        }
    }
}

<#
.SYNOPSIS
Returns the requirement files of a Module Version.

.DESCRIPTION
This function returns the requirement files of a Module Version.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.EXAMPLE
Get-PsxVersionRequirementFiles -Module "CoolHat" -Version "22.0.10"
#>
function Get-PsxVersionRequirementFiles {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version
    )

    if (Test-PsxVersionPath -Module $Module -Version $Version) {
        $Requirements = Get-PsxVersionRequirements -Module $Module -Version $Version -Depth (Get-PsxConf -Key 'MaxRequirementsDepth')

        $RequirementFiles = @()

        $Requirements.GetEnumerator() | ForEach-Object {
            $Req = $_

            if ($Req.Key.StartsWith("PSMP-")) {
                try {
                    $PSMPFIle = (Get-Module -Name ($Req.Key).Substring(5) -ListAvailable | Where-Object { $_.Version -like $Req.Value } | Select-Object -First 1).Path
                    if ($PSMPFIle) {
                        $RequirementFiles += $PSMPFIle
                    }
                    else {
                        Write-Warning "Failed to get requirement file for PowerShell module '$(($Req.Key).Substring(5))' Version '$($Req.Value)'"
                    }
                }
                catch {
                    Write-Warning "Failed to get requirement file for Module '$($($Req.Key).Substring(5))' Version '$($Req.Value)': $_"
                }
            }
            else {
                try {
                    $RequirementFiles += Get-PsxVersionFile -Module $Req.Key -Version $Req.Value
                }
                catch {
                    Write-Warning "Failed to get requirement file for Module '$($Req.Key)' Version '$($Req.Value)': $_"
                }
            }
        }

        return $RequirementFiles
    }
    else {
        throw "Module '$Module' Version '$Version' is not registered in '$(Get-PsxConf -Key 'Name')'"
    }
}

<#
.SYNOPSIS
Returns the requirements of a Module Version.

.DESCRIPTION
This function returns the requirements of a Module Version.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.PARAMETER Depth
The maximum depth to search for requirements.

.EXAMPLE
Get-PsxVersionRequirements -Module "CoolHat" -Version "22.0.10"
#>
function Get-PsxVersionRequirements {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version,
        
        [Alias("Limit", "TTL")]
        [int] $Depth = (Get-PsxConf -Key 'MaxRequirementsDepth' -Default 5)
    )

    if (Test-PsxVersionPath -Module $Module -Version $Version) {
        $VersionPath = (Get-PsxVersionPath -Module $Module -Version $Version)
        $RequirementsPath = Join-Path -Path $VersionPath -ChildPath ".requirements"

        if (Test-Path -LiteralPath $RequirementsPath -PathType Leaf) {
            $Requirements = @{}

            $ReqLineRegEx = "^(?<module>$(Get-PsxConf "AllowedModuleNameChars")+)(?:\s*=\s*(?<version>$((Get-PsxConf 'VersionIncompleteRegEx').Trim('^$'))|latest))?$"
            
            $Lines = Get-Content -LiteralPath $RequirementsPath

            foreach ($Line in $Lines) {
                if ($Line -match $ReqLineRegEx) {
                    $ReqMod = $Matches.Module
                    if ($Matches.Version) {
                        $ReqVer = $Matches.Version
                    }
                    else {
                        $ReqVer = "latest"
                    }

                    if (!(Test-PsxModulePath -Module $ReqMod)) {
                        $ReqMod = "PSMP-$ReqMod"
                    }

                    if ($ReqVer -eq "latest" -and !($ReqMod.StartsWith("PSMP-"))) {
                        try {
                            $ReqVer = Get-PsxModuleLatest -Module $ReqMod
                        }
                        catch {
                            $ReqMod = "PSMP-$ReqMod"
                        }
                    }

                    if ($ReqVer -eq "latest") {
                        $ReqVer = "*"
                    }
                    
                    if ($ReqVer.Contains("*") -and !($ReqMod.StartsWith("PSMP-"))) {
                        $ReqVer = Get-PsxLatestVersion -Versions (Get-PsxMatchingVersions -Pattern $ReqVer -Versions (Get-PsxVersions -Module $ReqMod))
                    }

                    if (!($ReqMod.StartsWith("PSMP-"))) {
                        if ($Module -ne $ReqMod -and $Version -ne $ReqVer -and (Test-PsxVersionPath -Module $ReqMod -Version $ReqVer)) {
                            $Requirements[$ReqMod] = $ReqVer

                            if ($Depth -gt 0) {
                                $ReqReqs = Get-PsxVersionRequirements -Module $ReqMod -Version $ReqVer -Depth ($Depth - 1)
                                foreach ($ReqReq in $ReqReqs.Keys) {
                                    if ($Requirements.ContainsKey($ReqReq) -eq $false) {
                                        $Requirements[$ReqReq] = $ReqReqs[$ReqReq]
                                    }
                                    else {
                                        if ($Requirements[$ReqMod] -ne $ReqVer) {
                                            $Requirements[$ReqMod] = Get-PsxLatestVersion -Versions @($Requirements[$ReqMod], $ReqVer)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        $Requirements[$ReqMod] = $ReqVer
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
        throw "Module '$Module' Version '$Version' is not registered in '$(Get-PsxConf -Key 'Name')'"
    }
}

<#
.SYNOPSIS
Returns the path to the specified Module Version file.

.DESCRIPTION
This function returns the path to the specified Module Version file.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.EXAMPLE
Get-PsxVersionFile -Module "CoolHat" -Version "22.0.10"
#>
function Get-PsxVersionFile {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version
    )

    if (Test-PsxVersionPath -Module $Module -Version $Version) {
        $FileExtensions = (Get-PsxConf -Key 'ModuleFileExtensions')

        $VersionPath = (Get-PsxVersionPath -Module $Module -Version $Version)
        foreach ($FileExtension in $FileExtensions) {
            $ExtensionFiles = @(Get-ChildItem -LiteralPath $VersionPath -File | Where-Object { $_.Extension -eq ".$FileExtension" })

            if ($ExtensionFiles.Count -gt 1) {
                if ($ExtensionFiles.Name -contains "$Module.$FileExtension") {
                    return ($ExtensionFiles | Where-Object { $_.Name -eq "$Module.$FileExtension" }).FullName
                }
                else {
                    throw "Multiple '$FileExtension' files found for Version '$Version' of Module '$Module'"
                }
            }
            elseif ($ExtensionFiles.Count -eq 1) {
                return ($ExtensionFiles[0]).FullName
            }
            else {
                continue
            }
        }

        $ExternalSourcePath = Join-Path -Path $VersionPath -ChildPath ".SRC"
        if (Test-Path -LiteralPath $ExternalSourcePath -PathType Leaf) {
            $ExternalSource = Get-Content -LiteralPath $ExternalSourcePath -Raw

            if (Test-Path -LiteralPath $ExternalSource -PathType Leaf) {
                return $ExternalSource
            }
        }

        throw "No file found for Version '$Version' of Module '$Module'"
    }
    else {
        throw "Module '$Module' Version '$Version' is not registered in '$(Get-PsxConf -Key 'Name')'"
    }
}

<#
.SYNOPSIS
Returns the latest Version of a Module.

.DESCRIPTION
This function returns the latest Version of a Module.

.PARAMETER Module
The name of the Module.

.EXAMPLE
Get-PsxModuleLatest -Module "CoolHat"
#>
function Get-PsxModuleLatest {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
        [string] $Module
    )

    if ($Module -and (Test-PsxModulePath -Module $Module)) {
        $Latest = Get-PsxLatestVersion -Versions (Get-PsxVersions -Module $Module)
    }
    else {
        throw "Module '$Module' is not registered in '$(Get-PsxConf -Key 'Name')'"
    }

    return $Latest
}

<#
.SYNOPSIS
Returns the latest Version from a list of Versions.

.DESCRIPTION
This function returns the latest Version from a list of Versions.

.PARAMETER Versions
The Versions to get the latest Version from.

.EXAMPLE
Get-PsxLatestVersion -Versions @("22.2.12", "54.2.11", "00.0.0", "12.3.4-NO")
#>
function Get-PsxLatestVersion {
    param(
        [Alias("Version")]
        [string[]] $Versions = @()
    )

    return (Get-PsxSortedVersions -Versions $Versions -Descending:$true) | Select-Object -First 1
}

<#
.SYNOPSIS
Sorts the Versions in ascending or descending order.

.DESCRIPTION
This function sorts a list of Versions in ascending or descending order based on the Major and Minor components.

.PARAMETER Versions
The Versions to be sorted.

.PARAMETER Descending
Whether to sort the Versions in descending order.

.EXAMPLE
Get-PsxSortedVersions -Versions @("22.2.12", "54.2.11", "00.0.0", "12.3.4-NO")

.NOTES
The way it works right now is absolute bullshit. I have to fix it someday.
#>
function Get-PsxSortedVersions {
    param(
        [Alias("Version")]
        [string[]] $Versions = @(),

        [Alias("Desc")]
        [switch] $Descending
    )

    $versionMap = @{}
    $Versions | ForEach-Object {
        if ($_ -match (Get-PsxConf -Key 'VersionRegEx')) {
            $strippedVersion = "$($Matches.Major).$($Matches.Minor)"
            $versionMap[$strippedVersion] = $_
        }
        else {
            $versionMap[$_] = $_
        }
    }

    $sortedStrippedVersions = [Version[]]($versionMap.Keys) | Sort-Object -Descending:$Descending

    $sortedFullVersions = $sortedStrippedVersions | ForEach-Object { $versionMap[$_.ToString()] }

    return [string[]]$sortedFullVersions
}

<#
.SYNOPSIS
Returns a list of registered Versions.

.DESCRIPTION
This function returns a list of Versions registered in PSXpedite or in a specific Module and matching a specified Pattern.

.PARAMETER Module
The Module to get the Versions of.

.PARAMETER Pattern
The Pattern to match against.

.EXAMPLE
Get-PsxVersions -Module "CoolHat" -Pattern "22.*.*"

.EXAMPLE
Get-PsxVersions -Pattern "22.*.*"
#>
function Get-PsxVersions {
    param(
        [Alias("Name")]
        [string] $Module,

        [Alias("Filter")]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionFilterRegEx') })]
        [string] $Pattern = "*.*.*"
    )

    if ($Module) {
        if (Test-PsxModulePath -Module $Module) {
            $Modules = @($Module)
        }
        else {
            $Modules = @()
        }
    }
    else {
        $Modules = Get-PsxModules
    }
    
    $Versions = @{}

    foreach ($Module in $Modules) {
        $Versions[$Module] = @(Get-PsxMatchingVersions -Pattern $Pattern -Versions @((Get-ChildItem -LiteralPath (Get-PsxModulePath -Module $Module) -Directory | Where-Object { $_.Name -match (Get-PsxConf 'VersionIncompleteRegEx') }).Name))
    }

    if ($Modules.Count -eq 1) {
        return $Versions[$Modules[0]]
    }
    else {
        return $Versions
    }
}

<#
.SYNOPSIS
Returns the Versions that match the specified Pattern.

.DESCRIPTION
This function returns the Versions that match the specified Pattern.

.PARAMETER Pattern
The Pattern to match against.

.PARAMETER Versions
The Versions to test.

.EXAMPLE
Get-PsxMatchingVersions -Pattern "22.*.*" -Versions @("22.0.10", "23.0.1", "24.0.11", "33.0.0-EN", "4.89.849327")
#>
function Get-PsxMatchingVersions {
    param(
        [Alias("Filter")]
        [string] $Pattern = "*.*.*",

        [Alias("Version")]
        [string[]] $Versions = @()
    )

    $MatchingVersions = @()

    foreach ($Version in $Versions) {
        if ($Version -and (Test-PsxVersionMatch -Version $Version -Pattern $Pattern)) {
            $MatchingVersions += $Version
        }
    }

    return $MatchingVersions
}

<#
.SYNOPSIS
Tests if the specified Version matches the specified Pattern.

.DESCRIPTION
This function tests if the specified Version matches the specified Pattern.

.PARAMETER Version
The Version to test.

.PARAMETER Pattern
The Pattern to test against.

.EXAMPLE
Test-PsxVersionMatch -Version "22.0.10" -Pattern "22.*.*"
#>
function Test-PsxVersionMatch {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Versions")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionIncompleteRegExs') })]
        [string] $Version,

        [Alias("Filter")]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionFilterRegEx') })]
        [string] $Pattern = "*.*.*"
    )
    
    $Components = Get-PsxVersionComponents -Version $Version
    $PatternComponents = Get-PsxVersionFilterComponents -Version $Pattern

    return (
        $Components.Year -like $PatternComponents.Year -and
        $Components.Major -like $PatternComponents.Major -and
        $Components.Minor -like $PatternComponents.Minor
    )
}

<#
.SYNOPSIS
Returns the components of the specified Version Filter.

.DESCRIPTION
This function returns the components of the specified Version Filter.

.PARAMETER Version
The Version Filter to get the components of.

.EXAMPLE
Get-PsxVersionFilterComponents -Version "22.*.*"
#>
function Get-PsxVersionFilterComponents {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionFilterRegEx') })]
        [string] $Version
    )

    if ($Version -match (Get-PsxConf -Key 'VersionFilterRegEx')) {
        return @{
            Year  = $Matches.Year
            Major = $Matches.Major
            Minor = $Matches.Minor
        }
    }
    else {
        @{
            Year  = "*"
            Major = "*"
            Minor = "*"
        }
    }

}

<#
.SYNOPSIS
Returns the components of the specified Version.

.DESCRIPTION
This function returns the components of the specified Version.

.PARAMETER Version
The Version to get the components of.

.EXAMPLE
Get-PsxVersionComponents -Version "22.0.10"
#>
function Get-PsxVersionComponents {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version
    )

    if ($Version -match (Get-PsxConf -Key 'VersionRegEx')) {
        $Components = @{
            Version = $Version
            Year    = $Matches.Year
            Major   = $Matches.Major
            Minor   = $Matches.Minor
        }

        if ($Matches.Language) {
            $Components.Language = $Matches.Language
        }

        return $Components
    }
    else {
        @{}
    }
}

<#
.SYNOPSIS
Returns the names of all registered Modules.

.DESCRIPTION
This function returns the names of all registered Modules.

.EXAMPLE
Get-PsxModules
#>
function Get-PsxModules {
    return (Get-ChildItem -LiteralPath (Get-PsxDefaultModulesPath) -Directory | Where-Object { $_.Name.StartsWith(".") -eq $false }).Name
}

<#
.SYNOPSIS
Tests if the specified Module Version exists.

.DESCRIPTION
This function tests if the specified Module Version exists.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.EXAMPLE
Test-PsxVersionPath -Module "CoolHat" -Version "22.0.10"
#>
function Test-PsxVersionPath {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version
    )

    return (Test-Path -LiteralPath (Get-PsxVersionPath -Module $Module -Version $Version) -PathType Container)
}

<#
.SYNOPSIS
Tests if the specified Module exists.

.DESCRIPTION
This function tests if the specified Module exists.

.PARAMETER Module
The name of the Module.

.EXAMPLE
Test-PsxModulePath -Module "CoolHat"
#>
function Test-PsxModulePath {
    param(
        [Alias("Name")]
        [string] $Module
    )

    if ([string]::IsNullOrEmpty($Module)) {
        return $false
    }

    return (Test-Path -LiteralPath (Get-PsxModulePath -Module $Module) -PathType Container)
}

<#
.SYNOPSIS
Returns the path to the specified Module Version.

.DESCRIPTION
This function returns the path to the specified Module Version.

.PARAMETER Module
The name of the Module.

.PARAMETER Version
The Version of the Module.

.EXAMPLE
Get-PsxVersionPath -Module "CoolHat" -Version "22.0.10"
#>
function Get-PsxVersionPath {
    param(
        [parameter(Mandatory = $true, Position = 0)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module,

        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -match (Get-PsxConf -Key 'VersionRegEx') })]
        [string] $Version
    )

    return (Join-Path -Path (Get-PsxModulePath -Module $Module) -ChildPath $Version)

}

<#
.SYNOPSIS
Returns the path to the specified Module.

.DESCRIPTION
This function returns the path to the specified Module.

.PARAMETER Module
The name of the Module.

.EXAMPLE
Get-PsxModulePath -Module "CoolHat"
#>
function Get-PsxModulePath {
    param(
        [parameter(Mandatory = $true)]
        [Alias("Name")]
        [ValidateNotNullOrEmpty()]
        [string] $Module
    )

    return (Join-Path -Path (Get-PsxDefaultModulesPath) -ChildPath $Module)
}

function Get-PsxDefaultModulesPath {
    return (Get-PsxConf -Key 'ModulesRoot' -Default (Join-Path -Path $PSScriptRoot -ChildPath "Modules"))
}