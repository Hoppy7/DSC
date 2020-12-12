@{
    AllNodes = @(
        @{
            nodeName              = "adoAgent";
            agentUri              = "https://vstsagentpackage.azureedge.net/agent/2.179.0/vsts-agent-win-x64-2.179.0.zip";
            agentPath             = "E:\ado_agent";
            agentBits             = "adoAgent.zip"
            agentCount            = 4
            adoUrl                = "https://dev.azure.com/hoppy7"
            adoAgentPool          = "ASEV3"
            adoAgentAccount       = "NT Authority\System"
            adoAgentName          = "ado_agent"
        }
    )
}