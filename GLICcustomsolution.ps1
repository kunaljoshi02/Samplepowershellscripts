# Connect to Azure
Connect-AzAccount
# ---------------------------
# 1. Define App Registration Credentials
# ---------------------------
$TenantId    = "<Your Tenant ID>"
$ClientId    = "<Client ID of App Registration>"
#As a best practice, store client secrets in a secure location such as Azure Key Vault or use Azure Managed Identity. This is only a sample
$ClientSecret= "<Client Secret of App Registration>"

# ---------------------------
# 2. Get OAuth Token
# ---------------------------
$TokenBody = @{
    grant_type    = "client_credentials"
    client_id     = $ClientId
    client_secret = $ClientSecret
    scope         = "https://graph.microsoft.com/.default"
}
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $TokenBody
$AccessToken   = $TokenResponse.access_token

# ---------------------------
# 3. Connect to Azure & Pull Arc Tags
# ---------------------------
#Connect-AzAccount
$ArcMachines = Get-AzResource -ResourceType "Microsoft.HybridCompute/Machines"
#For testing a single machine, uncomment below
#$ArcMachines = Get-AzVM -Name "<Your Machine Name>"
foreach ($machine in $ArcMachines) {
    $deviceName = $machine.name
    $EnvTag  = $machine.Tags["Env"]
    $NameTag = $machine.Tags["Name"]

    # ---------------------------
    # 4. Update Entra Device Extension Attributes
    # ---------------------------
    
# Get the Entra device object by display name
    $SecureClientSecret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
    # Create a PSCredential Object Using the Client ID and Secure Client Secret
    $ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret
    # Connect to Microsoft Graph Using the Tenant ID and Client Secret Credential
    Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $ClientSecretCredential
    $device = Get-MgDevice -ProxyCredential $ClientSecretCredential -Filter "displayName eq '$deviceName'"
    $deviceId = $device.Id
    $GraphUri = "https://graph.microsoft.com/v1.0/devices/$DeviceId"
    $Headers  = @{ 'Authorization' = "Bearer $AccessToken"}
    $Body     = @{
        extensionAttributes = @{
            extensionAttribute1 = $EnvTag
            extensionAttribute2 = $NameTag
        }
    } | ConvertTo-Json -Depth 3
    
    $response = Invoke-RestMethod -Uri $GraphUri -Headers $Headers -Method Patch -Body $Body -ContentType "application/json" 
}
