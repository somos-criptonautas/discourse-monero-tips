import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Monero tips | opting in to verified tips", function (needs) {
  needs.user();
  needs.settings({
    monero_tips_enabled: true,
    monero_tips_verified_enabled: true,
    monero_tips_icon: "coins",
  });

  test("the warning is shown before the key can be pasted", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");

    assert.dom(".monero-verified-preference__caveat").exists();
    assert.dom(".monero-verified-preference__key").exists();
    assert
      .dom(
        ".monero-verified-preference__caveat ~ .monero-verified-preference__key"
      )
      .exists("the caveat comes first in the DOM, not after the field");
  });
});

acceptance("Monero tips | with verification off", function (needs) {
  needs.user();
  needs.settings({
    monero_tips_enabled: true,
    monero_tips_verified_enabled: false,
    monero_tips_icon: "coins",
  });

  test("no view key is asked for", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");

    assert.dom(".monero-address-preference__input").exists();
    assert.dom(".monero-verified-preference").doesNotExist();
  });
});
