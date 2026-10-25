import Toybox.WatchUi;
import Toybox.Lang;

class TibberWidgetDelegate extends WatchUi.BehaviorDelegate {
    var _widgetView;

    /** Create the main-screen input delegate. */
    function initialize(widgetView) {
        BehaviorDelegate.initialize();
        _widgetView = widgetView;
    }

    /** Refresh the current price when START/SELECT is pressed. */
    function onSelect() {
        if (_widgetView != null && _widgetView has :refreshPriceData) {
            _widgetView.refreshPriceData();
            return true;
        }
        return false;
    }

    /** Open the hourly graph when navigating upward from the main view. */
    function onPreviousPage() {
        if (_widgetView != null && _widgetView has :showPriceGraph) {
            _widgetView.showPriceGraph(1);
            return true;
        }
        return false;
    }

    /** Open the quarter-hour graph when navigating downward from the main view. */
    function onNextPage() {
        if (_widgetView != null && _widgetView has :showPriceGraph) {
            _widgetView.showPriceGraph(0);
            return true;
        }
        return false;
    }

    /** Refresh the current price when the screen is tapped. */
    function onTap(tapEvent) {
        if (_widgetView != null && _widgetView has :refreshPriceData) {
            _widgetView.refreshPriceData();
        }
        return true;
    }

    /** Keep ENTER mapped to refresh on devices that report key events directly. */
    function onKey(keyEvent) {
        var pressedKey = keyEvent.getKey();
        if (pressedKey == WatchUi.KEY_ENTER) {
            if (_widgetView != null && _widgetView has :refreshPriceData) {
                _widgetView.refreshPriceData();
            }
            return true;
        }
        return false;
    }

    /** Open price and resolution settings. */
    function onMenu() {
        if (_widgetView != null && _widgetView has :showSettings) {
            _widgetView.showSettings();
        }
        return true;
    }

    /** Allow the system to close the widget from its base view. */
    function onBack() {
        return false;
    }
}