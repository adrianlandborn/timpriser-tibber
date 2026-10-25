import Toybox.WatchUi;

class TibberNetworkFeeDetailDelegate extends WatchUi.BehaviorDelegate {
    private var _detailView;

    function initialize(detailView) {
        BehaviorDelegate.initialize();
        _detailView = detailView;
    }

    function onPreviousPage() {
        return _detailView.adjust(1);
    }

    function onNextPage() {
        return _detailView.adjust(-1);
    }

    function onTap(clickEvent) {
        var coordinates = clickEvent.getCoordinates();
        return _detailView.adjustAt(coordinates[0], coordinates[1]);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}