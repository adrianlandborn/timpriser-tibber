import Toybox.WatchUi;

class TibberPriceGraphDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.refreshPriceData();
        return true;
    }

    function onMenu() {
        _view.togglePriceResolution();
        return true;
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onNextPage() {
        return true;
    }
}