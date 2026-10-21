import Toybox.WatchUi;

class TibberMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        // Menu not used in widget mode
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}