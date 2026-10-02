import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
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

function topicWith(address) {
  const payload = cloneJSON(topicFixtures["/t/280/1.json"]);
  const [first, ...rest] = payload.post_stream.posts;
  first.user_custom_fields = { monero_address: address };
  rest.forEach((post) => (post.user_custom_fields = {}));
  return payload;
}

acceptance("Monero tips | on a post", function (needs) {
  needs.user();
  needs.settings({ monero_tips_enabled: true, monero_tips_icon: "coins" });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => helper.response(topicWith(ADDRESS)));
    server.get("/monero-tips/:username.json", () =>
      helper.response({
        address: ADDRESS,
        uri: `monero:${ADDRESS}`,
        qr: "data:image/png;base64,iVBORw0KGgo=",
      })
    );
  });

  test("the tip button sits with the post menu's bottom-left controls", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#post_1 .post-controls .post-action-menu__monero-tip")
      .exists("the author with an address can be tipped");
    assert
      .dom(".topic-meta-data .monero-tip-trigger")
      .doesNotExist("it is no longer next to the name");
    assert
      .dom("#post_2 .post-action-menu__monero-tip")
      .doesNotExist("authors without an address are not offered");

    await click("#post_1 .post-action-menu__monero-tip");

    assert.dom(".monero-tip-modal__address").hasValue(ADDRESS);
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
