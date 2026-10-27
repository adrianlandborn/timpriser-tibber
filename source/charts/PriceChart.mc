import Toybox.Graphics;
import Toybox.Math;
import Toybox.Time;

/**
 * Reusable price-series renderer for timestamped hourly or quarter-hour data.
 * Prices are scaled from raw values; axis bounds are rounded only for ticks.
 */
class TibberPriceChart {
    private var _poppinsTinyFont;
    private var _poppinsSmallFont;
    private var _poppinsMediumFont;
    private var _levelColors;

    /** Use font resources supplied by the parent graph view. */
    function initialize(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont) {
        _poppinsTinyFont = poppinsTinyFont;
        _poppinsSmallFont = poppinsSmallFont;
        _poppinsMediumFont = poppinsMediumFont;
        _levelColors = new HourLevelBar();
    }

    /**
     * Draw a step series within the supplied time span.
     *
      * @param deviceContext Device context for the current view update.
    * @param priceIntervals Compact [plot minute, price value, level code] triples.
      * @param chartSpanMinutes Horizontal range in minutes, normally 1440 or 2880.
    * @param intervalDurationMinutes The interval length, normally 15 or 60.
    * @param currency Currency for the active interval footer.
      * @param chartTitle Page title shown above the plot.
      * @param statusNote Optional availability note shown below the title.
     */
    function draw(deviceContext, priceIntervals, chartSpanMinutes, intervalDurationMinutes, currency, chartTitle, statusNote) {
        if (priceIntervals == null || priceIntervals.size() == 0) {
            return;
        }

        var displayWidth = deviceContext.getWidth();
        var displayHeight = deviceContext.getHeight();
        var diameter = displayWidth < displayHeight ? displayWidth : displayHeight;
        var centerX = displayWidth / 2;
        var centerY = displayHeight / 2;
        var safeHalfWidth = diameter * 0.40;
        var safeHalfHeight = diameter * 0.29;
        var plotLeft = centerX - safeHalfWidth + 17;
        var plotRight = centerX + safeHalfWidth - 5;
        var plotTop = centerY - safeHalfHeight + (statusNote == null ? 8 : 16);
        var plotBottom = centerY + safeHalfHeight - 25;
        var plotWidth = plotRight - plotLeft;
        var plotHeight = plotBottom - plotTop;

        var minimumPrice = priceIntervals[0][1];
        var maximumPrice = minimumPrice;
        var priceTotal = priceIntervals[0][1];
        for (var intervalIndex = 1; intervalIndex < priceIntervals.size(); intervalIndex++) {
            var intervalPrice = priceIntervals[intervalIndex][1];
            priceTotal += intervalPrice;
            if (intervalPrice < minimumPrice) {
                minimumPrice = intervalPrice;
            }
            if (intervalPrice > maximumPrice) {
                maximumPrice = intervalPrice;
            }
        }

        var yAxisTickStep = getNiceTickStep((maximumPrice - minimumPrice) / 3);
        var yAxisMinimum = Math.floor(minimumPrice / yAxisTickStep) * yAxisTickStep;
        var yAxisMaximum = Math.ceil(maximumPrice / yAxisTickStep) * yAxisTickStep;
        if (yAxisMaximum <= yAxisMinimum) {
            yAxisMaximum = yAxisMinimum + yAxisTickStep;
        }
        var yAxisRange = yAxisMaximum - yAxisMinimum;

        deviceContext.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        deviceContext.drawText(centerX, centerY - safeHalfHeight - 35, _poppinsSmallFont, chartTitle, Graphics.TEXT_JUSTIFY_CENTER);
        if (statusNote != null) {
            deviceContext.setColor(Theme.TEXT_SECONDARY, Theme.BACKGROUND);
            deviceContext.drawText(centerX, centerY - safeHalfHeight - 10, _poppinsTinyFont, statusNote, Graphics.TEXT_JUSTIFY_CENTER);
        }

        deviceContext.setColor(Theme.CHART_AXIS, Theme.BACKGROUND);
        deviceContext.drawLine(plotLeft, plotTop, plotLeft, plotBottom);
        deviceContext.drawLine(plotLeft, plotBottom, plotRight, plotBottom);
        drawAxes(deviceContext, plotLeft, plotRight, plotTop, plotBottom, yAxisMinimum, yAxisTickStep, yAxisRange, chartSpanMinutes);

        var graphPoints = [];
        for (var intervalIndex = 0; intervalIndex < priceIntervals.size(); intervalIndex++) {
            var priceInterval = priceIntervals[intervalIndex];
            var plotMinute = priceInterval[0];
            var intervalPrice = priceInterval[1];

            var pointX = plotLeft + plotMinute * plotWidth / chartSpanMinutes;
            var pointY = plotBottom - (intervalPrice - yAxisMinimum) * plotHeight / yAxisRange;
            var levelCode = priceInterval.size() > 2 ? priceInterval[2] : 0;
            graphPoints.add([pointX, pointY, plotMinute, intervalPrice, levelCode]);
        }

        var averageY = plotBottom - (priceTotal / priceIntervals.size() - yAxisMinimum) * plotHeight / yAxisRange;
        drawAverageLine(deviceContext, plotLeft, plotRight, averageY);

        deviceContext.setPenWidth(2);
        drawStepSeries(deviceContext, graphPoints, plotRight);
        drawCurrentMarker(deviceContext, graphPoints, plotLeft, plotWidth, chartSpanMinutes, intervalDurationMinutes, currency);
    }

