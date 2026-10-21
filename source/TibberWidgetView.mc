import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TibberWidgetView extends WatchUi.View {
    var _priceData;
    var _isLoading;
    var _errorMessage;
    var _tibberClient;

    function initialize() {
        View.initialize();
        _priceData = null;
        _isLoading = false;
        _errorMessage = null;
        _tibberClient = new TibberApiClient();
    }

    // Load your resources here
    function onLayout(dc) {
        // Simple layout - no complex resources needed
    }

    // Called when this View is brought to the foreground
    function onShow() {
        // Fetch price data when widget is shown
        fetchPriceData();
    }

    // Called when this View is removed from the screen
    function onHide() {
        // Nothing to clean up
    }

    // Update the view
    function onUpdate(dc) {
        // Clear the screen with white background
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        // Set black text
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);

        var width = dc.getWidth();
        var height = dc.getHeight();

        if (_isLoading) {
            drawLoadingScreen(dc, width, height);
        } else if (_errorMessage != null) {
            drawErrorScreen(dc, width, height);
        } else {
            drawCurrentPriceScreen(dc, width, height);
        }
    }

    function drawLoadingScreen(dc, width, height) {
        dc.drawText(width / 2, height / 2 - 10, Graphics.FONT_SMALL, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height / 2 + 15, Graphics.FONT_TINY, "Tibber Energy", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawErrorScreen(dc, width, height) {
        dc.drawText(width / 2, height / 2 - 20, Graphics.FONT_TINY, "Error:", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height / 2, Graphics.FONT_TINY, _errorMessage, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height / 2 + 20, Graphics.FONT_TINY, "Tibber Energy", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawCurrentPriceScreen(dc, width, height) {
        if (_priceData != null) {
            var currentPrice = _priceData.get("current_price");
            var currentTime = _priceData.get("current_time");

            if (currentPrice != null) {
                // Current price - large and centered
                dc.drawText(width / 2, height / 2 - 25, Graphics.FONT_LARGE, currentPrice, Graphics.TEXT_JUSTIFY_CENTER);
                dc.drawText(width / 2, height / 2 + 5, Graphics.FONT_SMALL, "öre/kWh", Graphics.TEXT_JUSTIFY_CENTER);

                // Current time
                if (currentTime != null) {
                    dc.drawText(width / 2, height / 2 + 25, Graphics.FONT_TINY, currentTime, Graphics.TEXT_JUSTIFY_CENTER);
                }

                // Show current view info - positioned for round screen
                dc.drawText(width / 2, height / 2 + 40, Graphics.FONT_TINY, "Current Price", Graphics.TEXT_JUSTIFY_CENTER);
            } else {
                dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, "No price data", Graphics.TEXT_JUSTIFY_CENTER);
            }
        } else {
            dc.drawText(width / 2, height / 2 - 10, Graphics.FONT_SMALL, "TIBBER", Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, height / 2 + 10, Graphics.FONT_TINY, "Loading...", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function fetchPriceData() {
        _isLoading = true;
        WatchUi.requestUpdate();

        _tibberClient.getCurrentPrice(method(:onPriceDataReceived));
    }

    function refreshPriceData() {
        // Public method for refreshing data on button press
        System.println("refreshPriceData called");
        fetchPriceData();
    }

    function onPriceDataReceived(responseData) {
        _isLoading = false;

        if (responseData instanceof Dictionary) {
            _priceData = responseData;
            _errorMessage = null;
        } else if (responseData instanceof String) {
            _errorMessage = responseData;
            _priceData = null;
        } else {
            _errorMessage = "Unknown error";
            _priceData = null;
        }

        WatchUi.requestUpdate();
    }

}