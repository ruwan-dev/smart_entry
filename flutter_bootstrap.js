{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    const config = {
      renderer: "html", // CanvasKit වෙනුවට html renderer එක පාවිච්චි කරමු (ලෝඩ් වෙන්න ලේසියි)
    };
    
    const appRunner = await engineInitializer.initializeEngine(config);
    
    // ඇප් එක run කරනවා
    await appRunner.runApp();

    // ඇප් එක run වෙලා තත්පර බාගයකට පස්සේ විතරක් loader එක අයින් කරනවා
    // එතකොට අර සුදු screen එක එන්න වෙලාවක් ලැබෙන්නේ නැහැ
    setTimeout(function() {
      var loader = document.getElementById('initial-loader');
      if (loader) {
        loader.style.display = 'none';
        loader.remove();
      }
    }, 500);
  }
});