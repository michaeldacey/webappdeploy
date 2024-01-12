using './webapp_deploy.bicep'

param acrName = 'myacr'
param imageName = 'nginx'
param appName = 'mywebapp'

// We will need to overwrite the value in the workflow
param applicationServicePrincipalId = '<spId>'
