/**
 * Persists bridge diagnostics so they survive the CMS editor unmounting the picker.
 *
 * The modal closes the instant assetselected fires, so anything held only in component state
 * is gone before it can be read. Everything interesting gets written here instead, then
 * queried from the CLI.
 */
public with sharing class AprimoBridgeLog {
    /** Long text area cap. */
    private static final Integer MAX_PAYLOAD = 131072;

    @AuraEnabled
    public static String log(String mode, String outcome, String payload) {
        Bridge_Finding__c f = new Bridge_Finding__c(
            Mode__c = truncate(mode, 50),
            Outcome__c = truncate(outcome, 255),
            Payload__c = truncate(payload, MAX_PAYLOAD)
        );
        insert f;
        return f.Id;
    }

    private static String truncate(String s, Integer max) {
        if (String.isBlank(s)) {
            return null;
        }
        return s.length() > max ? s.left(max) : s;
    }
}
