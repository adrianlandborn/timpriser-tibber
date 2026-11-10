import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class TibberApp extends Application.AppBase {
    private var _priceView;
    /** Lite start screen; only set on devices without glance support. */
    private var _liteView;

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

    /**
     * Create the initial view and its input delegate. Without glance support the system keeps
     * UP/DOWN on the root view for its widget loop, so the root is a lite price screen and START
     * opens the full widget as a pushed view, where UP/DOWN reach the app.
     */
    function getInitialView() {
        TibberPhoneSettings.apply();
        if (!(WatchUi has :GlanceView)) {
            var liteView = new TibberWidgetView(true);
            _liteView = liteView;
            return [liteView, new TibberLiteDelegate()];
        }
        var priceView = new TibberWidgetView(false);
        _priceView = priceView;
        var inputDelegate = new TibberWidgetDelegate(priceView);
        return [priceView, inputDelegate];
    }

    /** True when the full widget is pushed above the lite start screen. */
    function isWidgetPushed() {
        return _liteView != null;
    }

    /** Push the full widget above the lite start screen. */
    function openWidget() as Void {
        var priceView = new TibberWidgetView(false);
        _priceView = priceView;
        WatchUi.pushView(priceView, new TibberWidgetDelegate(priceView), WatchUi.SLIDE_UP);
    }

    /** Leave the full widget for the lite start screen and release it. */
    function closeWidget() as Void {
        _priceView = null;
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

    /** Apply phone settings and refetch prices when the user edits settings in Garmin Connect. */
    function onSettingsChanged() as Void {
        TibberPhoneSettings.apply();
        if (_priceView != null) {
            _priceView.reloadSettings();
        }
        if (_liteView != null) {
            _liteView.reloadSettings();
        }
        WatchUi.requestUpdate();
    }

    /** Provide a compact current-price preview in the widget glance list. */
    function getGlanceView() {
        return [new TibberGlanceView()];
    }

}