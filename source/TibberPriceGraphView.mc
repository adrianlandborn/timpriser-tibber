import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

class TibberPriceGraphView extends WatchUi.View {
    private var _resolution;
    private var _resolutionCallback;
    private var _apiClient;
    private var _intervals;
    private var _isLoading;
    private var _errorMessage;

    function initialize(resolution, resolutionCallback) {
        View.initialize();
        _resolution = resolution;
        _resolutionCallback = resolutionCallback;
        _apiClient = new TibberApiClient();
        _intervals = null;
        _isLoading = false;
        _errorMessage = null;
    }

    function onShow() {
        fetchDailyPrices();
    }

/**
 * Called when the view needs to be updated.
 * Draws the loading screen, error message, or the price graph.
 */
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        if (_isLoading) {
            drawCenteredText(dc, width, height, "Loading prices...");
        } else if (_errorMessage != null) {
            drawCenteredText(dc, width, height, _errorMessage);
        } else if (_intervals == null || _intervals.size() == 0) {
            drawCenteredText(dc, width, height, "No prices available");
        } else {
            drawGraph(dc, width, height);
        }
    }

/**
 * Draws the price graph for the current intervals.
 * Handles axis scaling, tick marks, and plotting the data points.
 */
    function drawGraph(dc, width, height) {
        var diameter = width < height ? width : height;
        var centerX = width / 2;
        var centerY = height / 2;
        var safeHalfWidth = diameter * 0.40;
        var safeHalfHeight = diameter * 0.29;
        var left = centerX - safeHalfWidth + 17;
        var right = centerX + safeHalfWidth - 5;
        var top = centerY - safeHalfHeight + 8;
        var bottom = centerY + safeHalfHeight - 25;
        var plotWidth = right - left;
        var plotHeight = bottom - top;

        var dataMinimum = _intervals[0].get("price_value");
        var dataMaximum = dataMinimum;
        for (var i = 1; i < _intervals.size(); i++) {
            var value = _intervals[i].get("price_value");
            if (value < dataMinimum) {
                dataMinimum = value;
            }
            if (value > dataMaximum) {
                dataMaximum = value;
            }
        }

        var tickStep = getNiceTickStep((dataMaximum - dataMinimum) / 3);
        var axisMinimum = Math.floor(dataMinimum / tickStep) * tickStep;
        var axisMaximum = Math.ceil(dataMaximum / tickStep) * tickStep;
        if (axisMaximum <= axisMinimum) {
            axisMaximum = axisMinimum + tickStep;
        }
        var axisRange = axisMaximum - axisMinimum;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawLine(left, top, left, bottom);
        dc.drawLine(left, bottom, right, bottom);
        drawAxisLabels(dc, left, right, top, bottom, axisMinimum, axisMaximum, tickStep, axisRange);

        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
        dc.setPenWidth(2);

        var points = [];
        for (var i = 0; i < _intervals.size(); i++) {
            var interval = _intervals[i];
            var minute = interval.get("start_minute_of_day");
            var price = interval.get("price_value");
            if (minute == null || price == null) {
                continue;
            }

            var x = left + minute * plotWidth / 1440;
            var y = bottom - (price - axisMinimum) * plotHeight / axisRange;
            points.add([x, y, minute, interval]);
        }

        for (var i = 0; i < points.size(); i++) {
            var point = points[i];
            var x1 = point[0];
            var y1 = point[1];
            var x2 = right;

            if (i + 1 < points.size()) {
                x2 = points[i + 1][0];
            }

            dc.drawLine(x1, y1, x2, y1);
            if (i + 1 < points.size()) {
                var nextY = points[i + 1][1];
                if (nextY != y1) {
                    dc.drawLine(x2, y1, x2, nextY);
                }
            }
        }

        var currentMinute = getCurrentMinuteOfDay();
        var activePoint = null;
        for (var i = 0; i < points.size(); i++) {
            var startMinute = points[i][2];
            if (startMinute != null && startMinute <= currentMinute) {
                activePoint = points[i];
            }
        }

        if (activePoint != null) {
            var currentX = left + currentMinute * plotWidth / 1440;
            var currentY = activePoint[1];
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
            dc.fillCircle(currentX, currentY, 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawCircle(currentX, currentY, 4);
            drawCurrentIntervalSummary(dc, width, height, activePoint[3]);
        }
    }

/**
 * Draws the summary for the current interval, including price and time range.
 */
    function drawCurrentIntervalSummary(dc, width, height, interval) {
        var price = interval.get("price");
        var currency = interval.get("currency");
        if (price == null || currency == null) {
            return;
        }

        var unit = currency.equals("SEK") ? "öre" : currency;
        var priceFont = Graphics.FONT_LARGE;
        var unitFont = Graphics.FONT_SMALL;
        var availableWidth = width - 20;
        var priceWidth = dc.getTextWidthInPixels(price, priceFont);
        var unitWidth = dc.getTextWidthInPixels(unit, unitFont);
        if (priceWidth + unitWidth + 6 > availableWidth) {
            priceFont = Graphics.FONT_MEDIUM;
            priceWidth = dc.getTextWidthInPixels(price, priceFont);
        }
        if (priceWidth + unitWidth + 6 > availableWidth) {
            priceFont = Graphics.FONT_SMALL;
            unitFont = Graphics.FONT_XTINY;
            priceWidth = dc.getTextWidthInPixels(price, priceFont);
            unitWidth = dc.getTextWidthInPixels(unit, unitFont);
        }

        var startX = (width - priceWidth - unitWidth - 6) / 2;
        var valueY = height - 45;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(startX, valueY, priceFont, price, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + priceWidth + 6, valueY + 3, unitFont, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var startMinute = interval.get("start_minute_of_day");
        var duration = interval.get("duration_minutes");
        var startTime = interval.get("start_time");
        if (startMinute == null || duration == null || startTime == null) {
            return;
        }

        var endMinute = (startMinute + duration) % 1440;
        var endTime = (endMinute / 60).format("%02d") + ":" + (endMinute % 60).format("%02d");
        var timeRange = startTime + "-" + endTime;
        dc.drawText(width / 2, height - 20, Graphics.FONT_XTINY, timeRange, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function getCurrentMinuteOfDay() {
        var timeInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return timeInfo.hour * 60 + timeInfo.min;
    }

    function getNiceTickStep(rawStep) {
        if (rawStep <= 0) {
            return 1;
        }

        var magnitude = 1.0;
        while (rawStep >= magnitude * 10) {
            magnitude *= 10;
        }
        while (rawStep < magnitude) {
            magnitude /= 10;
        }

        var normalized = rawStep / magnitude;
        if (normalized <= 1) {
            return magnitude;
        } else if (normalized <= 2) {
            return 2 * magnitude;
        } else if (normalized <= 5) {
            return 5 * magnitude;
        }
        return 10 * magnitude;
    }

    function drawAxisLabels(dc, left, right, top, bottom, minimum, maximum, tickStep, range) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        var format = tickStep < 1 ? "%.2f" : "%.0f";
        var value = minimum;
        var tickCount = 0;
        while (value <= maximum + tickStep * 0.001 && tickCount < 6) {
            var y = bottom - (value - minimum) * (bottom - top) / range;
            dc.drawText(left - 3, y, Graphics.FONT_XTINY, value.format(format), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            value += tickStep;
            tickCount++;
        }

        var labelHours = [6, 12, 18];
        var labels = ["06", "12", "18"];
        for (var i = 0; i < labels.size(); i++) {
            var x = left + (right - left) * labelHours[i] / 24;
            dc.drawText(x, bottom + 2, Graphics.FONT_XTINY, labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawCenteredText(dc, width, height, text) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function fetchDailyPrices() {
        _isLoading = true;
        _errorMessage = null;
        WatchUi.requestUpdate();
        _apiClient.getDailyPrices(method(:onDailyPricesReceived), _resolution);
    }

    function onDailyPricesReceived(response) {
        _isLoading = false;
        if (response instanceof Dictionary) {
            var intervals = response.get("intervals");
            if (intervals instanceof Array) {
                _intervals = intervals;
                _errorMessage = null;
            } else {
                _intervals = null;
                _errorMessage = "Invalid price data";
            }
        } else if (response instanceof String) {
            _intervals = null;
            _errorMessage = response as String;
        } else {
            _intervals = null;
            _errorMessage = "Unable to load prices";
        }
        WatchUi.requestUpdate();
    }

    function refreshPriceData() {
        fetchDailyPrices();
    }

    function togglePriceResolution() {
        _resolution = _resolution.equals("HOURLY") ? "QUARTER_HOURLY" : "HOURLY";
        if (_resolutionCallback != null) {
            _resolutionCallback.invoke(_resolution);
        }
        fetchDailyPrices();
    }
}