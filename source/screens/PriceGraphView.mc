import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class TibberPriceGraphView extends WatchUi.View {
    private var _apiClient;
    private var _chart;
    private var _selectedPage;
    private var _priceIntervals;
    private var _chartSpanMinutes;
    private var _intervalDurationMinutes;
    private var _currency;
    private var _priceType;
    private var _hasTomorrowPrices;
    private var _isLoading;
    private var _errorMessage;
    private var _poppinsSmallFont;
    private var _poppinsTinyFont;

    /** Create the graph page controller and its reusable chart renderer. */
    function initialize(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont, priceType, initialPage) {
        View.initialize();
        _apiClient = new TibberApiClient();
        _poppinsSmallFont = poppinsSmallFont;
        _poppinsTinyFont = poppinsTinyFont;
        _chart = new TibberPriceChart(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont);
        _selectedPage = initialPage;
        _priceIntervals = null;
        _chartSpanMinutes = 1440;
        _intervalDurationMinutes = 15;
        _currency = null;
        _priceType = priceType;
        _hasTomorrowPrices = false;
        _isLoading = false;
        _errorMessage = null;
    }

    /** Fetch graph data when the detail page becomes visible. */
    /** Load the selected page when the graph view becomes visible. */
    function onShow() {
        var storedPriceType = Storage.getValue("tibber_price_type");
        if (storedPriceType instanceof String) {
            _priceType = storedPriceType;
        }
        fetchGraphPrices(false);
    }

    /** Draw the current loading, error, empty, or chart state. */
    function onUpdate(deviceContext) {
        deviceContext.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        deviceContext.clear();

        var displayWidth = deviceContext.getWidth();
        var displayHeight = deviceContext.getHeight();
        if (_isLoading) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, "Laddar priser...");
        } else if (_errorMessage != null) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, _errorMessage);
        } else if (_priceIntervals == null || _priceIntervals.size() == 0) {
            drawCenteredText(deviceContext, displayWidth, displayHeight, "Priser saknas");
        } else {
            _chart.draw(deviceContext, _priceIntervals, _chartSpanMinutes, _intervalDurationMinutes, _currency, getPageTitle(), getPageNote());
        }
    }

    /** Return the display title for the selected graph page. */
    function getPageTitle() {
        var title;
        if (_selectedPage == 0) {
            title = "IDAG | 15 MIN";
        } else if (_hasTomorrowPrices) {
            title = "2 DAGAR | TIMPRIS";
        } else {
            title = "IDAG | TIMPRIS";
        }
        return title;
    }

    /** Return a note when hourly tomorrow prices have not been published. */
    function getPageNote() {
        if (_selectedPage == 1 && !_hasTomorrowPrices) {
            return "Imorgon saknas";
        }
        return null;
    }

    /** Fetch today's prices, optionally including tomorrow on the hourly page. */
    function fetchGraphPrices(forceRefresh) {
        _isLoading = true;
        _errorMessage = null;
        WatchUi.requestUpdate();

        var priceResolution = _selectedPage == 0 ? "QUARTER_HOURLY" : "HOURLY";
        var includeTomorrow = _selectedPage == 1;
        if (forceRefresh) {
            _apiClient.refreshDailyPrices(method(:onPricesReceived), priceResolution, includeTomorrow);
        } else {
            _apiClient.getDailyPrices(method(:onPricesReceived), priceResolution, includeTomorrow);
        }
    }

    /** Save a successful interval response or display its error state. */
    function onPricesReceived(apiResponse) {
        _isLoading = false;
        if (apiResponse instanceof Dictionary) {
            var sourceIntervals = apiResponse.get("intervals");
            var chartSpanMinutes = apiResponse.get("span_minutes");
            if (sourceIntervals instanceof Array && chartSpanMinutes != null) {
                _priceIntervals = [];
                var selectedPriceIndex = _priceType.equals("SPOT") ? 2 : 1;
                var includeNetworkFees = _priceType.equals("TOTAL") && Storage.getValue("tibber_network_fees_enabled") == true;
                var priceCalculator = new TibberPriceCache();
                var hourlySpotTotals = [];
                var hourlySpotCounts = [];

                if (includeNetworkFees) {
                    buildHourlySpotAverages(sourceIntervals as Array, hourlySpotTotals, hourlySpotCounts);
                }

                for (var intervalIndex = 0; intervalIndex < (sourceIntervals as Array).size(); intervalIndex++) {
                    var sourceInterval = (sourceIntervals as Array)[intervalIndex];
                    if (sourceInterval instanceof Array && (sourceInterval as Array).size() > selectedPriceIndex) {
                        var plotMinute = (sourceInterval as Array)[0];
                        var displayPrice = (sourceInterval as Array)[selectedPriceIndex] as Float;
                        if (includeNetworkFees) {
                            var hourBucket = plotMinute / 60;
                            var spotAverage = (hourlySpotTotals as Array)[hourBucket] / (hourlySpotCounts as Array)[hourBucket];
                            displayPrice = priceCalculator.getPriceWithNetworkFees(displayPrice, spotAverage);
                        }
                        _priceIntervals.add([plotMinute, displayPrice]);
                    }
                }
                _chartSpanMinutes = chartSpanMinutes;
                _intervalDurationMinutes = apiResponse.get("resolution_minutes");
                _currency = apiResponse.get("currency");
                _hasTomorrowPrices = apiResponse.get("tomorrow_available") == true;
                _errorMessage = null;
            } else {
                _priceIntervals = null;
                _errorMessage = "Ogiltiga prisdata";
            }
        } else if (apiResponse instanceof String) {
            _priceIntervals = null;
            _errorMessage = apiResponse as String;
        } else {
            _priceIntervals = null;
            _errorMessage = "Kunde inte läsa priser";
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

    function getSelectedPage() {
        return _selectedPage;
    }

    private function buildHourlySpotAverages(sourceIntervals, hourlySpotTotals, hourlySpotCounts) {
        for (var intervalIndex = 0; intervalIndex < sourceIntervals.size(); intervalIndex++) {
            var interval = sourceIntervals[intervalIndex];
            if (!(interval instanceof Array) || (interval as Array).size() < 3) {
                continue;
            }

            var plotMinute = (interval as Array)[0];
            var hourBucket = 0;
            while ((hourBucket + 1) * 60 <= plotMinute) {
                hourBucket++;
            }
            while (hourlySpotTotals.size() <= hourBucket) {
                hourlySpotTotals.add(0.0);
                hourlySpotCounts.add(0);
            }
            hourlySpotTotals[hourBucket] = hourlySpotTotals[hourBucket] + ((interval as Array)[2] as Float);
            hourlySpotCounts[hourBucket] = hourlySpotCounts[hourBucket] + 1;
        }
    }

    /** Change pages and request fresh data unless that request is already active. */
    private function setPage(pageIndex) {
        if (_isLoading || (pageIndex == _selectedPage && _priceIntervals != null)) {
            return;
        }
        _selectedPage = pageIndex;
        _priceIntervals = null;
        fetchGraphPrices(false);
    }

    /** Refresh the selected page's prices. */
    function refreshPriceData() {
        fetchGraphPrices(true);
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
