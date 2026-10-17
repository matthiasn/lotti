// Opens Paddle's overlay checkout for the session the app created.
//
// The app opens this page as checkout.html#session=<id>&price=<price id>.
// Both values arrive in the fragment, which browsers never send to a server,
// so neither this site's logs nor any proxy sees the session id. Paddle gets
// it as customData and echoes it in the webhook, which is how the payment is
// attributed to the app's anonymous entitlement — no account, no email here.
(function () {
  'use strict';

  var config = window.LOTTI_SYNC_CHECKOUT || {};
  var status = document.getElementById('status');
  var retry = document.getElementById('retry');

  var params = new URLSearchParams(window.location.hash.slice(1));
  var sessionId = params.get('session') || '';
  var priceId = params.get('price') || '';

  function show(message) {
    status.textContent = message;
  }

  if (!/^[A-Za-z0-9_-]{16,128}$/.test(sessionId) || !/^pri_[a-z0-9]+$/.test(priceId)) {
    show('This checkout link is incomplete. Start again from Lotti: Settings → Sync.');
    return;
  }
  if (!window.Paddle || !config.paddleClientToken) {
    show('The checkout could not load. Check your connection and reload this page.');
    return;
  }

  if (config.paddleEnvironment === 'sandbox') {
    window.Paddle.Environment.set('sandbox');
  }

  function open() {
    retry.hidden = true;
    window.Paddle.Checkout.open({
      items: [{ priceId: priceId, quantity: 1 }],
      customData: { checkout_session_id: sessionId },
      settings: {
        displayMode: 'overlay',
        theme: 'light',
        successUrl: config.successUrl,
      },
    });
  }

  window.Paddle.Initialize({
    token: config.paddleClientToken,
    eventCallback: function (event) {
      if (event.name === 'checkout.closed') {
        show('Checkout closed. You can reopen it, or return to Lotti.');
        retry.hidden = false;
      } else if (event.name === 'checkout.completed') {
        show('Payment received. Return to Lotti — sync is being set up.');
      }
    },
  });
  retry.addEventListener('click', open);
  open();
})();
