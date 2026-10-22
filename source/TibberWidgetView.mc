import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TibberWidgetView extends WatchUi.View {
    var _priceData;
    var _isLoading;
    var _errorMessage;
    var _tibberClient;
    var _priceResolution;

    function initialize() {
        View.initialize();
        _priceData = null;
        _isLoading = false;
        _errorMessage = null;
        _tibberClient = new TibberApiClient();
        _priceResolution = "QUARTER_HOURLY";
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
        // Clear the screen with black background
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

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
        drawTextStack(dc, width, height, [
            ["Loading...", Graphics.FONT_SMALL],
            ["Tibber Energy", Graphics.FONT_TINY]
        ]);
    }

    function drawErrorScreen(dc, width, height) {
        drawTextStack(dc, width, height, [
            ["Error", Graphics.FONT_SMALL],
            [_errorMessage, Graphics.FONT_TINY],
            ["Tibber Energy", Graphics.FONT_TINY]
        ]);
    }

    function drawCurrentPriceScreen(dc, width, height) {
        if (_priceData != null) {
            var currentPrice = _priceData.get("current_price");
            var currentTime = _priceData.get("current_time");

            if (currentPrice != null) {
                var currency = _priceData.get("currency");
                var priceUnit = "öre/kWh";
                if (currency != null && !currency.equals("SEK")) {
                    priceUnit = currency + "/kWh";
                }

                var priceFont = Graphics.FONT_LARGE;
                if (width < 220 || height < 220) {
                    priceFont = Graphics.FONT_MEDIUM;
                }

                var rows = [
                    [currentPrice, priceFont],
                    [priceUnit, Graphics.FONT_SMALL]
                ];
                if (currentTime != null) {
                    rows.add([currentTime, Graphics.FONT_TINY]);
                }
                var resolutionLabel = _priceResolution.equals("HOURLY") ? "Hourly price" : "15-minute price";
                rows.add([resolutionLabel, Graphics.FONT_TINY]);
                drawTextStack(dc, width, height, rows);
            } else {
                drawTextStack(dc, width, height, [
                    ["No price data", Graphics.FONT_SMALL]
                ]);
            }
        } else {
            drawTextStack(dc, width, height, [
                ["TIBBER", Graphics.FONT_SMALL],
                ["Loading...", Graphics.FONT_TINY]
            ]);
        }
    }

    function drawTextStack(dc, width, height, rows) {
        var maxWidth = width - 16;
        var spacing = 3;
        var heights = [];
        var totalHeight = 0;

        for (var i = 0; i < rows.size(); i++) {
            var text = rows[i][0] as String;
            var font = fitFont(dc, text, rows[i][1], maxWidth);
            text = fitText(dc, text, font, maxWidth);
            rows[i][0] = text;
            rows[i][1] = font;

            var dimensions = dc.getTextDimensions(text, font);
            var lineHeight = dimensions[1];
            heights.add(lineHeight);
            totalHeight += lineHeight;
            if (i > 0) {
                totalHeight += spacing;
            }
        }

        var y = (height - totalHeight) / 2;
        for (var i = 0; i < rows.size(); i++) {
            var lineHeight = heights[i];
            var centerY = y + lineHeight / 2;
            dc.drawText(
                width / 2,
                centerY,
                rows[i][1],
                rows[i][0],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            y += lineHeight + spacing;
        }
    }

    function fitFont(dc, text, font, maxWidth) {
        while (dc.getTextWidthInPixels(text, font) > maxWidth && font != Graphics.FONT_TINY) {
            if (font == Graphics.FONT_LARGE) {
                font = Graphics.FONT_MEDIUM;
            } else if (font == Graphics.FONT_MEDIUM) {
                font = Graphics.FONT_SMALL;
            } else {
                font = Graphics.FONT_TINY;
            }
        }
        return font;
    }

    function fitText(dc, text, font, maxWidth) {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }

        var shortened = text;
        while (shortened.length() > 3 && dc.getTextWidthInPixels(shortened + "...", font) > maxWidth) {
            shortened = shortened.substring(0, shortened.length() - 1);
        }

        if (shortened.length() > 3) {
            return shortened + "...";
        }

        while (shortened.length() > 0 && dc.getTextWidthInPixels(shortened, font) > maxWidth) {
            shortened = shortened.substring(0, shortened.length() - 1);
        }
        return shortened;
    }

    function fetchPriceData() {
        _isLoading = true;
        WatchUi.requestUpdate();

        _tibberClient.getCurrentPrice(method(:onPriceDataReceived), _priceResolution);
    }

    function togglePriceResolution() {
        _priceResolution = _priceResolution.equals("QUARTER_HOURLY") ? "HOURLY" : "QUARTER_HOURLY";
        _priceData = null;
        _errorMessage = null;
        fetchPriceData();
    }

    function showPriceGraph() {
        var graphView = new TibberPriceGraphView(_priceResolution, method(:onGraphResolutionChanged));
        var graphDelegate = new TibberPriceGraphDelegate(graphView);
        WatchUi.pushView(graphView, graphDelegate, WatchUi.SLIDE_UP);
    }

    function onGraphResolutionChanged(resolution) {
        _priceResolution = resolution;
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