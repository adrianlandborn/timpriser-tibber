import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class TibberApp extends Application.AppBase {
    private var _priceView;

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
        TibberPhoneSettings.apply();
        var priceView = new TibberWidgetView();
        _priceView = priceView;
        var inputDelegate = new TibberWidgetDelegate(priceView);
        return [priceView, inputDelegate];
    }

    /** Apply phone settings and refetch prices when the user edits settings in Garmin Connect. */
    function onSettingsChanged() as Void {
        TibberPhoneSettings.apply();
        if (_priceView != null) {
            _priceView.reloadSettings();
        }
        WatchUi.requestUpdate();
    }

    /** Provide a compact current-price preview in the widget glance list. */
    function getGlanceView() {
        return [new TibberGlanceView()];
    }

}