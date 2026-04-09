using Aspire.Hosting.Azure;

var builder = DistributedApplication.CreateBuilder(args);

var tenantId    = builder.AddParameter("TenantId");
var appName     = builder.AddParameter("AppName");

var keyVault = builder.AddAzureKeyVault("keyvault")
    .WithParameter("name", appName);

var appRegistration = builder.AddBicepTemplate(
    name: "App",
    bicepFile: "../infra/App/app-registration.bicep"
)
    .WithParameter("subjectName", "CN=bff.contoso.com")
    .WithParameter("appName", appName)
    .WithParameter("keyVaultName", keyVault.GetOutput("name"))
    .WithParameter("caeDomainName", "placeholder");

var clientId       = appRegistration.GetOutput("clientId");
var uamiId         = appRegistration.GetOutput("uamiId");
var keyVaultUrl    = appRegistration.GetOutput("keyVaultUrl");
var keyVaultSecret = appRegistration.GetOutput("keyVaultSecret");
var identifierUri  = appRegistration.GetOutput("identifierUri");

var weatherapi = builder.AddProject<Projects.WeatherAPI>("weatherapi")
    .WaitFor(appRegistration)
    .WithEnvironment("TenantId", tenantId)
    .WithEnvironment("ClientId", clientId)
    .PublishAsAzureContainerApp((module, app ) => {});

builder.AddProject<Projects.BFF_Web_App>("bff-web-app")
    .WaitFor(appRegistration)
    .WithReference(weatherapi)
    .WithEnvironment("TenantId", tenantId)
    .WithEnvironment("ClientId", clientId)
    .WithEnvironment("UamiId", uamiId)
    .WithEnvironment("IdentifierUri", identifierUri)
    .WithEnvironment("KeyVaultUrl", keyVaultUrl)
    .WithEnvironment("KeyVaultSecret", keyVaultSecret)
    .WithExternalHttpEndpoints()
    .PublishAsAzureContainerApp((module, app) => { });

builder.Build().Run();
