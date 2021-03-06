function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackageName,
        
        [System.String]
        $CondaPath,
        
        [System.String]
        $Channel,

        [parameter(Mandatory = $false)]
        [System.String]
        $Version

    )

    Write-Verbose "Checking whether [$PackageName] Conda Package is installed"

    if (-not($CondaPath)) {
        try {
            $CondaPath = (Get-Command conda -ErrorAction Stop).Path
        }
        catch {
            Throw "Cannot find conda.bat in `$env:Path!"
        }
    }

    $CondaListOutput = & $CondaPath list $PackageName --show-channel-urls --json | ConvertFrom-Json

    #find the correct version of the package
    if ($Version) {
        $CondaPackage = $CondaListOutput | Where-Object {$_.Version -eq $Version}
    }
    elseif ($CondaListOutput -and (-not ($CondaListOutput.Error))) {
        Write-Verbose "Version not specified, using latest available"
        $CondaPackage = $CondaListOutput | sort-object Version -Descending | Select-Object -First 1
    }

    if ($CondaPackage) {
        $Ensure = 'Present'
    }
    else {
        $Ensure = 'Absent'
    }

    $returnValue = @{
        PackageName     = $CondaPackage.Name
        Ensure          = $Ensure
        Params          = $Params
        Channel         = $CondaPackage.Channel
        Version         = $CondaPackage.Version
        CondaPath       = $CondaPath
    }

    $returnValue
}

function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackageName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Params,

        [System.String]
        $Channel,

        [parameter(Mandatory = $false)]
        [System.String]
        $Version,

        [System.String]
        $CondaPath
    )

    if (-not($CondaPath)) {
        try {
            $CondaPath = (Get-Command conda -ErrorAction Stop).Path
        }
        catch {
            Throw "Cannot find conda.bat in `$env:Path!"
        }
    }
    if (-not($Version)){  
        Write-Verbose "Version not specified, using latest available"
        $Version = "Latest"
    }

    if ($Ensure -eq 'Present') {
        Write-Verbose "Installing package [$PackageName=$Version]..."
        
        if ($Channel) {
            Write-Verbose -Message "Using Channel [$Channel]"
            cmd /c "$CondaPath install $PackageName==$Version --yes -override-channels -c $Channel"
        }
        elseif ($Channel -and ($Version -eq "Latest")) { 
            Write-Verbose -Message "Using Channel [$Channel]"
            cmd /c "$CondaPath install $PackageName --yes -override-channels -c $Channel"
        } 
        elseif ((-not $Channel) -and ($Version -ne "Latest")) {
            cmd /c "$CondaPath install $PackageName==$Version --yes"
        }
        elseif ((-not $Channel) -and ($Version -eq "Latest")) {
            cmd /c "$CondaPath install $PackageName --yes"
        }
    }

    elseif (($Ensure -eq 'Absent') -and ($Version -ne "Latest")) {
        Write-Verbose "Uninstalling package [$PackageName=$Version]..."
            cmd /c "$CondaPath uninstall $PackageName==$Version --yes"
    }
    elseif (($Ensure -eq 'Absent') -and ($Version -eq "Latest")) {
        Write-Verbose "Uninstalling package [$PackageName]..."
        cmd /c "$CondaPath uninstall $PackageName --yes"
    }
}

function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $PackageName,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure,

        [System.String]
        $Params,

        [System.String]
        $Channel,

        [System.String]
        $Version,

        [System.String]
        $CondaPath
    )

    $result = [System.Boolean]
    
    if (-not($CondaPath)) {
        try {
            $CondaPath = (Get-Command conda -ErrorAction Stop).Path
        }
        catch {
            Throw "Cannot find conda.bat in `$env:Path!"
        }
    }

    if (-not($Version)){
        if ($Channel) {
            Write-Verbose "Querying channel [$Channel] for latest version of [$PackageName]"
            $CondaSearchOutput = & $CondaPath search $PackageName --json --override-channels -c $Channel | ConvertFrom-Json
        }
        else {
            Write-Verbose "Querying default channels for latest version of [$PackageName]"
            $CondaSearchOutput = & $CondaPath search $PackageName --json | ConvertFrom-Json
        }
        if ($CondaSearchOutput.Error) {
            throw $CondaSearchOutput.Error
        }
        $LatestPackegeAvailable = $CondaSearchOutput.$PackageName | Sort-Object version -Descending | Select-Object -First 1
        $Version = $LatestPackegeAvailable.Version.replace("post00","post")
        Write-Verbose "Found latest version [$Version)] on channel [$($LatestPackegeAvailable.Channel)]"
    }

    Write-Verbose "Checking whether [$PackageName=$Version] Conda Package is installed"
    
    $CondaOutput = & $CondaPath list $PackageName --show-channel-urls --json | ConvertFrom-Json
    
    #find the correct version of the package
    $CondaPackage = $CondaOutput | Where-Object {$_.version -eq $Version}
    
    if (($CondaPackage) -and ($Ensure -eq 'Present')) {
        Write-Verbose -Message "Package [$PackageName=$Version] is already installed"
        $result = $true
    }
    elseif (($CondaPackage) -and ($Ensure -eq 'Absent')) {
        Write-Verbose -Message "Package [$PackageName=$Version] is installed and should be removed"
        $result = $false
    }
    elseif ((-not($CondaPackage) -and ($Ensure -eq 'Present'))) {
        Write-Verbose -Message "Package [$PackageName=$Version] is not installed and should be installed"
        $result = $false
    }
    else {
        Write-Verbose -Message "Package [$PackageName=$Version] is already uninstalled"
        $result = $true
    }

    $result
}

Export-ModuleMember -Function *-TargetResource