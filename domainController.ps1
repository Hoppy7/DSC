#Requires -module @{ModuleName = 'xActiveDirectory';ModuleVersion = '3.0.0.0'}
#Requires -module @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
#Requires -module @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.4.0.0'}


configuration domainController
{

Import-DscResource -ModuleName @{ModuleName = 'xActiveDirectory'; ModuleVersion = '3.0.0.0'}
Import-DscResource -ModuleName @{ModuleName = 'xStorage'; ModuleVersion = '3.4.0.0'}
Import-DscResource -ModuleName @{ModuleName = 'xPendingReboot'; ModuleVersion = '0.4.0.0'}
Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

# When using with Azure Automation, modify these values to match your stored credential names
$domainCredential = Get-AutomationPSCredential 'localadmin'

    node localhost
    {
        WindowsFeature ADDSInstall
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }
        
        xWaitforDisk Disk2
        {
            DiskId = 2
            RetryIntervalSec = 10
            RetryCount = 30
        }
        
        xDisk DiskF
        {
            DiskId = 2
            DriveLetter = 'F'
            DependsOn = '[xWaitforDisk]Disk2'
        }
        
        xPendingReboot BeforeDC
        {
            Name = 'BeforeDC'
            SkipCcmClientSDK = $true
            DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF'
        }
        
        # Configure domain values here
        xADDomain Domain
        {
            DomainName = $configurationData.nonNodeData.domainName
            DomainAdministratorCredential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
            DatabasePath = $configurationData.nonNodeData.databasePath
            LogPath = $configurationData.nonNodeData.logPath
            SysvolPath = $configurationData.nonNodeData.sysvolPath
            DependsOn = '[WindowsFeature]ADDSInstall','[xDisk]DiskF','[xPendingReboot]BeforeDC'
        }
        
        Registry DisableRDPNLA
        {
            Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'
            ValueName = 'UserAuthentication'
            ValueData = 0
            ValueType = 'Dword'
            Ensure = 'Present'
            DependsOn = '[xADDomain]Domain'
        }
    }
}
