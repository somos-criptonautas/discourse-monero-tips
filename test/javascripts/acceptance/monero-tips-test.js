import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const ADDRESS = `4${"8".repeat(94)}`;

function profileWith(address) {
  const payload = cloneJSON(userFixtures["/u/charlie.json"]);
  payload.user.custom_fields = address ? { monero_address: address } : {};
  return payload;
}

acceptance("Monero tips | a member with an address", function (needs) {
  needs.user();
  needs.settings({ monero_tips_enabled: true, monero_tips_icon: "coins" });

  needs.pretender((server, helper) => {
    server.get("/u/charlie.json", () => helper.response(profileWith(ADDRESS)));
    server.get("/monero-tips/charlie.json", () =>
      helper.response({
        address: ADDRESS,
        uri: `monero:${ADDRESS}`,
        qr: "data:image/png;base64,iVBORw0KGgo=",
      })
    );
  });

  test("the profile offers a tip button that shows the address", async function (assert) {
    await visit("/u/charlie");

    assert.dom(".monero-tip-profile .monero-tip-trigger").exists();

    await click(".monero-tip-profile .monero-tip-trigger");

    assert.dom(".monero-tip-modal__address").hasValue(ADDRESS);
    assert.dom(".monero-tip-modal__qr").exists("the QR comes from the server");
  });
});

acceptance("Monero tips | a member without one", function (needs) {
  needs.user();
  needs.settings({ monero_tips_enabled: true, monero_tips_icon: "coins" });

  needs.pretender((server, helper) => {
    server.get("/u/charlie.json", () => helper.response(profileWith(null)));
  });

  test("is not offered a tip button", async function (assert) {
    await visit("/u/charlie");

    assert.dom(".monero-tip-trigger").doesNotExist();
  });
});

acceptance("Monero tips | when disabled", function (needs) {
  needs.user();
  needs.settings({ monero_tips_enabled: false });

  needs.pretender((server, helper) => {
    server.get("/u/charlie.json", () => helper.response(profileWith(ADDRESS)));
  });

  test("nothing is offered", async function (assert) {
    await visit("/u/charlie");

    assert.dom(".monero-tip-trigger").doesNotExist();
  });
});
