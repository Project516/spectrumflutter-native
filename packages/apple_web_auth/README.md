# apple_web_auth

`ASWebAuthenticationSession` as an OAuth redirect listener.

```dart
final callback = await appleWebAuthenticate(
  url: authorizeUrl,
  callbackScheme: 'spectrumstrategy',
);
final code = callback.queryParameters['code'];
```

This is the mobile answer to a loopback redirect. A desktop app can bind
`127.0.0.1` and have the browser redirect to it (RFC 8252); an iPhone cannot
rely on that, so the OS runs the browser and hands the app back a URL on a
scheme it registered.

## Things worth knowing before using it

- **The scheme has to be in `Info.plist`** under `CFBundleURLTypes`, and it
  has to match the `redirect_uri` sent to the provider. Miss either and the
  callback never arrives, with no error to read.
- **A closed sheet throws `AppleWebAuthCancelled`, not an error.** Somebody
  backing out is an ordinary outcome with nothing to report and nothing to
  retry, so it is worth telling apart.
- **The session shares Safari's cookies.** Somebody already signed in to the
  provider is not asked again. `prefersEphemeralWebBrowserSession` is off for
  that reason; turn it on only if a shared device makes that wrong.
- Off iOS and macOS every call throws rather than doing nothing, so a caller
  that reaches here on the wrong platform finds out.
