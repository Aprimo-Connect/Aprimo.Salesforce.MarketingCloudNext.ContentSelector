/**
 * Resolves per-instance Aprimo selector config from Custom Metadata, keyed by instanceKey.
 *
 * Cacheable so the LWC can @wire it: the picker reads this the moment its context arrives,
 * which is what lets it launch the Aprimo selector without a config form.
 */
public with sharing class AprimoDamConfigController {
    public class Config {
        @AuraEnabled public Boolean found = false;
        @AuraEnabled public String instanceKey;
        @AuraEnabled public String tenantUrl;
        @AuraEnabled public String searchExpression;
        @AuraEnabled public List<String> facets = new List<String>();
        @AuraEnabled public String dialogMode;
    }

    private static final String DEFAULT_EXPRESSION = 'latestversionofmasterfile.haspublicuri = true';
    private static final String DEFAULT_DIALOG_MODE = 'fullscreen';

    @AuraEnabled(cacheable=true)
    public static Config getConfig(String instanceKey) {
        Config c = new Config();
        c.instanceKey = instanceKey;
        if (String.isBlank(instanceKey)) {
            return c;
        }

        List<Aprimo_DAM_Config__mdt> rows = [
            SELECT Tenant_URL__c, Search_Expression__c, Facets__c, Dialog_Mode__c
            FROM Aprimo_DAM_Config__mdt
            WHERE Instance_Key__c = :instanceKey
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return c;
        }

        Aprimo_DAM_Config__mdt r = rows[0];
        c.found = true;
        c.tenantUrl = r.Tenant_URL__c;
        c.searchExpression = String.isBlank(r.Search_Expression__c)
            ? DEFAULT_EXPRESSION
            : r.Search_Expression__c;
        c.dialogMode = String.isBlank(r.Dialog_Mode__c) ? DEFAULT_DIALOG_MODE : r.Dialog_Mode__c;
        if (String.isNotBlank(r.Facets__c)) {
            for (String f : r.Facets__c.split(',')) {
                if (String.isNotBlank(f)) {
                    c.facets.add(f.trim());
                }
            }
        }
        return c;
    }
}
