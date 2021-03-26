@{
    AllNodes = @(
        @{
            nodeName              = "pipelineAgent"
            agentCount            = 4
            agentUri              = "https://vstsagentpackage.azureedge.net/agent/2.179.0/vsts-agent-win-x64-2.179.0.zip"
            agentPath             = "F:\ado_agent"
            agentBits             = "adoAgent.zip"
            adoUrl                = "https://dev.azure.com/hoppy7"
            adoAgentPool          = "azDeploy"
            adoAgentAccount       = "NT Authority\System"
            adoAgentName          = "ado_agent"
        }
    )
}