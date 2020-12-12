configuration ado_agent
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration';
    Import-DscResource -ModuleName 'xPSDesiredStateConfiguration';

    $adoPat = Get-AutomationVariable -Name 'adoPat';

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

        xRemoteFile adoAgent 
        {
            DestinationPath = "$($env:TEMP)\$($configurationData.AllNodes.agentBits)"
            Uri             = $configurationData.AllNodes.agentUri
            DependsOn       = "[Script]initializeRawDisks"
        }

        for ($i = 0; $i -lt $configurationData.AllNodes.agentCount; $i++)
        { 
            File $("agentDirectory" + $i)
            {
                DestinationPath = $configurationData.AllNodes.agentPath + $i
                Type            = "Directory"
                Ensure          = "Present"
                DependsOn       = "[xRemoteFile]adoAgent"
            }
    
            xArchive $("adoAgent" + $i)
            {
                Path        = "$($env:TEMP)\$($configurationData.AllNodes.agentBits)"
                Destination = $configurationData.AllNodes.agentPath + $i
                Force       = $true
                Ensure      = "Present"
                DependsOn   = "[File]$("agentDirectory" + $i)"
            }
    
            Script $("installAdoAgent" + $i)
            {
                GetScript = {
                    [bool]$adoAgentService = [bool]$(Get-Service | ? {$_.Name -like "vstsagent*$($using:configurationData.AllNodes.adoAgentName + $using:i)"});
                    return @{"Result" = $adoAgentService};
                }
                SetScript = {
                    & "$($using:configurationData.AllNodes.agentPath + $using:i)\config.cmd" --unattended --url $using:configurationData.AllNodes.adoUrl --auth PAT --token $using:adoPat --pool $using:configurationData.AllNodes.adoAgentPool `
                        --agent $($using:configurationData.AllNodes.adoAgentName + $using:i) --runAsService --windowsLogonAccount $using:configurationData.AllNodes.adoAgentAccount --work $($using:configurationData.AllNodes.agentPath + $using:i);
                }
                TestScript = {
                    $adoAgentService = Get-Service | ? {$_.Name -like "vstsagent*$($using:configurationData.AllNodes.adoAgentName + $using:i)"};
                    if ($adoAgentService)
                    {
                        return $true;
                    }                
                    else
                    {
                        return $false;
                    }
                }
                DependsOn = "[xArchive]$("adoAgent" + $i)"
            }
        }
    }
}