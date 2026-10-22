import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

class TibberWidgetView extends WatchUi.View {
    var _currentPriceData;
    var _isPriceLoading;
    var _priceErrorMessage;
    var _priceApiClient;
    var _currentPriceResolution;

    /** Initialize the price screen and its API client. */
    function initialize() {
        View.initialize();
        _currentPriceData = null;
        _isPriceLoading = false;
        _priceErrorMessage = null;
        _priceApiClient = new TibberApiClient();
        _currentPriceResolution = "QUARTER_HOURLY";
    }

    /** Lay out the price screen; drawing is sized from the device context. */
    function onLayout(dc) {
    }

    /** Refresh current price data when the main screen becomes visible. */
    function onShow() {
        fetchPriceData();
    }

    /** Release or reset view state when the main screen is hidden. */
    function onHide() {
    }

    /** Draw the loading, error, or current-price state. */
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

        var width = dc.getWidth();
        var height = dc.getHeight();

        if (_isPriceLoading) {
            drawLoadingScreen(dc, width, height);
        } else if (_priceErrorMessage != null) {
            drawErrorScreen(dc, width, height);
        } else {
            drawCurrentPriceScreen(dc, width, height);
        }
    }

    /** Draw the waiting state while the Tibber request is in flight. */
    function drawLoadingScreen(dc, width, height) {
        drawTextStack(dc, width, height, [
            ["Loading...", Graphics.FONT_SMALL],
            ["Tibber Energy", Graphics.FONT_TINY]
        ]);
    }

    /** Draw an API or parsing error for the current-price request. */
    function drawErrorScreen(dc, width, height) {
        drawTextStack(dc, width, height, [
            ["Error", Graphics.FONT_SMALL],
            [_priceErrorMessage, Graphics.FONT_TINY],
            ["Tibber Energy", Graphics.FONT_TINY]
        ]);
    }

    /** Draw the current price, currency, timestamp, and selected resolution. */
    function drawCurrentPriceScreen(dc, width, height) {
        if (_currentPriceData != null) {
            var currentPriceText = _currentPriceData.get("current_price");
            var currentIntervalTime = _currentPriceData.get("current_time");

            if (currentPriceText != null) {
                var currency = _currentPriceData.get("currency");
                var priceUnit = "öre/kWh";
                if (currency != null && !currency.equals("SEK")) {
                    priceUnit = currency + "/kWh";
                }

                var priceFont = Graphics.FONT_LARGE;
                if (width < 220 || height < 220) {
                    priceFont = Graphics.FONT_MEDIUM;
                }

                var priceRows = [
                    [currentPriceText, priceFont],
                    [priceUnit, Graphics.FONT_SMALL]
                ];
                if (currentIntervalTime != null) {
                    priceRows.add([currentIntervalTime, Graphics.FONT_TINY]);
                }
                var resolutionLabel = _currentPriceResolution.equals("HOURLY") ? "Hourly price" : "15-minute price";
                priceRows.add([resolutionLabel, Graphics.FONT_TINY]);
                drawTextStack(dc, width, height, priceRows);
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

    /** Measure and vertically center a stack of text/font row pairs. */
    function drawTextStack(dc, width, height, textRows) {
        var availableTextWidth = width - 16;
        var rowSpacing = 3;
        var rowHeights = [];
        var textStackHeight = 0;

        for (var rowIndex = 0; rowIndex < textRows.size(); rowIndex++) {
            var rowText = textRows[rowIndex][0] as String;
            var rowFont = fitFont(dc, rowText, textRows[rowIndex][1], availableTextWidth);
            rowText = fitText(dc, rowText, rowFont, availableTextWidth);
            textRows[rowIndex][0] = rowText;
            textRows[rowIndex][1] = rowFont;

            var textDimensions = dc.getTextDimensions(rowText, rowFont);
            var rowHeight = textDimensions[1];
            rowHeights.add(rowHeight);
            textStackHeight += rowHeight;
            if (rowIndex > 0) {
                textStackHeight += rowSpacing;
            }
        }

        var nextRowTop = (height - textStackHeight) / 2;
        for (var rowIndex = 0; rowIndex < textRows.size(); rowIndex++) {
            var rowHeight = rowHeights[rowIndex];
            var rowCenterY = nextRowTop + rowHeight / 2;
            dc.drawText(
                width / 2,
                rowCenterY,
                textRows[rowIndex][1],
                textRows[rowIndex][0],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            nextRowTop += rowHeight + rowSpacing;
        }
    }

    /** Choose the largest built-in font that fits a line within maxWidth. */
    function fitFont(dc, candidateText, preferredFont, availableTextWidth) {
        var selectedFont = preferredFont;
        while (dc.getTextWidthInPixels(candidateText, selectedFont) > availableTextWidth && selectedFont != Graphics.FONT_TINY) {
            if (selectedFont == Graphics.FONT_LARGE) {
                selectedFont = Graphics.FONT_MEDIUM;
            } else if (selectedFont == Graphics.FONT_MEDIUM) {
                selectedFont = Graphics.FONT_SMALL;
            } else {
                selectedFont = Graphics.FONT_TINY;
            }
        }
        return selectedFont;
    }

    /** Truncate text with an ellipsis when it remains too wide at FONT_TINY. */
    function fitText(dc, candidateText, selectedFont, availableTextWidth) {
        if (dc.getTextWidthInPixels(candidateText, selectedFont) <= availableTextWidth) {
            return candidateText;
        }

        var shortenedText = candidateText;
        while (shortenedText.length() > 3 && dc.getTextWidthInPixels(shortenedText + "...", selectedFont) > availableTextWidth) {
            shortenedText = shortenedText.substring(0, shortenedText.length() - 1);
        }

        if (shortenedText.length() > 3) {
            return shortenedText + "...";
        }

        while (shortenedText.length() > 0 && dc.getTextWidthInPixels(shortenedText, selectedFont) > availableTextWidth) {
            shortenedText = shortenedText.substring(0, shortenedText.length() - 1);
        }
        return shortenedText;
    }

    /** Request the current price using the selected main-screen resolution. */
    function fetchPriceData() {
        _isPriceLoading = true;
        WatchUi.requestUpdate();

        _priceApiClient.getCurrentPrice(method(:onPriceDataReceived), _currentPriceResolution);
    }

    /** Switch hourly/quarter-hourly resolution and reload the current price. */
    function togglePriceResolution() {
        _currentPriceResolution = _currentPriceResolution.equals("QUARTER_HOURLY") ? "HOURLY" : "QUARTER_HOURLY";
        _currentPriceData = null;
        _priceErrorMessage = null;
        fetchPriceData();
    }

    /** Push the graph detail view above the current-price screen. */
    function showPriceGraph() {
        var graphView = new TibberPriceGraphView();
        var graphDelegate = new TibberPriceGraphDelegate(graphView);
        WatchUi.pushView(graphView, graphDelegate, WatchUi.SLIDE_UP);
    }

    /** Refresh current-price data from a touch or physical input event. */
    function refreshPriceData() {
        // Public method for refreshing data on button press
        System.println("refreshPriceData called");
        fetchPriceData();
    }

    /** Save the result of the asynchronous current-price request. */
    function onPriceDataReceived(responseData) {
        _isPriceLoading = false;

        if (responseData instanceof Dictionary) {
            _currentPriceData = responseData;
            _priceErrorMessage = null;
        } else if (responseData instanceof String) {
            _priceErrorMessage = responseData;
            _currentPriceData = null;
        } else {
            _priceErrorMessage = "Unknown error";
            _currentPriceData = null;
        }

        WatchUi.requestUpdate();
    }

}