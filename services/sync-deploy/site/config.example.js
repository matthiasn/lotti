// Copy to config.js on the server and fill in. The client-side token is public
// by design (Paddle → Developer tools → Authentication → client-side tokens);
// the API key and webhook secret never belong here.
window.LOTTI_SYNC_CHECKOUT = {
  paddleEnvironment: 'sandbox', // 'production' once the domain is approved
  paddleClientToken: 'test_replace_me',
  successUrl: 'https://sync.example.com/success',
};
