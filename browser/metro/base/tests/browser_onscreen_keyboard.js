/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

function test() {
  runTests();
}

gTests.push({
  desc: "Onscreen keyboard tests",
  run: function() {
    // By design, Metro apps can't show the keyboard programmatically, so we
    // can't use the real keyboard in this test:
    // http://msdn.microsoft.com/en-us/library/windows/apps/hh465404.aspx#user-driven_invocation
    //
    // Instead, we will use this mock object to simulate keyboard changes.
    let originalUtils = window.MetroUtils;
    window.MetroUtils = {
      keyboardHeight: 0,
      keyboardVisible: false
    };
    registerCleanupFunction(function() {
      window.MetroUtils = originalUtils;
    });

    let tab = yield addTab(chromeRoot + "browser_onscreen_keyboard.html");
    // Explicitly dismiss the toolbar at the start, because it messes with the
    // keyboard and sizing if it's dismissed later.
    ContextUI.dismiss();

    let doc = tab.browser.contentDocument;
    let text = doc.getElementById("text")
    let rect0 = text.getBoundingClientRect();
    text.focus();

    // "Show" the keyboard.
    MetroUtils.keyboardHeight = 100;
    MetroUtils.keyboardVisible = true;
    Services.obs.notifyObservers(null, "metro_softkeyboard_shown", null);

    let rect1 = text.getBoundingClientRect();
    is(rect1.top, rect0.top - 100, "text field moves up by 100px");

    // "Hide" the keyboard.
    MetroUtils.keyboardHeight = 0;
    MetroUtils.keyboardVisible = false;
    Services.obs.notifyObservers(null, "metro_softkeyboard_hidden", null);

    let rect2 = text.getBoundingClientRect();
    is(rect2.top, rect0.top, "text field moves back to the original position");

    finish();
  }
});
