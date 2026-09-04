// Registers the Aprimo provider instance that makes the bridge appear in the CMS editor.
// Run with:  sf apex run --file scripts/apex/register-aprimo-provider.apex --target-org <org>
//
// Deploy the metadata first — this fails with a clear message if the provider is missing.
//
// instanceKey below is an opaque identifier handed to the LWC via context. Change it only
// if you're registering multiple Aprimo instances (e.g. separate tenants) — each needs a
// unique key, and each needs its own Aprimo_DAM_Config__mdt record with a matching
// Instance_Key__c value (see create-dam-config.apex).

String instanceId = AprimoProviderAdmin.register(
    'Aprimo',        // must match <label> in Aprimo.dgtAssetMgmtProvider-meta.xml
    'Aprimo',         // shown to admins
    'aprimo',         // instanceKey, must match Instance_Key__c on your config record
    true              // default instance
);
System.debug('Registered provider instance: ' + instanceId);

for (String row : AprimoProviderAdmin.listInstances()) {
    System.debug(row);
}
