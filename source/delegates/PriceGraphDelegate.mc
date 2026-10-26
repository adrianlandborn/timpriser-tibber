import Toybox.WatchUi;

class TibberPriceGraphDelegate extends WatchUi.BehaviorDelegate {
    var _graphView;
    var _widgetView;

    /** Create an input delegate for a graph page; the widget view hosts the settings. */
    function initialize(graphView, widgetView) {
        BehaviorDelegate.initialize();
        _graphView = graphView;
        _widgetView = widgetView;
    }

    /** Refresh the graph page when START/SELECT is pressed. */
    function onSelect() {
        _graphView.refreshPriceData();
        return true;
    }

    /** Open price and resolution settings when MENU is pressed. */
    function onMenu() {
        _widgetView.showSettings();
        return true;
    }

    /** Return from the graph detail view to the current-price screen. */
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    /** Move up from quarter-hour prices to the widget or to hourly prices. */
    function onPreviousPage() {
        if (_graphView.getSelectedPage() == 0) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            _graphView.showQuarterHourlyPage();
        }
        return true;
    }

    /** Move down from hourly prices to the widget or to quarter-hour prices. */
    function onNextPage() {
        if (_graphView.getSelectedPage() == 1) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else {
            _graphView.showHourlyPage();
        }
        return true;
    }
}