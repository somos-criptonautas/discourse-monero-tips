import { withPluginApi } from "discourse/lib/plugin-api";
import MoneroTipPostMenuButton from "../components/post-menu/monero-tip-button";

export default {
  name: "monero-tips",

  initialize(container) {
    if (!container.lookup("service:site-settings").monero_tips_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context: { buttonKeys } }) => {
          // First of the extra controls, so it takes the bottom-left corner.
          dag.add("monero-tip", MoneroTipPostMenuButton, {
            before: buttonKeys.REPLIES,
          });
        }
      );
    });
  },
};
