import Toybox.WatchUi;

class TibberWidgetSettingsDelegate extends WatchUi.BehaviorDelegate {
    private var _settingsView;

    function initialize(settingsView) {
        BehaviorDelegate.initialize();
        _settingsView = settingsView;
    }

    function onPreviousPage() {
        return _settingsView.moveSelection(-1);
    }

    function onNextPage() {
        return _settingsView.moveSelection(1);
    }

    function onPreviousMode() {
        return _settingsView.openSelectedNetworkFeeDetails();
    }

    function onNextMode() {
        return _settingsView.openSelectedNetworkFeeDetails();
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_LEFT) {
            return _settingsView.openSelectedNetworkFeeDetails();
        } else if (key == WatchUi.KEY_RIGHT) {
            return _settingsView.openSelectedNetworkFeeDetails();
        }
        return false;
    }

    function onSelect() {
        return _settingsView.selectCurrentOption();
    }

    function onTap(clickEvent) {
        var coordinates = clickEvent.getCoordinates();
        return _settingsView.selectOptionAt(coordinates[0], coordinates[1]);
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}