{{flutter_js}}
{{flutter_build_config}}

// The application owns its Push/PWA service worker in index.html.
// Do not pass Flutter serviceWorkerSettings here: registering Flutter's
// generated worker on the same scope would replace/race the custom worker.
_flutter.loader.load();
