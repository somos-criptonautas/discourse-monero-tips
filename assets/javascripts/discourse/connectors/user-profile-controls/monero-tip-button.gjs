import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import MoneroTipModal from "../../components/modal/monero-tip";
import { userAddress } from "../../lib/monero-tips";

export default class MoneroTipButton extends Component {
  @service siteSettings;
  @service modal;

  get user() {
    return this.args.outletArgs?.model;
  }

  get isVisible() {
    return this.siteSettings.monero_tips_enabled && !!userAddress(this.user);
  }

  @action
  openTip() {
    this.modal.show(MoneroTipModal, {
      model: { username: this.user.username },
    });
  }

  <template>
    {{#if this.isVisible}}
      <li class="monero-tip-profile">
        <button
          type="button"
          class="btn btn-default monero-tip-trigger"
          {{on "click" this.openTip}}
        >
          {{icon this.siteSettings.monero_tips_icon}}
          <span>{{i18n "monero_tips.tip"}}</span>
        </button>
      </li>
    {{/if}}
  </template>
}
