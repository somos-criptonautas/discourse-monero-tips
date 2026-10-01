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

  @tracked address = userAddress(this.args.outletArgs?.model) || "";
  @tracked saving = false;
  @tracked saved = false;

  get isVisible() {
    return this.siteSettings.monero_tips_enabled;
  }

  @action
  updateAddress(event) {
    this.address = event.target.value;
    this.saved = false;
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
    {{/if}}
  </template>
}
