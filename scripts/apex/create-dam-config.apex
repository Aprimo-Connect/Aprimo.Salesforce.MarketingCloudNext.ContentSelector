// Creates the Aprimo_DAM_Config__mdt record the bridge reads at runtime.
//
// Custom metadata records can't be created with plain DML (`insert`) — Apex rejects that
// at compile time. This uses Metadata.Operations.enqueueDeployment, which queues an
// asynchronous Metadata API deployment, same as a package/source deploy would. It can take
// a few seconds to a minute or two to land; query the record afterward to confirm
// (see the commented SOQL at the bottom), or check Setup > Custom Metadata Types >
// Aprimo DAM Config > Manage Aprimo DAM Configs.
//
// If this deployment fails or never lands (some orgs have flaky custom metadata record
// deploys), create the record by hand instead: Setup > Custom Metadata Types >
// Aprimo DAM Config > Manage Aprimo DAM Configs > New — see the README's
// "Configure your tenant" section for the same field values used below.
//
// EDIT tenantUrl BELOW for your Aprimo tenant, then run with:
//   sf apex run --file scripts/apex/create-dam-config.apex --target-org <org>

String tenantUrl = 'https://YOUR-TENANT.dam.aprimo.com'; // <-- EDIT: your Aprimo tenant URL

Metadata.CustomMetadata config = new Metadata.CustomMetadata();
config.fullName = 'Aprimo_DAM_Config__mdt.Aprimo';
config.label = 'Aprimo';

Metadata.CustomMetadataValue instanceKey = new Metadata.CustomMetadataValue();
instanceKey.field = 'Instance_Key__c';
instanceKey.value = 'aprimo'; // must match register-aprimo-provider.apex
config.values.add(instanceKey);

Metadata.CustomMetadataValue tenantUrlField = new Metadata.CustomMetadataValue();
tenantUrlField.field = 'Tenant_URL__c';
tenantUrlField.value = tenantUrl;
config.values.add(tenantUrlField);

Metadata.CustomMetadataValue searchExpression = new Metadata.CustomMetadataValue();
searchExpression.field = 'Search_Expression__c';
searchExpression.value = 'latestversionofmasterfile.haspublicuri = true';
config.values.add(searchExpression);

Metadata.CustomMetadataValue dialogMode = new Metadata.CustomMetadataValue();
dialogMode.field = 'Dialog_Mode__c';
dialogMode.value = 'fullscreen';
config.values.add(dialogMode);

Metadata.DeployContainer container = new Metadata.DeployContainer();
container.addMetadata(config);

Id jobId = Metadata.Operations.enqueueDeployment(container, null);
System.debug('Enqueued custom metadata deployment, job id: ' + jobId);
System.debug('Check status: Setup > Deployment Status, or re-query in a few seconds:');
System.debug('  SELECT DeveloperName, Tenant_URL__c FROM Aprimo_DAM_Config__mdt');
