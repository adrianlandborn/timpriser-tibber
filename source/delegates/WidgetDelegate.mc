import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

class TibberWidgetDelegate extends WatchUi.BehaviorDelegate {
    var _widgetView;

    /** Create the main-screen input delegate. */
    function initialize(widgetView) {
        BehaviorDelegate.initialize();
        _widgetView = widgetView;
    }

    /** Refresh the current price when START/SELECT is pressed; on older touch-only devices a tap opens the next screen instead. */
    function onSelect() {
        if (TibberTouchScroll.isEnabled()) {
            return onNextPage();
        }
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

    /** Route ENTER through onSelect on devices that report key events directly. */
    function onKey(keyEvent) {
        var pressedKey = keyEvent.getKey();
        if (pressedKey == WatchUi.KEY_ENTER) {
            onSelect();
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

    /** Return to the lite start screen when the widget was opened from it; otherwise let the system close the widget. */
    function onBack() {
        var app = Application.getApp() as TibberApp;
        if (app.isWidgetPushed()) {
            app.closeWidget();
            return true;
        }
        return false;
    }
}