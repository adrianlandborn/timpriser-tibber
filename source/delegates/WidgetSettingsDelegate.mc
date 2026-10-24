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