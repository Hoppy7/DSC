configuration sqlAlwaysOnAvailabilityGroup
{
    # import dsc modules
    Import-DscResource -ModuleName xPSDesiredStateConfiguration -ModuleVersion 8.6.0.0
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion 12.4.0.0
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion 6.3.0.0
    Import-DscResource -ModuleName xFailOverCluster -ModuleVersion 1.12.0.0
    Import-DscResource -ModuleName StorageDsc -ModuleVersion 4.6.0.0
    Import-DscResource -ModuleName SecurityPolicyDsc -ModuleVersion 2.8.0.0

    # format the IP addresses to be consumed by the high availabilty resources
    $clusterIPandSubNetClass = $configurationData.nonNodeData.clusterStaticIP + "/" + $configurationData.nonNodeData.clusterIPSubnetClass
    $listenerIPandMask = $configurationData.nonNodeData.listenerStaticIP + "/" + $configurationData.nonNodeData.listenerSubnetMask

    # credentials
    $sqlSvcAccount = Get-AutomationPSCredential -Name "SQLSvcAccount"
    $domainAdmin = Get-AutomationPSCredential -Name "domainAdmin"

    # base configuration
    Node $AllNodes.nodeName
    {   
        # lcm
        LocalConfigurationManager
        {
            AllowModuleOverwrite           = $true
            ConfigurationMode              = "ApplyAndAutoCorrect" # accepted values: ApplyOnly, ApplyAndMonitor, ApplyAndAutoCorrect
            RebootNodeIfNeeded             = $true
            ActionAfterReboot              = "ContinueConfiguration"
            ConfigurationModeFrequencyMins = 15
            RefreshMode                    = "Push"
            RefreshFrequencyMins           = 30
        }
        
        # drive configuration
        # data drive
        WaitForDisk dataDrive
        { 
            DiskId           = 2
            RetryIntervalSec = 60
            RetryCount       = 60
        }

        Disk dataDrive
        {
            DiskId             = 2
            DriveLetter        = $configurationData.nonNodeData.sqlDatadriveLetter
            FSFormat           = "NTFS"
            AllocationUnitSize = 64kb
            DependsOn          = "[WaitForDisk]dataDrive"
        }

        # log drive
        WaitForDisk logDrive
        {
            DiskId           = 3
            RetryIntervalSec = 60
            RetryCount       = 60
        }

        Disk logDrive
        {
            DiskId             = 3
            DriveLetter        = $configurationData.nonNodeData.sqlLogdriveLetter
            FSFormat           = "NTFS"
            AllocationUnitSize = 64kb
            DependsOn          = "[WaitForDisk]logDrive"
        }

        # temp db drive
        WaitForDisk tempDbDrive
        {
            DiskId           = 4
            RetryIntervalSec = 60
            RetryCount       = 60
        }

        Disk tempDbDrive
        {
            DiskId             = 4
            DriveLetter        = $configurationData.nonNodeData.sqlTempdbdriveLetter
            FSFormat           = "NTFS"
            AllocationUnitSize = 64kb
            DependsOn          = "[WaitForDisk]tempDbDrive"
        }

        # windows features
        WindowsFeature NET-Framework45-Core
        {
            Name   = "NET-Framework-45-Core"
            Ensure = "Present"
        }

        WindowsFeature NET-Framework-Core
        {
            Name                 = "NET-Framework-Core"
            Ensure               = "Present"
            IncludeAllSubFeature = $true
        }

        WindowsFeature Failover-Clustering
        {
            Name   = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature RSAT-Clustering-Mgmt
        { 
            Name      = "RSAT-Clustering-Mgmt"
            Ensure    = "Present" 
			DependsOn = "[WindowsFeature]Failover-Clustering"
        } 

        WindowsFeature RSAT-Clustering-PowerShell
        {
            Name   = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature RSAT-AD-PowerShell
        {
            Name   = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        # power plan
        PowerPlan highPerf
        {
            Name             = "High performance"
            IsSingleInstance = "Yes"
        }
        
        # time zone
        TimeZone timeZone
        {
            TimeZone         = $configurationData.nonNodeData.timeZone
            IsSingleInstance = "Yes"
        }

        # sql install
        SqlSetup sqlSetup
        {
            InstanceName        = $configurationData.nonNodeData.sqlInstanceName
            Features            = $configurationData.nonNodeData.sqlFeatures
            SQLCollation        = $configurationData.nonNodeData.sqlCollation
            SQLSvcAccount       = $sqlSvcAccount
            AgtSvcAccount       = $sqlSvcAccount
            ASSvcAccount        = $sqlSvcAccount
            ASSysAdminAccounts  = $configurationData.nonNodeData.SQLSysAdmins
            SQLSysAdminAccounts = $configurationData.nonNodeData.SQLSysAdmins
            InstallSharedDir    = "C:\Program Files\Microsoft SQL Server"
            InstallSharedWOWDir = "C:\Program Files (x86)\Microsoft SQL Server"
            InstanceDir         = "C:\Program Files\Microsoft SQL Server"
            InstallSQLDataDir   = "$($configurationData.nonNodeData.sqlDatadriveLetter):\SQLData"
            SQLUserDBDir        = "$($configurationData.nonNodeData.sqlDatadriveLetter):\SQLData"
            SQLUserDBLogDir     = "$($configurationData.nonNodeData.sqlLogdriveLetter):\SQLLogs"
            SQLTempDBDir        = "$($configurationData.nonNodeData.sqlTempdbdriveLetter):\SQLTempDB"
            SQLTempDBLogDir     = "$($configurationData.nonNodeData.sqlLogdriveLetter):\SQLLogs"
            SourcePath          = $configurationData.nonNodeData.sqlSourcePath
            SecurityMode        = $configurationData.nonNodeData.sqlSecurityMode
            SAPwd               = $domainAdmin
        }
        
        # sql services
        Service MSSQLSERVER
        {
            Name        = "MSSQLSERVER"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        Service MSSQLServerOLAPService
        {
            Name        = "MSSQLServerOLAPService"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        Service SQLBrowser
        {
            Name        = "SQLBrowser"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        Service SQLSERVERAGENT
        {
            Name        = "SQLSERVERAGENT"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        Service SQLTELEMETRY
        {
            Name        = "SQLTELEMETRY"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        Service SQLWriter
        {
            Name        = "SQLWriter"
            StartupType = "Automatic"
            State       = "Running"
            Ensure      = "Present"
            DependsOn   = "[SqlSetup]sqlSetup"
        }

        # sql login
        SqlServerLogin sqlLogin
        {
            Name                 = "NT SERVICE\ClusSvc"
            ServerName           = $configurationData.nonNodeData.primaryNode
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            LoginType            = "WindowsUser"
            Ensure               = "Present"
            DependsOn            = "[SqlSetup]sqlSetup"
            PsDscRunAsCredential = $domainAdmin
        }

        # Add the required permissions to the cluster service login
        SqlServerPermission sqlPermissions
        {
            ServerName           = $configurationData.nonNodeData.primaryNode
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            Principal            = "NT SERVICE\ClusSvc"
            Permission           = "ConnectSql", "AlterAnyAvailabilityGroup", "ViewServerState"
            Ensure               = "Present"
            DependsOn            = "[SqlServerLogin]sqlLogin"
            PsDscRunAsCredential = $domainAdmin
        }
        
        # sql network configuration
        SqlServerNetwork sqlNetworkConfiguration
        {
            InstanceName   = $configurationData.nonNodeData.sqlInstanceName
            ProtocolName   = "Tcp"
            IsEnabled      = $true
            TCPDynamicPort = $false
            TCPPort        = $configurationData.nonNodeData.sqlPort
            RestartService = $true       
            DependsOn      = "[SqlSetup]sqlSetup"
        }

        # sql firewall
        SqlWindowsFirewall sqlFirewallRules
        {
            InstanceName = $configurationData.nonNodeData.sqlInstanceName
            Features     = $configurationData.nonNodeData.sqlFeatures
            SourcePath   = $configurationData.nonNodeData.sqlSourcePath
            Ensure       = "Present"
            DependsOn    = "[SqlSetup]sqlSetup"
        }
    }

    # primary node
    Node $AllNodes.Where{$_.role -contains "sqlAGPrimary"}.NodeName
    {
        # cluster
        xCluster createCluster
        {
            Name                          = $configurationData.nonNodeData.clusterName
            StaticIPAddress               = $clusterIPandSubNetClass
            DomainAdministratorCredential = $domainAdmin
            DependsOn                     = "[WindowsFeature]RSAT-Clustering-Mgmt", "[SqlSetup]sqlSetup"
        }
        
        # create database
        SqlDatabase foobarDB
        {
            ServerName           = $configurationData.nonNodeData.primaryNode
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            Name                 = $configurationData.nonNodeData.sqlDatabases
            Ensure               = "Present"
            DependsOn            = "[SqlSetup]sqlSetup"
            PsDscRunAsCredential = $domainAdmin
        }

        # mirroring endpoint 
        SqlServerEndpoint hadrEndpoint
        {
            EndPointName         = $configurationData.nonNodeData.sqlHadrEndpointName
            ServerName           = $configurationData.nonNodeData.primaryNode
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            Port                 = $configurationData.nonNodeData.sqlHadrEndpointPort
            Ensure               = "Present"
            DependsOn            = "[SqlSetup]sqlSetup", "[xCluster]createCluster"
            PsDscRunAsCredential = $domainAdmin
        }

        # always on
        SqlAlwaysOnService alwaysOn
        {
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            ServerName           = $configurationData.nonNodeData.primaryNode
            RestartTimeout       = 120
            Ensure               = "Present"
            DependsOn            = "[SqlSetup]sqlSetup", "[xCluster]createCluster"
            PsDscRunAsCredential = $domainAdmin
        }

        # availability group
        SqlAG availabilityGroup
        {
            Name                 = $configurationData.nonNodeData.sqlAGName
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            ServerName           = $configurationData.nonNodeData.primaryNode
            Ensure               = "Present"
            DependsOn            = "[SqlAlwaysOnService]alwaysOn", "[SqlServerEndpoint]hadrEndpoint"
            PsDscRunAsCredential = $domainAdmin
        }

        <# witness
        xClusterQuorum witnessConfiguration
        {
            IsSingleInstance = "No"
            Type             = "NodeAndFileShareMajority"
            Resource         = "\\witness.company.local\witness$"
        }
        #>

        <# availability group listener
        SqlAGListener availabilityGroupListener
        {
            ServerName           = $configurationData.nonNodeData.primaryNode
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            availabilityGroup    = $configurationData.nonNodeData.sqlAGName
            Name                 = $configurationData.nonNodeData.sqlAGName
            IpAddress            = $listenerIPandMask
            Port                 = $configurationData.nonNodeData.sqlPort
            Ensure               = "Present"
            DependsOn            = "[SqlAG]availabilityGroup"
            PsDscRunAsCredential = $domainAdmin
        }
        #>
    }

    # secondary node
    Node $AllNodes.Where{$_.role -contains "sqlAGSecondary"}.NodeName
    {   
        # windows features
        WindowsFeature RSAT-Clustering-CmdInterface
        {
            Name      = "RSAT-Clustering-CmdInterface"
            Ensure    = "Present"
            DependsOn = "[WindowsFeature]RSAT-Clustering-PowerShell"
        }

        # wait for cluster creation
        xWaitForCluster waitForCluster
        {
            Name             = $configurationData.nonNodeData.clusterName
            RetryIntervalSec = 10
            RetryCount       = 100
            DependsOn        = "[WindowsFeature]RSAT-Clustering-CmdInterface"
        }

        # join cluster
        xCluster joinCluster
        {
            Name                          = $configurationData.nonNodeData.clusterName
            StaticIPAddress               = $configurationData.nonNodeData.clusterIPandSubNetClass
            DomainAdministratorCredential = $domainAdmin
            DependsOn                     = "[xWaitForCluster]waitForCluster"
        }

        # always on
        SqlAlwaysOnService alwaysOn
        {
            InstanceName         = $configurationData.nonNodeData.sqlInstanceName
            ServerName           = $configurationData.nonNodeData.secondaryNode
            RestartTimeout       = 120
            Ensure               = "Present"
            DependsOn            = "[xCluster]joinCluster"
            PsDscRunAsCredential = $domainAdmin
        }

        # availability group
        SqlWaitForAG waitForAvailabilityGroup
        {
            Name                 = $configurationData.nonNodeData.sqlAGName
            RetryIntervalSec     = 30
            RetryCount           = 40
            PsDscRunAsCredential = $domainAdmin
        }

        # add availability group replica
        SqlAGReplica addReplica
        {
            Name                       = $configurationData.nonNodeData.secondaryNode
            AvailabilityGroupName      = $configurationData.nonNodeData.sqlAGName
            ServerName                 = $configurationData.nonNodeData.secondaryNode
            InstanceName               = $configurationData.nonNodeData.sqlInstanceName
            PrimaryReplicaServerName   = $configurationData.nonNodeData.primaryNode
            PrimaryReplicaInstanceName = $configurationData.nonNodeData.sqlInstanceName
            ProcessOnlyOnActiveNode    = 1
            Ensure                     = "Present"
            DependsOn                  = "[SqlWaitForAG]waitForAvailabilityGroup"
            PsDscRunAsCredential       = $domainAdmin
        }
    }
}