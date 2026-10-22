import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TibberWidgetDelegate extends WatchUi.BehaviorDelegate {
    var _widgetView;

    /** Create the main-screen input delegate. */
    function initialize(widgetView) {
        BehaviorDelegate.initialize();
        _widgetView = widgetView;
        System.println("TibberWidgetDelegate initialized with view: " + (_widgetView != null ? "yes" : "no"));
    }

    /** Open the graph when START/SELECT is pressed. */
    function onSelect() {
        if (_widgetView != null && _widgetView has :showPriceGraph) {
            _widgetView.showPriceGraph();
            return true;
        }
        return false;
    }

    /** Refresh the current price when the screen is tapped. */
    function onTap(tapEvent) {
        System.println("onTap called");
        if (_widgetView != null && _widgetView has :refreshPriceData) {
            System.println("Calling refreshPriceData from tap");
            _widgetView.refreshPriceData();
        }
        return true;
    }

    /** Route the physical ENTER key to the graph entry action. */
    function onKey(keyEvent) {
        System.println("onKey called");
        var pressedKey = keyEvent.getKey();
        if (pressedKey == WatchUi.KEY_ENTER) {
            if (_widgetView != null && _widgetView has :showPriceGraph) {
                _widgetView.showPriceGraph();
            }
            return true;
        }
        return false;
    }

    /** Toggle current-price resolution from the main screen's MENU button. */
    function onMenu() {
        if (_widgetView != null && _widgetView has :togglePriceResolution) {
            _widgetView.togglePriceResolution();
        } else if (_widgetView != null && _widgetView has :refreshPriceData) {
            _widgetView.refreshPriceData();
        }
        return true;
    }

    /** Preserve the widget's existing back-button behavior. */
    function onBack() {
        // Handle back button - close widget
        System.println("onBack called");
        return true;
    }
}