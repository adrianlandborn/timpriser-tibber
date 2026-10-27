import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Application.Storage;

class TibberWidgetView extends WatchUi.View {
    var _currentPriceData;
    var _isPriceLoading;
    var _priceErrorMessage;
    var _priceApiClient;
    var _currentPriceResolution;
    var _currentPriceType;
    var _poppinsTinyFont;
    var _poppinsSmallFont;
    var _poppinsMediumFont;
    var _poppinsLargeFont;
    var _poppinsPriceFont;
    var _widgetLogo;
    var _hourBar;

    /** Initialize the price screen and its API client. */
    function initialize() {
        View.initialize();
        _hourBar = new HourLevelBar();
        _currentPriceData = null;
        _isPriceLoading = false;
        _priceErrorMessage = null;
        _priceApiClient = new TibberApiClient();
        _currentPriceResolution = Storage.getValue("tibber_price_resolution");
        if (!(_currentPriceResolution instanceof String) ||
            (!_currentPriceResolution.equals("HOURLY") && !_currentPriceResolution.equals("QUARTER_HOURLY"))) {
            _currentPriceResolution = "QUARTER_HOURLY";
        }
        _currentPriceType = Storage.getValue("tibber_price_type");
        if (!(_currentPriceType instanceof String) ||
            (!_currentPriceType.equals("TOTAL") && !_currentPriceType.equals("SPOT"))) {
            _currentPriceType = "TOTAL";
        }
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
        fetchPriceData(false);
    }

    /** Release or reset view state when the main screen is hidden. */
    function onHide() {
    }

