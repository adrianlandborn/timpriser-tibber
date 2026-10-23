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
    var _poppinsTinyFont;
    var _poppinsSmallFont;
    var _poppinsMediumFont;
    var _poppinsLargeFont;
    var _poppinsPriceFont;
    var _widgetLogo;

    /** Initialize the price screen and its API client. */
    function initialize() {
        View.initialize();
        _currentPriceData = null;
        _isPriceLoading = false;
        _priceErrorMessage = null;
        _priceApiClient = new TibberApiClient();
        _currentPriceResolution = "QUARTER_HOURLY";
        _poppinsTinyFont = WatchUi.loadResource(Rez.Fonts.PoppinsTiny) as WatchUi.FontResource;
        _poppinsSmallFont = WatchUi.loadResource(Rez.Fonts.PoppinsSmall) as WatchUi.FontResource;
        _poppinsMediumFont = WatchUi.loadResource(Rez.Fonts.PoppinsMedium) as WatchUi.FontResource;
        _poppinsLargeFont = WatchUi.loadResource(Rez.Fonts.PoppinsLarge) as WatchUi.FontResource;
        _poppinsPriceFont = WatchUi.loadResource(Rez.Fonts.PoppinsPrice) as WatchUi.FontResource;
        _widgetLogo = WatchUi.loadResource(Rez.Drawables.WidgetLogo) as WatchUi.BitmapResource;
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
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

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
            ["Loading...", _poppinsSmallFont],
            ["Tibber Energy", _poppinsTinyFont]
        ], null);
    }

    /** Draw an API or parsing error for the current-price request. */
    function drawErrorScreen(dc, width, height) {
        drawTextStack(dc, width, height, [
            ["Error", _poppinsSmallFont],
            [_priceErrorMessage, _poppinsTinyFont],
            ["Tibber Energy", _poppinsTinyFont]
        ], null);
    }

    /** Draw the current price, currency, timestamp, and selected resolution. */
    function drawCurrentPriceScreen(dc, width, height) {
        if (_currentPriceData != null) {
            var currentPriceText = _currentPriceData.get("current_price");
            var currentIntervalTime = _currentPriceData.get("current_time");
            var currentIntervalMinutes = _currentPriceData.get("interval_minutes");

            if (currentPriceText != null) {
                var currency = _currentPriceData.get("currency");
                var priceUnit = "öre";
                if (currency != null && !currency.equals("SEK")) {
                    priceUnit = currency;
                }

                var priceRows = [
                    [currentPriceText + " " + priceUnit, _poppinsPriceFont]
                ];
                var currentIntervalRange = formatIntervalRange(currentIntervalTime, currentIntervalMinutes);
                if (currentIntervalRange != null) {
                    priceRows.add([currentIntervalRange, _poppinsSmallFont]);
                }
                drawTextStack(dc, width, height, priceRows, _widgetLogo);
            } else {
                drawTextStack(dc, width, height, [
                    ["No price data", _poppinsSmallFont]
                ], null);
            }
        } else {
            drawTextStack(dc, width, height, [
                ["Loading...", _poppinsTinyFont]
            ], _widgetLogo);
        }
    }

    /** Format an interval start and duration as an HH:mm-HH:mm range. */
    function formatIntervalRange(startTime, intervalMinutes) {
        if (!(startTime instanceof String) || intervalMinutes == null || startTime.length() < 5) {
            return null;
        }

        var startHour = startTime.substring(0, 2).toNumber();
        var startMinute = startTime.substring(3, 5).toNumber();
        if (startHour == null || startMinute == null) {
            return null;
        }

        var endMinuteOfDay = (startHour * 60 + startMinute + intervalMinutes) % 1440;
        var endTime = (endMinuteOfDay / 60).format("%02d") + ":" + (endMinuteOfDay % 60).format("%02d");
        return startTime.substring(0, 5) + "-" + endTime;
    }

    /** Measure and vertically center a stack of text/font rows and optional logo. */
    function drawTextStack(dc, width, height, textRows, logoResource) {
        var availableTextWidth = width - 16;
        var rowSpacing = 3;
        var logoSpacing = 8;
        var rowHeights = [];
        var contentHeight = 0;

        for (var rowIndex = 0; rowIndex < textRows.size(); rowIndex++) {
            var rowText = textRows[rowIndex][0] as String;
            var rowFont = fitFont(dc, rowText, textRows[rowIndex][1], availableTextWidth);
            rowText = fitText(dc, rowText, rowFont, availableTextWidth);
            textRows[rowIndex][0] = rowText;
            textRows[rowIndex][1] = rowFont;

            var textDimensions = dc.getTextDimensions(rowText, rowFont);
            var rowHeight = textDimensions[1];
            rowHeights.add(rowHeight);
            contentHeight += rowHeight;
            if (rowIndex > 0) {
                contentHeight += rowSpacing;
            }
        }

        if (logoResource != null) {
            contentHeight += logoResource.getHeight() + logoSpacing;
        }

        var verticalOffset = 10;
        var nextRowTop = (height - contentHeight) / 2 - verticalOffset;
        if (logoResource != null) {
            var logoX = (width - logoResource.getWidth()) / 2;
            dc.drawBitmap(logoX, nextRowTop, logoResource);
            nextRowTop += logoResource.getHeight() + logoSpacing;
        }

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
        while (dc.getTextWidthInPixels(candidateText, selectedFont) > availableTextWidth && selectedFont != _poppinsTinyFont) {
            if (selectedFont == _poppinsPriceFont) {
                selectedFont = _poppinsLargeFont;
            } else if (selectedFont == _poppinsLargeFont) {
                selectedFont = _poppinsMediumFont;
            } else if (selectedFont == _poppinsMediumFont) {
                selectedFont = _poppinsSmallFont;
            } else {
                selectedFont = _poppinsTinyFont;
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
        var graphView = new TibberPriceGraphView(_poppinsTinyFont, _poppinsSmallFont, _poppinsMediumFont);
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