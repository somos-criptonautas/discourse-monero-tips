import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import MoneroTipModal from "../../components/modal/monero-tip";
import { postAddress } from "../../lib/monero-tips";

// Next to the poster's name: present enough to find, quiet enough to ignore.
export default class MoneroTipIcon extends Component {
  @service siteSettings;
  @service modal;

  get username() {
    return this.args.outletArgs?.user?.username;
  }

  get isVisible() {
    return (
      this.siteSettings.monero_tips_enabled &&
      !!postAddress(this.args.outletArgs?.post)
    );
  }

  @action
  openTip(event) {
    event.preventDefault();
    event.stopPropagation();
    this.modal.show(MoneroTipModal, { model: { username: this.username } });
  }

  <template>
    {{#if this.isVisible}}
      <button
        type="button"
        class="btn-flat monero-tip-trigger"
        title={{i18n "monero_tips.tip_user" username=this.username}}
        {{on "click" this.openTip}}
      >
        {{icon this.siteSettings.monero_tips_icon}}
      </button>
    {{/if}}
  </template>
}
