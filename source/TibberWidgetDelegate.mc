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
        // Handle SELECT button press - refresh price data
        System.println("onSelect called");
        if (_view != null && _view has :refreshPriceData) {
            System.println("Calling refreshPriceData");
            _view.refreshPriceData();
        } else {
            System.println("View is null or doesn't have refreshPriceData");
        }
        return true;
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
            if (_view != null && _view has :refreshPriceData) {
                System.println("Calling refreshPriceData from key");
                _view.refreshPriceData();
            }
            return true;
        }
        return false;
    }

    function onMenu() {
        // Handle menu button - refresh data
        System.println("onMenu called");
        if (_view != null && _view has :refreshPriceData) {
            System.println("Calling refreshPriceData from menu");
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