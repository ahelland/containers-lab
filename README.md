# Containers Lab

This repo is intended for learning and playing around with containers in Azure.

```
- The code focuses on working with containers, and to make that easier we skip things like locking down communication to an internal network. Which you should do in production.
- The code here is aimed at being run on your computer, not through CI/CD pipelines. 
And we know that friends don't let friends right-click & publish so not entirely a good outer loop.
- Non-essential resource names and parameters are hard-coded in the Bicep files.
```

## Prerequisites
- An Azure subscription (with Owner access).
- Application Administrator or Global Admin in the Entra tenant the subscription is connected to.
- .NET 10 SDK (https://get.dot.net)
- Aspire CLI (https://get.aspire.dev)
- Azure CLI

## Repo structure  
- 01_ACR: Bicep for deploying an Azure Container Registry.
- 02_HelloTime: A simple .NET 10 app that shows the current time.
- 03_BFF_Aspire: A .NET 10 Backend-for-Frontend (BFF) Blazor sample app.
- 04_ACA: Bicep for deploying an Azure Container Apps Environment and subsequent deployment of the containers making up the BFF.
- 04_AKS_Auto: Bicep for deploying an AKS Automatic cluster.

## Deploying and running code
Start with logging in to Azure:  
`az login`

Check you are using the right subscription:  
`az account show`

Each folder contains one or more files to deploy the artifacts.

_01_ACR_  
Run the following:  
`deploy_acr.azcli`

_02_HelloTime_.  
Build and push the app to ACR:  
`push_image.azcli`

_03_ACA_  
To run app locally:
```
# Inserts values into appsettings.json
update_appsettings.sh

# Build and run locally
aspire run
```
Build and push the app to ACR:  
`push_containers.azcli`

_04_ACA_  
```
# Inserts name of ACR into bicepparam file.
update_acr_name.sh

# Deploy Container Environment and containers 
deploy_cae.azcli 
```

_05_AKS_Auto_  
Deploy AKS cluster and the HelloTime app:  
`deploy_aks.azcli`

## Authentication / Authorization 
There's some Entra sauce behind the scenes with the BFF web app you might want to take note of. (That is actually leaning towards best practice.)  

When you run the app locally with Aspire a Key Vault is provisioned to Azure, a certificate is generated, and an app registration is created in Entra with the public key of the certificate added. This means the sign in feature is configured in your app all without exchanging a client secret.

When you deploy to Azure and run in Container Apps an app registration is also created. But this one creates a federated identity credential linking to a User-Assigned Managed Identity attached to the app. That means you can go passwordless on the server side, and there's no client secret involved nor is there a cert to rotate and secure either.