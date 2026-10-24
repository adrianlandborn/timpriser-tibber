import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberApp extends Application.AppBase {

    /** Initialize the base Connect IQ application. */
    function initialize() {
        AppBase.initialize();
    }

    /** Handle application startup state when the widget is opened. */
    function onStart(state as Dictionary?) as Void {
    }

    /** Handle application shutdown state when the widget is closed. */
    function onStop(state as Dictionary?) as Void {
    }

    /** Create the initial price view and its input delegate. */
    function getInitialView() {
        var priceView = new TibberWidgetView();
        var inputDelegate = new TibberWidgetDelegate(priceView);
        return [priceView, inputDelegate];
    }

    /** Provide a compact current-price preview in the widget glance list. */
    function getGlanceView() {
        return [new TibberGlanceView()];
    }

}