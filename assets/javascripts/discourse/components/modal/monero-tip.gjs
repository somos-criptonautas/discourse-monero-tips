import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class MoneroTipModal extends Component {
  @tracked address = null;
  @tracked uri = null;
  @tracked qr = null;
  @tracked attributed = false;
  @tracked error = null;
  @tracked copied = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  get username() {
    return this.args.model.username;
  }

  // The address is already on the page; the QR is not, so it is fetched rather
  // than drawn in the browser.
  async load() {
    try {
      const result = await ajax(`/monero-tips/${this.username}.json`);
      this.address = result.address;
      this.uri = result.uri;
      this.qr = result.qr;
      this.attributed = result.attributed;
    } catch (e) {
      this.error = extractError(e);
    }
  }

  @action
  async copy() {
    await clipboardCopy(this.address);
    this.copied = true;
  }

  <template>
    <DModal
      @title={{i18n "monero_tips.modal_title" username=this.username}}
      @closeModal={{@closeModal}}
      class="monero-tip-modal"
    >
      <:body>
        <p class="monero-tip-modal__intro">
          {{i18n "monero_tips.intro" username=this.username}}
        </p>

        <p class="monero-tip-modal__attribution">
          {{#if this.attributed}}
            {{i18n "monero_tips.attributed"}}
          {{else}}
            {{i18n "monero_tips.unattributed"}}
          {{/if}}
        </p>

        {{#if this.error}}
          <div class="alert alert-error">{{this.error}}</div>
        {{else if this.address}}
          {{#if this.qr}}
            <img
              class="monero-tip-modal__qr"
              src={{this.qr}}
              alt={{i18n "monero_tips.scan"}}
              width="240"
              height="240"
            />
          {{/if}}

          <label class="monero-tip-modal__label" for="monero-tip-address">
            {{i18n "monero_tips.address"}}
          </label>
          <input
            id="monero-tip-address"
            class="monero-tip-modal__address"
            type="text"
            value={{this.address}}
            readonly
          />
        {{/if}}
      </:body>

      <:footer>
        {{#if this.address}}
          <button
            type="button"
            class="btn btn-primary"
            {{on "click" this.copy}}
          >
            {{if
              this.copied
              (i18n "monero_tips.copied")
              (i18n "monero_tips.copy")
            }}
          </button>

          <a href={{this.uri}} class="btn btn-default">
            {{i18n "monero_tips.open_wallet"}}
          </a>
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
