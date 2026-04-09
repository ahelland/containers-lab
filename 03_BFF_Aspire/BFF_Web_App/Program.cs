using BFF_Web_App;
using BFF_Web_App.Client.Weather;
using BFF_Web_App.Components;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.FluentUI.AspNetCore.Components;
using Microsoft.Identity.Abstractions;
using Microsoft.Identity.Web;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using System.IdentityModel.Tokens.Jwt;
using Yarp.ReverseProxy.Transforms;

var builder = WebApplication.CreateBuilder(args);

var tenantId        = builder.Configuration.GetValue<string>("TenantId");
var clientId        = builder.Configuration.GetValue<string>("ClientId");
var uamiId          = builder.Configuration.GetValue<string>("UamiId") ?? string.Empty;
var identitifierUri = builder.Configuration.GetValue<string>("IdentifierUri");
var keyvaultUrl     = builder.Configuration.GetValue<string>("KeyVaultUrl") ?? "noVault";
var keyvaultSecret  = builder.Configuration.GetValue<string>("KeyVaultSecret") ?? "noVault";
var dnsSuffix       = builder.Configuration.GetValue<string>("DnsSuffix") ?? string.Empty;

builder.AddServiceDefaults();

builder.Services.AddAuthentication(OpenIdConnectDefaults.AuthenticationScheme)
    .AddCookie("MicrosoftOidc")
    .AddMicrosoftIdentityWebApp(microsoftIdentityOptions =>
    {
        if (builder.Environment.IsDevelopment())
        { 
            //Certificate is used for auth for local dev
            microsoftIdentityOptions.ClientCredentials = new CredentialDescription[] {
            CertificateDescription.FromKeyVault(keyvaultUrl,keyvaultSecret)};
        }
        else
        {
            //When deployed to Azure use a User Assigned Managed Identity
            CredentialDescription uami = new CredentialDescription();
            uami.ManagedIdentityClientId = uamiId;
            uami.TokenExchangeUrl = "api://AzureADTokenExchange";
            uami.SourceType = CredentialSource.SignedAssertionFromManagedIdentity;
            microsoftIdentityOptions.ClientCredentials = new CredentialDescription[] { uami };
        }

        microsoftIdentityOptions.ClientId = clientId;

        microsoftIdentityOptions.SignInScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        microsoftIdentityOptions.CallbackPath = new PathString("/signin-oidc");
        microsoftIdentityOptions.SignedOutCallbackPath = new PathString("/signout-callback-oidc");
        microsoftIdentityOptions.RemoteSignOutPath = new PathString("/signout-oidc");
        microsoftIdentityOptions.Scope.Add($"{identitifierUri}/Weather.Get");
        microsoftIdentityOptions.Authority = $"https://login.microsoftonline.com/{tenantId}/v2.0/";

        microsoftIdentityOptions.ResponseType = OpenIdConnectResponseType.Code;
        microsoftIdentityOptions.MapInboundClaims = false;
        microsoftIdentityOptions.TokenValidationParameters.NameClaimType = JwtRegisteredClaimNames.Name;
        microsoftIdentityOptions.TokenValidationParameters.RoleClaimType = "role";
        microsoftIdentityOptions.SaveTokens = true;
    })
    .EnableTokenAcquisitionToCallDownstreamApi(confidentialClientApplicationOptions =>
    {
        confidentialClientApplicationOptions.Instance = "https://login.microsoftonline.com/";
        confidentialClientApplicationOptions.TenantId = tenantId;
        confidentialClientApplicationOptions.ClientId = clientId;
    })
  .AddInMemoryTokenCaches();

builder.Services.ConfigureCookieOidcRefresh("Cookies", "MicrosoftOidc");

builder.Services.AddAuthorization();

builder.Services.AddCascadingAuthenticationState();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents()
    .AddInteractiveWebAssemblyComponents()
    .AddAuthenticationStateSerialization();

builder.Services.AddFluentUIComponents();

builder.Services.AddHttpForwarderWithServiceDiscovery();
builder.Services.AddHttpContextAccessor();

var weatherApiUrl = "https://weatherapi";

if (dnsSuffix != string.Empty)
{
    weatherApiUrl = $"https://weatherapi.internal.{dnsSuffix}";
}

builder.Services.AddHttpClient<IWeatherForecaster, ServerWeatherForecaster>(httpClient =>
{
    httpClient.BaseAddress = new Uri(weatherApiUrl);
});

var app = builder.Build();

app.MapDefaultEndpoints();

if (app.Environment.IsDevelopment())
{
    app.UseWebAssemblyDebugging();
}
else
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();

    //To make https work
    app.UseForwardedHeaders(new ForwardedHeadersOptions
    {
        ForwardedHeaders = ForwardedHeaders.XForwardedProto | ForwardedHeaders.XForwardedHost
    });
}

app.UseHttpsRedirection();

app.UseStaticFiles();
app.UseAntiforgery();

app.MapStaticAssets();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode()
    .AddInteractiveWebAssemblyRenderMode()
    .AddAdditionalAssemblies(typeof(BFF_Web_App.Client._Imports).Assembly);

app.MapForwarder("/weather-forecast", "https://weatherapi", transformBuilder =>
{
    transformBuilder.AddRequestTransform(async transformContext =>
    {
        var accessToken = await transformContext.HttpContext.GetTokenAsync("access_token");
        transformContext.ProxyRequest.Headers.Authorization = new("Bearer", accessToken);
    });
}).RequireAuthorization();

app.MapGroup("/authentication").MapLoginAndLogout();

app.Run();
