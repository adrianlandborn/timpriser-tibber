import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when your application is exiting
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view of your widget here
    function getInitialView() {
        var view = new TibberWidgetView();
        var delegate = new TibberWidgetDelegate(view);
        return [view, delegate];
    }

}