import Toybox.Graphics;
import Toybox.WatchUi;

// Startup smoke tests: constructing a view runs its resource loading, so an
// out-of-memory error or a missing resource on a device fails here instead of
// only on the watch. Test builds use more memory than the release app, so a
// pass is a weaker signal than launching the .prg. The glance process is not
// exercised (tests do not run as a glance).

(:test)
function testWidgetViewStartup(logger) {
    var view = new TibberWidgetView(false);
    return view != null && view.getPriceFont() != null;
}

(:test)
function testGlanceViewStartup(logger) {
    if (!(WatchUi has :GlanceView)) {
        // Connect IQ 3.x devices (venu, vivoactive4, fenix6) have no glance class to extend.
        logger.debug("GlanceView not available; skipping");
        return true;
    }
    var view = new TibberGlanceView();
    return view != null;
}

(:test)
function testWidgetViewAllFontsLoaded(logger) {
    // Worst case for the main screens: the graph and settings screens need the
    // Medium and Large fonts on top of everything loaded at startup.
    var view = new TibberWidgetView(false);
    return view.getMediumFont() != null && view.getLargeFont() != null;
}

(:test)
function testLiteWidgetViewStartup(logger) {
    // Lite start screen on devices without glance support: cached price only, no API client.
    var view = new TibberWidgetView(true);
    return view.isLite() && view.getPriceFont() != null && view._priceApiClient == null;
}