    /** Draw a dashed horizontal line at the average price. */
    private function drawAverageLine(deviceContext, plotLeft, plotRight, averageY) {
        deviceContext.setColor(Theme.CHART_AVERAGE, Theme.BACKGROUND);
        for (var dashX = plotLeft; dashX < plotRight; dashX += 8) {
            var dashEnd = dashX + 4 < plotRight ? dashX + 4 : plotRight;
            deviceContext.drawLine(dashX, averageY, dashEnd, averageY);
        }
    }

    /** Draw each price as a flat interval followed by a vertical step. */
    private function drawStepSeries(deviceContext, graphPoints, plotRight) {
        for (var pointIndex = 0; pointIndex < graphPoints.size(); pointIndex++) {
            var currentPoint = graphPoints[pointIndex];
            deviceContext.setColor(currentPoint[4] > 0 ? _levelColors.getColorForCode(currentPoint[4]) : Theme.CHART_DEFAULT_LINE, Theme.BACKGROUND);
            var nextPointX = plotRight;
            if (pointIndex + 1 < graphPoints.size()) {
                nextPointX = graphPoints[pointIndex + 1][0];
            }
            deviceContext.drawLine(currentPoint[0], currentPoint[1], nextPointX, currentPoint[1]);

            if (pointIndex + 1 < graphPoints.size()) {
                var nextPointY = graphPoints[pointIndex + 1][1];
                if (nextPointY != currentPoint[1]) {
                    deviceContext.drawLine(nextPointX, currentPoint[1], nextPointX, nextPointY);
                }
            }
        }
    }

    /** Highlight the active interval at the center of its time span. */
    private function drawCurrentMarker(deviceContext, graphPoints, plotLeft, plotWidth, chartSpanMinutes, intervalDurationMinutes, currency) {
        var localTime = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentMinuteOfDay = localTime.hour * 60 + localTime.min;
        if (currentMinuteOfDay >= chartSpanMinutes) {
            return;
        }

        var activeGraphPoint = null;
        for (var pointIndex = 0; pointIndex < graphPoints.size(); pointIndex++) {
            if (graphPoints[pointIndex][2] <= currentMinuteOfDay) {
                activeGraphPoint = graphPoints[pointIndex];
            }
        }
        if (activeGraphPoint == null) {
            return;
        }

        if (intervalDurationMinutes == null) {
            return;
        }
        var intervalCenterMinute = activeGraphPoint[2] + intervalDurationMinutes / 2;
        var markerX = plotLeft + intervalCenterMinute * plotWidth / chartSpanMinutes;
        var markerY = activeGraphPoint[1];
        deviceContext.setColor(Theme.CHART_MARKER, Theme.BACKGROUND);
        deviceContext.fillCircle(markerX, markerY, 5);
        deviceContext.setColor(Theme.CHART_MARKER_OUTLINE, Theme.BACKGROUND);
        deviceContext.drawCircle(markerX, markerY, 5);
        drawCurrentIntervalFooter(deviceContext, activeGraphPoint, intervalDurationMinutes, currency);
    }

