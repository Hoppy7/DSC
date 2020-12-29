configuration rohopkin_dsc
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration';
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration';
    Import-DscResource -ModuleName 'cChoco';

    Node $AllNodes.nodeName
    {
        Script initializeRawDisks 
        {
            GetScript = {
                [bool]$rawDisks = [bool]$(Get-Disk | ? {$_.PartitionStyle -eq 'RAW'});
                return @{"Result" = $rawDisks};
            }
            SetScript = {
                $rawDisks = Get-Disk | ? {$_.PartitionStyle -eq 'RAW'};

                foreach ($disk in $rawDisks)
                {
                    # TODO: identify and assign datadisk name from ARM
                    $disk | Initialize-Disk -PartitionStyle MBR -PassThru | 
                        New-Partition -AssignDriveLetter -UseMaximumSize | 
                        Format-Volume -FileSystem NTFS -NewFileSystemLabel "dataDisk" -Force;
                }
            }
            TestScript = {
                $rawDisks = Get-Disk | ? {$_.PartitionStyle -eq 'RAW'};
                if ($rawDisks)
                {
                    return $false;
                }                
                else
                {
                    return $true;
                }
            }
        }

        cChocoInstaller installChocolatey
        {
            InstallDir = "C:\ProgramData\Chocolatey"
        }

        cChocoPackageInstaller azCli
        {
            Name        = "azure-cli"
            AutoUpgrade = $true
            Ensure      = "Present"
            DependsOn   = "[cChocoInstaller]installChocolatey"
        }

        cChocoPackageInstaller powershellCore
        {
            Name        = "powershell-core"
            AutoUpgrade = $true
            Ensure      = "Present"
            DependsOn   = "[cChocoInstaller]installChocolatey"
        }

        cChocoPackageInstaller azPowerShell
        {
            Name        = "az.powershell"
            AutoUpgrade = $true
            Ensure      = "Present"
            DependsOn   = "[cChocoInstaller]installChocolatey"
        }
    }
}