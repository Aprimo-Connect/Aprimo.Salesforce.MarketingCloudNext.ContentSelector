/**
 * aprimoSelectorBridge
 *
 * Salesforce CMS external content provider for Aprimo DAM. Rendered inside the CMS content
 * editor when a user picks "Aprimo" as the external content source.
 *
 * Flow: resolve per-instance config (tenant, search expression) from Custom Metadata keyed
 * by the instanceKey in the CMS context, present an "Open Aprimo" button, launch the hosted
 * Aprimo Content Selector in a new tab, receive the chosen asset over postMessage, and fire
 * the CMS `assetselected` event with the asset's public-link URL.
 */
import { LightningElement, api } from 'lwc';
import getConfig from '@salesforce/apex/AprimoDamConfigController.getConfig';

// publicuri is only returned by the selector in singlerendition mode, and only for records
// with an active Public Link — which is why the search expression must filter on haspublicuri.
const SELECT_MODE = 'singlerendition';
const DEFAULT_EXPRESSION = 'latestversionofmasterfile.haspublicuri = true';

/** btoa() throws on code points above U+00FF; selector options may contain such characters. */
function base64Utf8(str) {
    const bytes = new TextEncoder().encode(str);
    let binary = '';
    bytes.forEach((b) => {
        binary += String.fromCharCode(b);
    });
    return btoa(binary);
}

export default class AprimoSelectorBridge extends LightningElement {
    _context = {};

    @api
    get context() {
        return this._context;
    }
    set context(val) {
        this._context = val || {};
        this.resolveConfig();
    }

    tenantUrl = '';
    searchExpression = DEFAULT_EXPRESSION;
    facets = [];
    dialogMode = 'fullscreen';
    configResolved = false;
    configError = '';
    resolvedKey = null;
    hostOrigin = null;
    boundHandler = null;

    connectedCallback() {
        try {
            this.hostOrigin = window.location.origin;
        } catch (e) {
            this.hostOrigin = null;
        }
        this.boundHandler = this.handleMessage.bind(this);
        window.addEventListener('message', this.boundHandler, false);
    }

    disconnectedCallback() {
        if (this.boundHandler) {
            window.removeEventListener('message', this.boundHandler, false);
        }
    }

    resolveConfig() {
        const key = this._context && this._context.instanceKey;
        if (!key || key === this.resolvedKey) {
            return;
        }
        this.resolvedKey = key;

        getConfig({ instanceKey: key })
            .then((cfg) => {
                this.configResolved = true;
                if (cfg && cfg.found && cfg.tenantUrl) {
                    this.tenantUrl = cfg.tenantUrl;
                    this.searchExpression = cfg.searchExpression || DEFAULT_EXPRESSION;
                    this.facets = cfg.facets || [];
                    this.dialogMode = cfg.dialogMode || 'fullscreen';
                } else {
                    this.configError =
                        'No Aprimo configuration found for this content source. Ask your ' +
                        'administrator to create an Aprimo DAM Config record for instance key "' +
                        key +
                        '".';
                }
            })
            .catch((e) => {
                this.configResolved = true;
                this.configError =
                    'Could not load Aprimo configuration: ' +
                    (e && e.body ? e.body.message : e);
            });
    }

    get isLoading() {
        return !this.configResolved;
    }

    get hasError() {
        return this.configResolved && !!this.configError;
    }

    get ready() {
        return this.configResolved && !this.configError && !!this.tenantUrl;
    }

    /**
     * Opens the hosted Aprimo selector. Runs synchronously in the click handler: any await
     * before window.open() spends the user-gesture token and the browser blocks the popup.
     */
    handleOpen() {
        const tenant = (this.tenantUrl || '').trim().replace(/\/+$/, '');
        if (!tenant) {
            return;
        }
        const options = {
            title: 'Select content from Aprimo',
            accept: 'Select',
            limitingSearchExpression: this.searchExpression,
            select: SELECT_MODE,
            dialogMode: this.dialogMode,
            facets: this.facets,
            targetOrigin: this.hostOrigin
        };
        const url = tenant + '/dam/selectcontent#options=' + base64Utf8(JSON.stringify(options));
        window.open(url, 'aprimoSelector');
    }

    handleMessage(event) {
        const data = event.data;
        if (!data || typeof data !== 'object' || !('result' in data)) {
            return;
        }

        // Only accept messages from the configured Aprimo tenant.
        try {
            if (!this.tenantUrl || event.origin !== new URL(this.tenantUrl).origin) {
                return;
            }
        } catch (e) {
            return;
        }

        if (data.result !== 'accept') {
            return;
        }

        const selection = Array.isArray(data.selection) ? data.selection[0] : null;
        const rendition = selection && selection.rendition;
        if (!selection || !rendition || !rendition.publicuri) {
            return;
        }

        // Composite externalId: CMS dedupes on it, so record id alone would collapse distinct
        // renditions of the same asset into one (uneditable) content item.
        const externalId = (selection.id + ':' + rendition.id).slice(0, 255);
        this.dispatchEvent(
            new CustomEvent('assetselected', {
                detail: {
                    url: rendition.publicuri,
                    contentInfo: {
                        title: (selection.title || 'Untitled').slice(0, 255),
                        altText: (selection.title || '').slice(0, 255),
                        externalId,
                        urlName: this.slugify(selection.title)
                    }
                }
            })
        );
    }

    slugify(title) {
        return (title || 'asset')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/^-+|-+$/g, '')
            .slice(0, 255);
    }
}
