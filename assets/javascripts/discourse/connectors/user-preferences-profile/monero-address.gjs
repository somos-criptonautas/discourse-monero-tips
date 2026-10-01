import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { userAddress } from "../../lib/monero-tips";

// Saved through the plugin's own endpoint rather than the preferences form, so
// the address is validated before it is stored and nothing else can write it.
export default class MoneroAddressPreference extends Component {
  @service siteSettings;
  @service currentUser;

  @tracked address = userAddress(this.args.outletArgs?.model) || "";
  @tracked viewKey = "";
  @tracked saving = false;
  @tracked saved = false;
  @tracked status = this.currentUser?.monero_wallet_status?.status || null;
  @tracked statusError = this.currentUser?.monero_wallet_status?.error || null;

  get isVisible() {
    return this.siteSettings.monero_tips_enabled;
  }

  get verifiedAvailable() {
    return this.siteSettings.monero_tips_verified_enabled;
  }

  get enrolled() {
    return !!this.status;
  }

  get statusMessage() {
    if (this.status === "error") {
      return i18n("monero_tips.verified.status_error", {
        error: this.statusError,
      });
    }

    return this.status === "ready"
      ? i18n("monero_tips.verified.status_ready")
      : i18n("monero_tips.verified.status_pending");
  }

  @action
  updateAddress(event) {
    this.address = event.target.value;
    this.saved = false;
  }

  @action
  updateViewKey(event) {
    this.viewKey = event.target.value;
  }

  @action
  async save() {
    this.saving = true;

    try {
      await ajax("/monero-tips/address", {
        type: "PUT",
        data: { address: this.address },
      });
      this.saved = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @action
  async enroll() {
    this.saving = true;

    try {
      const result = await ajax("/monero-tips/view-key", {
        type: "PUT",
        data: { view_key: this.viewKey },
      });
      this.status = result.status;
      this.statusError = null;
      // Not kept in the page any longer than the request needs it.
      this.viewKey = "";
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  @action
  async withdraw() {
    this.saving = true;

    try {
      await ajax("/monero-tips/view-key", { type: "DELETE" });
      this.status = null;
      this.statusError = null;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    {{#if this.isVisible}}
      <div class="control-group monero-address-preference">
        <label class="control-label" for="monero-address">
          {{i18n "monero_tips.preference.label"}}
        </label>

        <div class="controls">
          <input
            id="monero-address"
            class="monero-address-preference__input"
            type="text"
            spellcheck="false"
            autocomplete="off"
            value={{this.address}}
            {{on "input" this.updateAddress}}
          />

          <button
            type="button"
            class="btn btn-default monero-address-preference__save"
            disabled={{this.saving}}
            {{on "click" this.save}}
          >
            {{if
              this.saved
              (i18n "monero_tips.preference.saved")
              (i18n "monero_tips.preference.save")
            }}
          </button>

          <p class="monero-address-preference__hint">
            {{i18n "monero_tips.preference.hint"}}
          </p>
        </div>
      </div>

      {{#if this.verifiedAvailable}}
        <div class="control-group monero-verified-preference">
          <label class="control-label" for="monero-view-key">
            {{i18n "monero_tips.verified.title"}}
          </label>

          <div class="controls">
            {{#if this.enrolled}}
              <p class="monero-verified-preference__status">
                {{this.statusMessage}}
              </p>

              <button
                type="button"
                class="btn btn-danger monero-verified-preference__withdraw"
                disabled={{this.saving}}
                {{on "click" this.withdraw}}
              >
                {{i18n "monero_tips.verified.withdraw"}}
              </button>
            {{else}}
              {{! Said before the field, not after it }}
              <p class="monero-verified-preference__caveat alert alert-warning">
                {{i18n "monero_tips.verified.caveat"}}
              </p>

              <input
                id="monero-view-key"
                class="monero-verified-preference__key"
                type="text"
                spellcheck="false"
                autocomplete="off"
                value={{this.viewKey}}
                placeholder={{i18n "monero_tips.verified.view_key"}}
                {{on "input" this.updateViewKey}}
              />

              <button
                type="button"
                class="btn btn-default monero-verified-preference__enroll"
                disabled={{this.saving}}
                {{on "click" this.enroll}}
              >
                {{i18n "monero_tips.verified.enroll"}}
              </button>
            {{/if}}
          </div>
        </div>
      {{/if}}
    {{/if}}
  </template>
}
