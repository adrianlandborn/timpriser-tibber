import Toybox.WatchUi;

class TibberPriceGraphDelegate extends WatchUi.BehaviorDelegate {
    var _graphView;

    /** Create an input delegate for a graph page. */
    function initialize(graphView) {
        BehaviorDelegate.initialize();
        _graphView = graphView;
    }

    /** Refresh the graph page when START/SELECT is pressed. */
    function onSelect() {
        _graphView.refreshPriceData();
        return true;
    }

    /** Refresh the graph page when MENU is pressed. */
    function onMenu() {
        _graphView.refreshPriceData();
        return true;
    }

    /** Return from the graph detail view to the current-price screen. */
    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    /** Select the quarter-hour prices page. */
    function onPreviousPage() {
        _graphView.showQuarterHourlyPage();
        return true;
    }

    /** Select the hourly today/tomorrow prices page. */
    function onNextPage() {
        _graphView.showHourlyPage();
        return true;
    }
}