# Aprimo Content Selector for Salesforce CMS

A Salesforce CMS external content provider that lets content authors pick assets from
Aprimo DAM directly inside the CMS content editor (Enhanced CMS Workspaces), including
Marketing Cloud Next's Content workspaces.

**How it works:** the bridge opens Aprimo's hosted Content Selector (`/dam/selectcontent`)
in a popup, receives the chosen asset over `postMessage`, and hands the asset's public-link
URL back to Salesforce CMS as external content. No Aprimo REST API integration is
involved — Aprimo's own hosted picker UI does the searching and selecting.

## What's included

| Path | Purpose |
|---|---|
| `force-app/main/default/lwc/aprimoSelectorBridge` | The LWC that renders in the CMS editor and drives the picker |
| `force-app/main/default/classes/AprimoProviderAdmin.cls` | Registers/lists/deletes the provider instance via `ConnectApi.ManagedContent` |
| `force-app/main/default/classes/AprimoDamConfigController.cls` | Resolves per-instance config (tenant URL, search expression, facets) for the LWC |
| `force-app/main/default/classes/AprimoBridgeLog.cls` | Writes `Bridge_Finding__c` records — lightweight diagnostic logging |
| `force-app/main/default/objects/Aprimo_DAM_Config__mdt` | Custom metadata type holding your tenant config |
| `force-app/main/default/objects/Bridge_Finding__c` | Custom object used by `AprimoBridgeLog` |
| `force-app/main/default/dgtAssetMgmtProviders`, `dgtAssetMgmtPrvdLghtCpnts` | Declares the provider + which LWC renders it |
| `force-app/main/default/cspTrustedSites/aprimo_dam.cspTrustedSite-meta.xml` | Allowlists `*.dam.aprimo.com` (your tenant domain) |
| `force-app/main/default/permissionsets/Aprimo_DAM_Connector.permissionset-meta.xml` | Apex class access + FLS for `Bridge_Finding__c` |
| `scripts/apex/register-aprimo-provider.apex` | Registers the provider instance (run once) |
| `scripts/apex/create-dam-config.apex` | Creates your tenant's config record |

## Prerequisites

- Salesforce CLI (`sf`)
- **Enhanced CMS Workspaces** enabled in your org (Setup > Digital Experiences, or already
  present if you have Marketing Cloud Next / Marketing Cloud Growth's Content workspaces)
- An Aprimo DAM tenant URL you can reach (e.g. `https://yourtenant.dam.aprimo.com`)

This connector does **not** require Data Cloud or Marketing Cloud Next specifically — it
plugs into Salesforce CMS's external content provider framework, which those products also
use for their Content workspaces. Confirmed: the metadata deploy, permission set
assignment, config record creation, and provider registration below all complete cleanly
on a plain Developer Edition scratch org with no Data Cloud/MC Next features enabled. What
we couldn't independently confirm is whether Enhanced CMS Workspaces itself ships enabled
by default in every edition — if **Content** doesn't appear as a tab/app for you, enable it
under Setup > Digital Experiences first.

## Install

### 1. Deploy the metadata

```bash
sf project deploy start --source-dir force-app --target-org <your-org>
```

### 2. Assign the permission set

```bash
sf org assign permset --name Aprimo_DAM_Connector --target-org <your-org>
```

Assign it to every user who will author CMS content with Aprimo, and to whoever runs the
registration script below.

### 3. Allowlist your Aprimo asset delivery domain (CSP)

`aprimo_dam.cspTrustedSite-meta.xml` allowlists your tenant domain
(`*.dam.aprimo.com`) for the picker UI itself, but the actual **image files** selected
assets resolve to are served from a separate delivery/CDN domain that is specific to your
Aprimo pod (for example `p1.aprimocdn.net`, or a sandbox-labeled variant like
`p1.sb.aprimocdn.net`). This can't be generalized with a wildcard — Salesforce's
`CspTrustedSite` wildcard only matches one subdomain label, so `*.aprimocdn.net` will not
cover a two-label host like `p1.sb.aprimocdn.net`.

To find your exact host:
1. Complete steps 4–6 below so the picker is working end to end.
2. Select an asset in Aprimo and watch the browser console for a CSP violation — it'll
   name the blocked host.
3. In Setup, create a new **CSP Trusted Site** allowlisting that exact host for Image Src
   and Media Src.

### 4. Create your tenant's config record

Edit `scripts/apex/create-dam-config.apex` with your Aprimo tenant URL, then run:

```bash
sf apex run --file scripts/apex/create-dam-config.apex --target-org <your-org>
```

If your org rejects DML on custom metadata (some orgs require Metadata API deployment
instead), create the record by hand: **Setup > Custom Metadata Types > Aprimo DAM Config >
Manage Aprimo DAM Configs > New**, using the same field values from the script.

### 5. Register the provider instance

```bash
sf apex run --file scripts/apex/register-aprimo-provider.apex --target-org <your-org>
```

This makes "Aprimo" appear as an available provider — but it's not yet enabled for any
specific CMS workspace.

### 6. Enable the provider for each CMS workspace

Provider registration is org-wide, but each CMS workspace must separately opt in:

1. Open the workspace under the **Content** tab.
2. Click the gear icon > **External Assets**.
3. Move **Aprimo** from *Available Providers* to *Selected Workspace Providers*.
4. Save.

Repeat for every workspace where authors should see Aprimo as a source.

### 7. Try it

In that workspace: **Add > Content > Image > Add External Asset > Aprimo > Open Aprimo**.

## Multiple Aprimo instances / tenants

`register-aprimo-provider.apex` and `create-dam-config.apex` both use the instance key
`aprimo`. If you need to connect more than one Aprimo tenant, register additional
instances with unique keys and matching config records — see the comments in
`register-aprimo-provider.apex`.

## License

_Add your organization's license of choice before publishing._