    /** Draw the active interval's price, unit, and start/end time below the plot. */
    private function drawCurrentIntervalFooter(deviceContext, activeGraphPoint, intervalDurationMinutes, currency) {
        var formattedPrice = activeGraphPoint[3].format("%.0f");
        if (formattedPrice == null || currency == null) {
            return;
        }

        var priceUnit = currency.equals("SEK") ? "öre" : currency;
        var priceFont = _poppinsMediumFont;
        var unitFont = _poppinsTinyFont;
        var availableWidth = deviceContext.getWidth() - 20;
        var priceWidth = deviceContext.getTextWidthInPixels(formattedPrice, priceFont);
        var unitWidth = deviceContext.getTextWidthInPixels(priceUnit, unitFont);
        if (priceWidth + unitWidth + 6 > availableWidth) {
            priceFont = _poppinsSmallFont;
            priceWidth = deviceContext.getTextWidthInPixels(formattedPrice, priceFont);
        }
        if (priceWidth + unitWidth + 6 > availableWidth) {
            priceFont = _poppinsTinyFont;
            priceWidth = deviceContext.getTextWidthInPixels(formattedPrice, priceFont);
            unitWidth = deviceContext.getTextWidthInPixels(priceUnit, unitFont);
        }

        var footerStartX = (deviceContext.getWidth() - priceWidth - unitWidth - 6) / 2;
        var priceCenterY = deviceContext.getHeight() - 45;
        deviceContext.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        deviceContext.drawText(footerStartX, priceCenterY, priceFont, formattedPrice, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        deviceContext.drawText(footerStartX + priceWidth + 6, priceCenterY + 3, unitFont, priceUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var intervalStartMinute = activeGraphPoint[2] % 1440;
        var intervalEndMinute = (intervalStartMinute + intervalDurationMinutes) % 1440;
        var intervalStartTime = (intervalStartMinute / 60).format("%02d") + ":" + (intervalStartMinute % 60).format("%02d");
        var intervalEndTime = (intervalEndMinute / 60).format("%02d") + ":" + (intervalEndMinute % 60).format("%02d");
        deviceContext.drawText(deviceContext.getWidth() / 2, deviceContext.getHeight() - 20, _poppinsTinyFont, intervalStartTime + "-" + intervalEndTime, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /** Draw rounded Y ticks and sparse hour labels over a 24- or 48-hour span. */
    private function drawAxes(deviceContext, plotLeft, plotRight, plotTop, plotBottom, axisMinimum, yAxisTickStep, yAxisRange, chartSpanMinutes) {
        deviceContext.setColor(Theme.CHART_AXIS, Theme.BACKGROUND);
        var labelFormat = yAxisTickStep < 1 ? "%.2f" : "%.0f";
        var tickValue = axisMinimum;
        var tickCount = 0;
        while (tickValue <= axisMinimum + yAxisRange + yAxisTickStep * 0.001 && tickCount < 6) {
            var tickY = plotBottom - (tickValue - axisMinimum) * (plotBottom - plotTop) / yAxisRange;
            deviceContext.drawText(plotLeft - 3, tickY, _poppinsTinyFont, tickValue.format(labelFormat), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            tickValue += yAxisTickStep;
            tickCount++;
        }

        var hourLabelOffsets;
        var hourLabels;
        if (chartSpanMinutes > 1440) {
            hourLabelOffsets = [6, 12, 18, 24, 30, 36, 42];
            hourLabels = ["06", "12", "18", "00", "06", "12", "18"];
        } else {
            hourLabelOffsets = [6, 12, 18];
            hourLabels = ["06", "12", "18"];
        }
        for (var labelIndex = 0; labelIndex < hourLabels.size(); labelIndex++) {
            var labelX = plotLeft + (plotRight - plotLeft) * hourLabelOffsets[labelIndex] / (chartSpanMinutes / 60);
            deviceContext.drawText(labelX, plotBottom + 2, _poppinsTinyFont, hourLabels[labelIndex], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    /** Choose a readable 1/2/5 × 10^n interval for the Y-axis. */
    private function getNiceTickStep(rawTickStep) {
        if (rawTickStep <= 0) {
            return 1;
        }

        var tickMagnitude = 1.0;
        while (rawTickStep >= tickMagnitude * 10) {
            tickMagnitude *= 10;
        }
        while (rawTickStep < tickMagnitude) {
            tickMagnitude /= 10;
        }

        var normalizedStep = rawTickStep / tickMagnitude;
        if (normalizedStep <= 1) {
            return tickMagnitude;
        } else if (normalizedStep <= 2) {
            return 2 * tickMagnitude;
        } else if (normalizedStep <= 5) {
            return 5 * tickMagnitude;
        }
        return 10 * tickMagnitude;
    }
}