    /** Draw the loading, error, or current-price state. */
    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
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
            ["Laddar...", _poppinsSmallFont],
            ["Tibber elpris", _poppinsTinyFont]
        ], null);
    }

    /** Draw an API or parsing error for the current-price request. */
    function drawErrorScreen(dc, width, height) {
        drawTextStack(dc, width, height, [
            ["Fel", _poppinsSmallFont],
            [_priceErrorMessage, _poppinsTinyFont],
            ["Tibber elpris", _poppinsTinyFont]
        ], null);
    }

    /** Draw the current price, currency, timestamp, and selected resolution. */
    function drawCurrentPriceScreen(dc, width, height) {
        if (_currentPriceData != null) {
            var priceCache = new TibberPriceCache();
            var currentPriceText = priceCache.getDisplayPrice(_currentPriceData, _currentPriceType);
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
                priceRows.add([_currentPriceType.equals("SPOT") ? "Spotpris" : "Totalpris", _poppinsTinyFont, Theme.TEXT_SECONDARY, null, -4]);
                var currentIntervalRange = formatIntervalRange(currentIntervalTime, currentIntervalMinutes);
                if (currentIntervalRange != null) {
                    priceRows.add([currentIntervalRange, _poppinsSmallFont, Theme.TEXT_PRIMARY, null, 8]);
                }
                var hourLevels = _currentPriceData.get("hour_levels");
                if (_hourBar.isValid(hourLevels)) {
                    priceRows.add([null, null, null, hourLevels]);
                }
                var tradingTaxesIncluded = _currentPriceType.equals("TOTAL");
                var networkFeesIncluded = tradingTaxesIncluded && Storage.getValue("tibber_network_fees_enabled") == true;
                priceRows.add([(tradingTaxesIncluded ? "Skatter inkl." : "Skatter exkl.") + " | " + (networkFeesIncluded ? "Nät inkl." : "Nät exkl."), _poppinsTinyFont, Theme.TEXT_SECONDARY, null, 12]);
                drawTextStack(dc, width, height, priceRows, _widgetLogo);
            } else {
                drawTextStack(dc, width, height, [
                    ["Prisdata saknas", _poppinsSmallFont]
                ], null);
            }
        } else {
            drawTextStack(dc, width, height, [
                ["Laddar...", _poppinsTinyFont]
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

    /** Spacing above a row: optional 5th element of the row, otherwise the default. */
    function getRowSpacing(textRows, rowIndex, defaultSpacing) {
        if (rowIndex >= textRows.size()) {
            return 0;
        }
        var row = textRows[rowIndex] as Array;
        return row.size() > 4 && row[4] != null ? row[4] : defaultSpacing;
    }

    /** Measure and vertically center a stack of text/font rows and optional logo. */
    function drawTextStack(dc, width, height, textRows, logoResource) {
        var availableTextWidth = width - 16;
        var defaultRowSpacing = 3;
        var logoSpacing = 8;
        var rowHeights = [];
        var contentHeight = 0;

        for (var rowIndex = 0; rowIndex < textRows.size(); rowIndex++) {
            var rowSpacing = rowIndex > 0 ? getRowSpacing(textRows, rowIndex, defaultRowSpacing) : 0;
            if (textRows[rowIndex][0] == null) {
                rowHeights.add(_hourBar.getHeight());
                contentHeight += _hourBar.getHeight() + rowSpacing;
                continue;
            }
            var rowText = textRows[rowIndex][0] as String;
            var rowFont = fitFont(dc, rowText, textRows[rowIndex][1], availableTextWidth);
            rowText = fitText(dc, rowText, rowFont, availableTextWidth);
            textRows[rowIndex][0] = rowText;
            textRows[rowIndex][1] = rowFont;

            var textDimensions = dc.getTextDimensions(rowText, rowFont);
            var rowHeight = textDimensions[1];
            rowHeights.add(rowHeight);
            contentHeight += rowHeight + rowSpacing;
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
            var rowSpacing = getRowSpacing(textRows, rowIndex + 1, defaultRowSpacing);
            var rowHeight = rowHeights[rowIndex];
            var rowCenterY = nextRowTop + rowHeight / 2;
            if (textRows[rowIndex][0] == null) {
                _hourBar.draw(dc, (width * 15 / 100), nextRowTop, width - (width * 15 / 100) * 2, textRows[rowIndex][3] as String);
                nextRowTop += rowHeight + rowSpacing;
                continue;
            }
            dc.setColor((textRows[rowIndex] as Array).size() > 2 ? textRows[rowIndex][2] : Theme.TEXT_PRIMARY, Theme.BACKGROUND);
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
    function fetchPriceData(forceRefresh) {
        _isPriceLoading = true;
        WatchUi.requestUpdate();

        if (forceRefresh) {
            _priceApiClient.refreshCurrentPrice(method(:onPriceDataReceived), _currentPriceResolution);
        } else {
            _priceApiClient.getCurrentPrice(method(:onPriceDataReceived), _currentPriceResolution);
        }
    }

    function getCurrentPriceType() {
        return _currentPriceType;
    }

    function getCurrentPriceResolution() {
        return _currentPriceResolution;
    }

    function getPriceFont() {
        return _poppinsPriceFont;
    }

    function getLargeFont() {
        return _poppinsLargeFont;
    }

    function showSettings() {
        var settingsView = new TibberWidgetSettingsView(self, _poppinsTinyFont, _poppinsSmallFont, _poppinsLargeFont);
        var settingsDelegate = new TibberWidgetSettingsDelegate(settingsView);
        WatchUi.pushView(settingsView, settingsDelegate, WatchUi.SLIDE_UP);
    }

    function setCurrentPriceType(priceType) {
        if (_currentPriceType.equals(priceType)) {
            return;
        }
        _currentPriceType = priceType;
        Storage.setValue("tibber_price_type", priceType);
        refreshDisplayedPrice();
    }

    function setCurrentPriceResolution(priceResolution) {
        if (_currentPriceResolution.equals(priceResolution)) {
            return;
        }
        _currentPriceResolution = priceResolution;
        Storage.setValue("tibber_price_resolution", priceResolution);
        refreshDisplayedPrice();
    }

    private function refreshDisplayedPrice() {
        _currentPriceData = null;
        _priceErrorMessage = null;
        fetchPriceData(false);
    }

    /** Push the graph detail view above the current-price screen. */
    function showPriceGraph(initialPage) {
        var graphView = new TibberPriceGraphView(_poppinsTinyFont, _poppinsSmallFont, _poppinsMediumFont, _currentPriceType, initialPage);
        var graphDelegate = new TibberPriceGraphDelegate(graphView, self);
        WatchUi.pushView(graphView, graphDelegate, WatchUi.SLIDE_UP);
    }

    /** Refresh current-price data from a touch or physical input event. */
    function refreshPriceData() {
        // Public method for refreshing data on button press
        fetchPriceData(true);
    }

    /** Save the result of the asynchronous current-price request. */
    function onPriceDataReceived(responseData) {
        _isPriceLoading = false;

        if (responseData instanceof Dictionary) {
            _currentPriceData = responseData;
            _priceErrorMessage = null;
            cacheGlancePrice(responseData);
        } else if (responseData instanceof String) {
            _priceErrorMessage = responseData;
            _currentPriceData = null;
        } else {
            _priceErrorMessage = "Okänt fel";
            _currentPriceData = null;
        }

        WatchUi.requestUpdate();
    }

    /** Persist the small price fields used by the glance preview. */
    private function cacheGlancePrice(priceData) {
        try {
            Storage.setValue("tibber_glance_ready", false);
            Storage.setValue("tibber_glance_price", priceData.get("current_price"));
            Storage.setValue("tibber_glance_spot_price", priceData.get("current_spot_price"));
            Storage.setValue("tibber_glance_currency", priceData.get("currency"));
            Storage.setValue("tibber_glance_time", priceData.get("current_time"));
            Storage.setValue("tibber_glance_interval", priceData.get("interval_minutes"));
            Storage.setValue("tibber_glance_price_type", _currentPriceType);
            Storage.setValue("tibber_glance_ready", true);
        } catch (ex) {
        }
    }

}