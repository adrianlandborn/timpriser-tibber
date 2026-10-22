import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TibberWidgetDelegate extends WatchUi.BehaviorDelegate {
    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
        System.println("TibberWidgetDelegate initialized with view: " + (_view != null ? "yes" : "no"));
    }

    function onSelect() {
        if (_view != null && _view has :showPriceGraph) {
            _view.showPriceGraph();
            return true;
        }
        return false;
    }

    function onTap(clickEvent) {
        // Handle touch screen tap - refresh on tap
        System.println("onTap called");
        if (_view != null && _view has :refreshPriceData) {
            System.println("Calling refreshPriceData from tap");
            _view.refreshPriceData();
        }
        return true;
    }

    function onKey(keyEvent) {
        // Handle any key press
        System.println("onKey called");
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            if (_view != null && _view has :showPriceGraph) {
                _view.showPriceGraph();
            }
            return true;
        }
        return false;
    }

    function onMenu() {
        if (_view != null && _view has :togglePriceResolution) {
            _view.togglePriceResolution();
        } else if (_view != null && _view has :refreshPriceData) {
            _view.refreshPriceData();
        }
        return true;
    }

    function onBack() {
        // Handle back button - close widget
        System.println("onBack called");
        return true;
    }
}