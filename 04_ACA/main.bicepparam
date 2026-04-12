using 'main.bicep'

param resourceTags = {            
  IaC: 'Bicep'
  Source: 'GitHub'
}

param AppName = 'bff-dotnet10-aca'
param location = 'norwayeast'

param acrName = ''
