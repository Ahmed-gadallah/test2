{{flutter_js}}
{{flutter_build_config}}

// Render into #zaad-app when the page provides one (phone-width frame for the
// shareable demo); otherwise take the whole page as usual.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const host = document.querySelector('#zaad-app');
    const appRunner = await engineInitializer.initializeEngine(host ? { hostElement: host } : {});
    await appRunner.runApp();
  },
});
