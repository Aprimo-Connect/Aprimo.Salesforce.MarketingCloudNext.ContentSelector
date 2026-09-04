/**
 * Registration helpers for the Aprimo content provider.
 *
 * Provider *instances* are created at runtime through ConnectApi, not deployed as metadata
 * — the DgtAssetMgmtProvider / DgtAssetMgmtPrvdLghtCpnt pair only declares that the
 * provider exists. Nothing appears in the CMS editor until an instance is registered here.
 *
 * Driven from scripts/apex/register-aprimo-provider.apex during the spike; a proper admin
 * UI only makes sense once the bridge is proven viable.
 */
public with sharing class AprimoProviderAdmin {
    public class RegistrationException extends Exception {}

    /**
     * Registers a provider instance for the given provider label.
     *
     * @param providerLabel matches the <label> in the DgtAssetMgmtProvider metadata
     * @param instanceName  human-readable name shown to admins
     * @param instanceKey   opaque per-instance key handed back to the LWC via context
     * @param isDefault     only one instance per org may be the default
     * @return the created providerInstanceId
     */
    public static String register(
        String providerLabel,
        String instanceName,
        String instanceKey,
        Boolean isDefault
    ) {
        String componentId = findProviderLightningComponentId(providerLabel);
        if (String.isBlank(componentId)) {
            throw new RegistrationException(
                'No provider found with label "' + providerLabel + '". Deploy the ' +
                'DgtAssetMgmtProvider and DgtAssetMgmtPrvdLghtCpnt metadata first.'
            );
        }

        ConnectApi.ManagedContentProviderInput input = new ConnectApi.ManagedContentProviderInput();
        input.name = instanceName;
        input.instanceKey = instanceKey;
        input.isDefault = (isDefault == null) ? false : isDefault;
        input.providerLightningComponentId = componentId;

        ConnectApi.ManagedContentProviderInstance created =
            ConnectApi.ManagedContent.createManagedContentProvider(input);
        return created.providerInstanceId;
    }

    /** Every registered instance across all providers, for inspection and cleanup. */
    public static List<String> listInstances() {
        List<String> out = new List<String>();
        ConnectApi.ManagedContentProviderCollection col =
            ConnectApi.ManagedContent.getManagedContentProviders();
        if (col == null || col.providers == null) {
            return out;
        }
        for (ConnectApi.ManagedContentProvider p : col.providers) {
            if (p.providerInstances == null) {
                continue;
            }
            for (ConnectApi.ManagedContentProviderInstance inst : p.providerInstances) {
                out.add(
                    p.label + ' | ' + inst.name + ' | ' + inst.providerInstanceId +
                    ' | default=' + inst.isDefault
                );
            }
        }
        return out;
    }

    /**
     * Deleting an instance fails while content still references it — expected during the
     * spike, since every test selection creates a CMS record.
     */
    public static void deleteInstance(String providerInstanceId) {
        ConnectApi.ManagedContent.deleteManagedContentProviderInstance(providerInstanceId);
    }

    private static String findProviderLightningComponentId(String providerLabel) {
        ConnectApi.ManagedContentProviderCollection col =
            ConnectApi.ManagedContent.getManagedContentProviders();
        if (col == null || col.providers == null) {
            return null;
        }
        for (ConnectApi.ManagedContentProvider p : col.providers) {
            if (providerLabel != null && providerLabel.equals(p.label)) {
                return p.providerLightningComponentId;
            }
        }
        return null;
    }
}
