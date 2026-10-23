import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberPriceGraphView extends WatchUi.View {
    private var _apiClient;
    private var _chart;
    private var _selectedPage;
    private var _priceIntervals;
    private var _chartSpanMinutes;
    private var _intervalDurationMinutes;
    private var _currency;
    private var _hasTomorrowPrices;
    private var _isLoading;
    private var _errorMessage;
    private var _poppinsSmallFont;
    private var _poppinsTinyFont;

    /** Create the graph page controller and its reusable chart renderer. */
    function initialize(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont) {
        View.initialize();
        _apiClient = new TibberApiClient();
        _poppinsSmallFont = poppinsSmallFont;
        _poppinsTinyFont = poppinsTinyFont;
        _chart = new TibberPriceChart(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont);
        _selectedPage = 0;
        _priceIntervals = null;
        _chartSpanMinutes = 1440;
        _intervalDurationMinutes = 15;
        _currency = null;
        _hasTomorrowPrices = false;
        _isLoading = false;
        _errorMessage = null;
    }

    /** Fetch graph data when the detail page becomes visible. */
    /** Load the selected page when the graph view becomes visible. */
    function onShow() {
        fetchGraphPrices();
    }

    /** Draw the current loading, error, empty, or chart state. */
    function onUpdate(deviceContext) {
        deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        deviceContext.clear();

        var displayWidth = deviceContext.getWidth();
        var displayHeight = deviceContext.getHeight();
        if (_isLoading) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, "Loading prices...");
        } else if (_errorMessage != null) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, _errorMessage);
        } else if (_priceIntervals == null || _priceIntervals.size() == 0) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, "No prices available");
        } else {
            _chart.draw(deviceContext, _priceIntervals, _chartSpanMinutes, _intervalDurationMinutes, _currency, getPageTitle(), getPageNote());
        }
    }

    /** Return the display title for the selected graph page. */
    function getPageTitle() {
        if (_selectedPage == 0) {
            return "TODAY / 15 MIN";
        }
        if (_hasTomorrowPrices) {
            return "2 DAYS / HOURLY";
        }
        return "TODAY / HOURLY";
    }

    /** Return a note when hourly tomorrow prices have not been published. */
    function getPageNote() {
        if (_selectedPage == 1 && !_hasTomorrowPrices) {
            return "Tomorrow not available";
        }
        return null;
    }

    /** Fetch today's prices, optionally including tomorrow on the hourly page. */
    function fetchGraphPrices() {
        _isLoading = true;
        _errorMessage = null;
        WatchUi.requestUpdate();

        var priceResolution = _selectedPage == 0 ? "QUARTER_HOURLY" : "HOURLY";
        var includeTomorrow = _selectedPage == 1;
        _apiClient.getDailyPrices(method(:onPricesReceived), priceResolution, includeTomorrow);
    }

    /** Save a successful interval response or display its error state. */
    function onPricesReceived(apiResponse) {
        _isLoading = false;
        if (apiResponse instanceof Dictionary) {
            var dailyPriceIntervals = apiResponse.get("intervals");
            var chartSpanMinutes = apiResponse.get("span_minutes");
            if (dailyPriceIntervals instanceof Array && chartSpanMinutes != null) {
                _priceIntervals = dailyPriceIntervals;
                _chartSpanMinutes = chartSpanMinutes;
                _intervalDurationMinutes = apiResponse.get("resolution_minutes");
                _currency = apiResponse.get("currency");
                _hasTomorrowPrices = apiResponse.get("tomorrow_available") == true;
                _errorMessage = null;
            } else {
                _priceIntervals = null;
                _errorMessage = "Invalid price data";
            }
        } else if (apiResponse instanceof String) {
            _priceIntervals = null;
            _errorMessage = apiResponse as String;
        } else {
            _priceIntervals = null;
            _errorMessage = "Unable to load prices";
        }
        WatchUi.requestUpdate();
    }

    /** Show today's quarter-hour prices. */
    function showQuarterHourlyPage() {
        setPage(0);
    }

    /** Show hourly prices for today and tomorrow when tomorrow is available. */
    function showHourlyPage() {
        setPage(1);
    }

    /** Change pages and request fresh data unless that request is already active. */
    private function setPage(pageIndex) {
        if (_isLoading || (pageIndex == _selectedPage && _priceIntervals != null)) {
            return;
        }
        _selectedPage = pageIndex;
        _priceIntervals = null;
        fetchGraphPrices();
    }

    /** Refresh the selected page's prices. */
    function refreshPriceData() {
        fetchGraphPrices();
    }

    /** Center a short loading/error message in the watch display. */
    function drawCenteredText(deviceContext, displayWidth, displayHeight, message) {
        deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        var selectedFont = _poppinsSmallFont;
        var availableWidth = displayWidth - 16;
        if (deviceContext.getTextWidthInPixels(message, selectedFont) > availableWidth) {
            selectedFont = _poppinsTinyFont;
        }
        while (message.length() > 0 && deviceContext.getTextWidthInPixels(message, selectedFont) > availableWidth) {
            message = message.substring(0, message.length() - 1);
        }
        deviceContext.drawText(displayWidth / 2, displayHeight / 2, selectedFont, message, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
