import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { postAddress } from "../../lib/monero-tips";
import MoneroTipModal from "../modal/monero-tip";

// Rendered with the post menu's extra controls, which sit at the bottom-left
// of the post, apart from the action buttons on the right.
export default class MoneroTipPostMenuButton extends Component {
  static extraControls = true;

  static shouldRender(args, helper) {
    return helper.siteSettings.monero_tips_enabled && !!postAddress(args.post);
  }

  @service siteSettings;
  @service modal;

  get username() {
    return this.args.post.username;
  }

  @action
  openTip() {
    this.modal.show(MoneroTipModal, { model: { username: this.username } });
  }

  <template>
    <button
      type="button"
      class="btn no-text btn-icon btn-flat post-action-menu__monero-tip monero-tip-trigger"
      title={{i18n "monero_tips.tip_user" username=this.username}}
      aria-label={{i18n "monero_tips.tip_user" username=this.username}}
      {{on "click" this.openTip}}
    >
      {{icon this.siteSettings.monero_tips_icon}}
    </button>
  </template>
}
