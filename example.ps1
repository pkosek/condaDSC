
Configuration CondaPackageInstallerExample {
    
    Import-DscResource -ModuleName CondaDSC
    
    CondaPackageInstaller conda-build {
        Ensure      = 'Present'
        PackageName = 'conda-build'
        Version = '3.18.0'
    }
}