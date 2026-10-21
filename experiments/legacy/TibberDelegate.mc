import Toybox.WatchUi;
import Toybox.System;

class TibberDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onMenu() {
        // Menu not used in widget mode
        return false;
    }

    function onSelect() {
        // Refresh data when select button is pressed
        return false;
    }

}