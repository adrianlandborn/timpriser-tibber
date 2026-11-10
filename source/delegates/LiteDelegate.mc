import Toybox.Application;
import Toybox.WatchUi;

/**
 * Input for the lite start screen on devices without glance support. The system keeps UP/DOWN
 * there for its widget loop, so START (or a tap) opens the full widget, where UP/DOWN work.
 */
class TibberLiteDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    /** Open the full widget. */
    function onSelect() {
        (Application.getApp() as TibberApp).openWidget();
        return true;
    }

    /** Open the full widget on a tap (touch devices). */
    function onTap(tapEvent) {
        return onSelect();
    }

    /** Route ENTER through onSelect on devices that report key events directly. */
    function onKey(keyEvent) {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) {
            return onSelect();
        }
        return false;
    }

    /** Let the system close the widget. */
    function onBack() {
        return false;
    }
}
