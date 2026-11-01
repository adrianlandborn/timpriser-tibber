import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

/**
 * Reusable price-series renderer for timestamped hourly or quarter-hour data.
 * Prices are scaled from raw values; axis bounds are rounded only for ticks.
 */
class TibberPriceChart {
    private const MINUTES_PER_HOUR = 60;
    private const MINUTES_PER_DAY = 1440;

    private const HALF_WIDTH_RATIO = 0.40;
    private const HALF_HEIGHT_RATIO = 0.29;
    private const PLOT_RIGHT_INSET = 5;
    private const PLOT_TOP_INSET = 8;
    private const PLOT_TOP_WITH_NOTE_INSET = 16;
    private const PLOT_BOTTOM_INSET = 25;
    private const TITLE_OFFSET = 35;
    private const STATUS_NOTE_OFFSET = 10;
    private const Y_LABEL_RESERVE = 6;
    private const Y_LABEL_GAP = 3;
    private const X_LABEL_GAP = 2;

    private const TARGET_TICK_INTERVALS = 3;
    private const MAX_Y_TICKS = 6;
    private const TICK_TOLERANCE = 0.001;

    private const AVERAGE_DASH_LENGTH = 4;
    private const AVERAGE_DASH_STRIDE = 8;
    private const SERIES_LINE_WIDTH = 2;
    private const MARKER_RADIUS = 5;

    private const FOOTER_SIDE_INSET = 10;
    private const FOOTER_BOTTOM_RATIO = 0.06;
    private const FOOTER_UNIT_GAP = 6;
    private const FOOTER_ROW_GAP = 2;
    private const FOOTER_CLEARANCE = 12;

    // Intervals are [minute, price, optional level]; projected points retain
    // that data after their [x, y] coordinates to avoid per-point dictionaries.
    private const POINT_X = 0;
    private const POINT_Y = 1;
    private const POINT_MINUTE = 2;
    private const POINT_PRICE = 3;
    private const POINT_LEVEL = 4;

    private var _poppinsTinyFont;
    private var _poppinsSmallFont;
    private var _poppinsMediumFont;
    private var _levelColors;
    private var _priceCache;

    /**
     * Use font resources supplied by the parent graph view.
     * @param poppinsTinyFont Font for axis labels, units, notes, and footer time.
     * @param poppinsSmallFont Font for the title and first price-size fallback.
     * @param poppinsMediumFont Preferred font for the footer price.
     */
    function initialize(poppinsTinyFont, poppinsSmallFont, poppinsMediumFont) {
        _poppinsTinyFont = poppinsTinyFont;
        _poppinsSmallFont = poppinsSmallFont;
        _poppinsMediumFont = poppinsMediumFont;
        _levelColors = new TibberHourLevelBar();
        _priceCache = new TibberPriceCache();
    }

    /**
     * Draw a step series within the supplied time span.
     *
     * @param deviceContext Device context for the current view update.
     * Null or empty interval data produces no drawing.
     *
     * @param priceIntervals Chronologically ordered [minute, price, optional level] arrays.
     * @param chartSpanMinutes Positive horizontal range from today's midnight, normally 1440 or 2880.
     * @param intervalDurationMinutes Interval length, normally 15 or 60; null hides marker and footer.
     * @param currency Currency code; null hides the footer but not the marker.
     * @param chartTitle Page title shown above the plot.
     * @param statusNote Optional availability note shown below the title.
     */
    function draw(deviceContext, priceIntervals, chartSpanMinutes, intervalDurationMinutes, currency, chartTitle, statusNote) {
        if (priceIntervals == null || priceIntervals.size() == 0) {
            return;
        }

        var scale = calculatePriceScale(priceIntervals);
        var layout = calculateLayout(deviceContext, scale[:ticks], statusNote);
        var graphPoints = projectIntervals(priceIntervals, chartSpanMinutes, layout, scale);

        drawHeader(deviceContext, layout, chartTitle, statusNote);
        drawAxes(deviceContext, layout, scale, chartSpanMinutes);

        var averageY = layout[:bottom] - (scale[:average] - scale[:minimum]) * layout[:height] / scale[:range];
        drawAverageLine(deviceContext, layout[:left], layout[:right], averageY);
        deviceContext.setPenWidth(SERIES_LINE_WIDTH);
        drawStepSeries(deviceContext, graphPoints, layout[:right]);
        drawCurrentMarker(deviceContext, graphPoints, layout, chartSpanMinutes, intervalDurationMinutes, currency);
    }

    /**
     * Round price bounds outward to readable ticks, including a nonzero range
     * for a constant-price series. The average uses unrounded interval prices.
     * @param priceIntervals Nonempty interval arrays with price at index 1.
     * @return Dictionary with :minimum, :range, :average, and :ticks;
     *         each tick is [numeric value, formatted label].
     */
    private function calculatePriceScale(priceIntervals) {
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

        var yAxisTickStep = getNiceTickStep((maximumPrice - minimumPrice) / TARGET_TICK_INTERVALS);
        var yAxisMinimum = Math.floor(minimumPrice / yAxisTickStep) * yAxisTickStep;
        var yAxisMaximum = Math.ceil(maximumPrice / yAxisTickStep) * yAxisTickStep;
        if (yAxisMaximum <= yAxisMinimum) {
            yAxisMaximum = yAxisMinimum + yAxisTickStep;
        }
        // Share the formatted ticks between measurement and rendering so the
        // reserved label width always matches the labels actually drawn.
        var labelFormat = yAxisTickStep < 1 ? "%.2f" : "%.0f";
        var ticks = [];
        var tickValue = yAxisMinimum;
        // Include the upper tick despite floating-point accumulation errors.
        while (tickValue <= yAxisMaximum + yAxisTickStep * TICK_TOLERANCE && ticks.size() < MAX_Y_TICKS) {
            ticks.add([tickValue, tickValue.format(labelFormat)]);
            tickValue += yAxisTickStep;
        }
        return {
            :minimum => yAxisMinimum,
            :range => yAxisMaximum - yAxisMinimum,
            :average => priceTotal / priceIntervals.size(),
            :ticks => ticks
        };
    }

    /**
     * Get the limiting display dimension used for proportional insets.
     * @param deviceContext Drawing surface providing width and height in pixels.
     * @return Smaller of the surface width and height.
     */
    private function getDisplayDiameter(deviceContext) {
        var width = deviceContext.getWidth();
        var height = deviceContext.getHeight();
        return width < height ? width : height;
    }

    /**
     * Measure Y labels and reserve header and footer space around the plot.
     * @param deviceContext Drawing surface used for dimensions and font metrics.
     * @param ticks [Numeric value, formatted label] pairs from calculatePriceScale().
     * @param statusNote Optional note; a non-null value lowers the plot top.
     * @return Pixel geometry keyed by :centerX, :titleY, :noteY, :left,
     *         :right, :top, :bottom, :width, and :height.
     */
    private function calculateLayout(deviceContext, ticks, statusNote) {
        var diameter = getDisplayDiameter(deviceContext);
        var centerX = deviceContext.getWidth() / 2;
        var centerY = deviceContext.getHeight() / 2;
        var safeHalfWidth = diameter * HALF_WIDTH_RATIO;
        var safeHalfHeight = diameter * HALF_HEIGHT_RATIO;
        var widestLabel = 0;
        for (var index = 0; index < ticks.size(); index++) {
            var labelWidth = deviceContext.getTextWidthInPixels(ticks[index][1], _poppinsTinyFont);
            if (labelWidth > widestLabel) {
                widestLabel = labelWidth;
            }
        }
        var plotLeft = centerX - safeHalfWidth + widestLabel + Y_LABEL_RESERVE;
        var plotRight = centerX + safeHalfWidth - PLOT_RIGHT_INSET;
        var plotTop = centerY - safeHalfHeight + (statusNote == null ? PLOT_TOP_INSET : PLOT_TOP_WITH_NOTE_INSET);
        var plotBottom = centerY + safeHalfHeight - PLOT_BOTTOM_INSET;
        // Reserve the largest footer font even if a long price later falls
        // back to a smaller one, keeping the plot stable between intervals.
        var footerSpace = deviceContext.getFontHeight(_poppinsMediumFont)
            + deviceContext.getFontHeight(_poppinsTinyFont) * 2
            + FOOTER_CLEARANCE + diameter * FOOTER_BOTTOM_RATIO;
        if (plotBottom > deviceContext.getHeight() - footerSpace) {
            plotBottom = deviceContext.getHeight() - footerSpace;
        }
        return {
            :centerX => centerX,
            :titleY => centerY - safeHalfHeight - TITLE_OFFSET,
            :noteY => centerY - safeHalfHeight - STATUS_NOTE_OFFSET,
            :left => plotLeft,
            :right => plotRight,
            :top => plotTop,
            :bottom => plotBottom,
            :width => plotRight - plotLeft,
            :height => plotBottom - plotTop
        };
    }

    /**
     * Draw the centered title and optional secondary note.
     * @param deviceContext Target drawing surface.
     * @param layout Geometry returned by calculateLayout().
     * @param chartTitle Title text above the plot.
     * @param statusNote Secondary text, or null to omit it.
     */
    private function drawHeader(deviceContext, layout, chartTitle, statusNote) {
        deviceContext.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        deviceContext.drawText(layout[:centerX], layout[:titleY], _poppinsSmallFont, chartTitle, Graphics.TEXT_JUSTIFY_CENTER);
        if (statusNote != null) {
            deviceContext.setColor(Theme.TEXT_SECONDARY, Theme.BACKGROUND);
            deviceContext.drawText(layout[:centerX], layout[:noteY], _poppinsTinyFont, statusNote, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    /**
     * Project timestamps and unrounded prices into plot coordinates.
     * @param priceIntervals Ordered [minute, price, optional level] arrays.
     * @param chartSpanMinutes Positive duration represented by the plot width.
     * @param layout Plot bounds and dimensions from calculateLayout().
     * @param scale Price minimum and range from calculatePriceScale().
     * @return [x, y, minute, price, level] arrays; missing levels become zero.
     */
    private function projectIntervals(priceIntervals, chartSpanMinutes, layout, scale) {
        var graphPoints = [];
        for (var intervalIndex = 0; intervalIndex < priceIntervals.size(); intervalIndex++) {
            var priceInterval = priceIntervals[intervalIndex];
            var plotMinute = priceInterval[0];
            var intervalPrice = priceInterval[1];

            var pointX = layout[:left] + plotMinute * layout[:width] / chartSpanMinutes;
            var pointY = layout[:bottom] - (intervalPrice - scale[:minimum]) * layout[:height] / scale[:range];
            var levelCode = priceInterval.size() > 2 ? priceInterval[2] : 0;
            graphPoints.add([pointX, pointY, plotMinute, intervalPrice, levelCode]);
        }

        return graphPoints;
    }

    /**
     * Draw a dashed average line, trimming the final dash at the right edge.
     * @param deviceContext Target drawing surface.
     * @param plotLeft Left endpoint in pixels.
     * @param plotRight Right endpoint in pixels.
     * @param averageY Projected average-price Y coordinate.
     */
    private function drawAverageLine(deviceContext, plotLeft, plotRight, averageY) {
        deviceContext.setColor(Theme.CHART_AVERAGE, Theme.BACKGROUND);
        for (var dashX = plotLeft; dashX < plotRight; dashX += AVERAGE_DASH_STRIDE) {
            var dashEnd = dashX + AVERAGE_DASH_LENGTH < plotRight ? dashX + AVERAGE_DASH_LENGTH : plotRight;
            deviceContext.drawLine(dashX, averageY, dashEnd, averageY);
        }
    }

    /**
     * Draw level-colored horizontal intervals and vertical price transitions.
     * The final interval extends to the plot's right edge.
     * @param deviceContext Target drawing surface with series pen width selected.
     * @param graphPoints Ordered projected points from projectIntervals().
     * @param plotRight Right endpoint of the final step in pixels.
     */
    private function drawStepSeries(deviceContext, graphPoints, plotRight) {
        for (var pointIndex = 0; pointIndex < graphPoints.size(); pointIndex++) {
            var currentPoint = graphPoints[pointIndex];
            deviceContext.setColor(currentPoint[POINT_LEVEL] > 0 ? _levelColors.getColorForCode(currentPoint[POINT_LEVEL]) : Theme.CHART_DEFAULT_LINE, Theme.BACKGROUND);
            var nextPointX = plotRight;
            if (pointIndex + 1 < graphPoints.size()) {
                nextPointX = graphPoints[pointIndex + 1][POINT_X];
            }
            deviceContext.drawLine(currentPoint[POINT_X], currentPoint[POINT_Y], nextPointX, currentPoint[POINT_Y]);

            if (pointIndex + 1 < graphPoints.size()) {
                var nextPointY = graphPoints[pointIndex + 1][POINT_Y];
                if (nextPointY != currentPoint[POINT_Y]) {
                    deviceContext.drawLine(nextPointX, currentPoint[POINT_Y], nextPointX, nextPointY);
                }
            }
        }
    }

    /**
     * Mark the latest interval starting at or before the current local minute,
     * positioning the marker at that interval's midpoint and drawing its footer.
     * @param deviceContext Target drawing surface.
     * @param graphPoints Chronologically ordered projected points.
     * @param layout Plot geometry from calculateLayout().
     * @param chartSpanMinutes Time range starting at today's midnight.
     * @param intervalDurationMinutes Interval length; null skips marker and footer.
     * @param currency Footer currency code; null suppresses only the footer.
     */
    private function drawCurrentMarker(deviceContext, graphPoints, layout, chartSpanMinutes, intervalDurationMinutes, currency) {
        var localTime = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var currentMinuteOfDay = localTime.hour * MINUTES_PER_HOUR + localTime.min;
        if (currentMinuteOfDay >= chartSpanMinutes) {
            return;
        }

        var activeGraphPoint = null;
        for (var pointIndex = 0; pointIndex < graphPoints.size(); pointIndex++) {
            if (graphPoints[pointIndex][POINT_MINUTE] <= currentMinuteOfDay) {
                activeGraphPoint = graphPoints[pointIndex];
            }
        }
        if (activeGraphPoint == null) {
            return;
        }

        if (intervalDurationMinutes == null) {
            return;
        }
        // The two-day chart starts at today's midnight, so today's local
        // minute selects an interval in its first day, not tomorrow's.
        var intervalCenterMinute = activeGraphPoint[POINT_MINUTE] + intervalDurationMinutes / 2;
        var markerX = layout[:left] + intervalCenterMinute * layout[:width] / chartSpanMinutes;
        var markerY = activeGraphPoint[POINT_Y];
        deviceContext.setColor(Theme.CHART_MARKER, Theme.BACKGROUND);
        deviceContext.fillCircle(markerX, markerY, MARKER_RADIUS);
        deviceContext.setColor(Theme.CHART_MARKER_OUTLINE, Theme.BACKGROUND);
        deviceContext.drawCircle(markerX, markerY, MARKER_RADIUS);
        drawCurrentIntervalFooter(deviceContext, activeGraphPoint, intervalDurationMinutes, currency, layout[:bottom]);
    }

    /**
     * Draw the rounded price, unit, and time range as a centered footer block.
     * @param deviceContext Target drawing surface.
     * @param activeGraphPoint Projected point containing interval minute and price.
     * @param intervalDurationMinutes Interval length used to compute its end time.
     * @param currency Currency code; SEK displays as ore, null omits the footer.
     * @param plotBottom Plot baseline Y coordinate, before X-axis labels.
     */
    private function drawCurrentIntervalFooter(deviceContext, activeGraphPoint, intervalDurationMinutes, currency, plotBottom) {
        var formattedPrice = activeGraphPoint[POINT_PRICE].format("%.0f");
        if (formattedPrice == null || currency == null) {
            return;
        }

        var priceUnit = currency.equals("SEK") ? Application.loadResource(Rez.Strings.PriceUnitOre) as String : currency;
        var priceFont = selectFooterPriceFont(deviceContext, formattedPrice, priceUnit);
        var unitFont = _poppinsTinyFont;
        var priceWidth = deviceContext.getTextWidthInPixels(formattedPrice, priceFont);
        var unitWidth = deviceContext.getTextWidthInPixels(priceUnit, unitFont);
        var footerStartX = (deviceContext.getWidth() - priceWidth - unitWidth - FOOTER_UNIT_GAP) / 2;
        var footer = calculateFooterLayout(deviceContext, priceFont, plotBottom);

        deviceContext.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        deviceContext.drawText(footerStartX, footer[:priceY], priceFont, formattedPrice, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        deviceContext.drawText(footerStartX + priceWidth + FOOTER_UNIT_GAP, footer[:priceY], unitFont, priceUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        deviceContext.drawText(deviceContext.getWidth() / 2, footer[:timeY], _poppinsTinyFont, formatIntervalRange(activeGraphPoint[POINT_MINUTE], intervalDurationMinutes), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /**
     * Choose the largest price font that fits beside the unit.
     * @param deviceContext Drawing surface used for text measurements.
     * @param formattedPrice Price text already rounded for display.
     * @param priceUnit Unit text drawn with the tiny font.
     * @return Medium or small font when it fits; tiny is the final fallback
     *         even when the combined text remains wider than the available space.
     */
    private function selectFooterPriceFont(deviceContext, formattedPrice, priceUnit) {
        var availableWidth = deviceContext.getWidth() - FOOTER_SIDE_INSET * 2;
        var unitWidth = deviceContext.getTextWidthInPixels(priceUnit, _poppinsTinyFont);
        var fonts = [_poppinsMediumFont, _poppinsSmallFont];
        for (var index = 0; index < fonts.size(); index++) {
            var priceWidth = deviceContext.getTextWidthInPixels(formattedPrice, fonts[index]);
            if (priceWidth + unitWidth + FOOTER_UNIT_GAP <= availableWidth) {
                return fonts[index];
            }
        }
        return _poppinsTinyFont;
    }

    /**
     * Center both footer rows between the X labels and the bottom inset.
     * @param deviceContext Drawing surface providing dimensions and font heights.
     * @param priceFont Selected footer price font.
     * @param plotBottom Plot baseline Y coordinate.
     * @return Dictionary with vertical text centers :priceY and :timeY.
     */
    private function calculateFooterLayout(deviceContext, priceFont, plotBottom) {
        var priceHeight = deviceContext.getFontHeight(priceFont);
        var unitHeight = deviceContext.getFontHeight(_poppinsTinyFont);
        var priceRowHeight = priceHeight > unitHeight ? priceHeight : unitHeight;
        var timeHeight = deviceContext.getFontHeight(_poppinsTinyFont);
        var footerHeight = priceRowHeight + FOOTER_ROW_GAP + timeHeight;
        // Center the whole block after the X labels, not just its price row.
        var footerTop = plotBottom + X_LABEL_GAP + timeHeight;
        var footerBottom = deviceContext.getHeight() - getDisplayDiameter(deviceContext) * FOOTER_BOTTOM_RATIO;
        var footerStartY = footerTop + (footerBottom - footerTop - footerHeight) / 2;
        return {
            :priceY => footerStartY + priceRowHeight / 2,
            :timeY => footerStartY + priceRowHeight + FOOTER_ROW_GAP + timeHeight / 2
        };
    }

    /**
     * Format an interval as HH:mm-HH:mm, wrapping both times at midnight.
     * @param startMinute Nonnegative minute offset from the chart's first midnight.
     * @param durationMinutes Interval length in minutes.
     * @return Start and end time joined by a hyphen, without a date.
     */
    private function formatIntervalRange(startMinute, durationMinutes) {
        return _priceCache.formatMinuteRange(startMinute, durationMinutes);
    }

    /**
     * Draw the left and bottom axis lines followed by their labels.
     * @param deviceContext Target drawing surface.
     * @param layout Plot geometry from calculateLayout().
     * @param scale Price scale including formatted Y ticks.
     * @param chartSpanMinutes Duration used to position hour labels.
     */
    private function drawAxes(deviceContext, layout, scale, chartSpanMinutes) {
        deviceContext.setColor(Theme.CHART_AXIS, Theme.BACKGROUND);
        deviceContext.drawLine(layout[:left], layout[:top], layout[:left], layout[:bottom]);
        deviceContext.drawLine(layout[:left], layout[:bottom], layout[:right], layout[:bottom]);
        drawYAxisLabels(deviceContext, layout, scale);
        drawXAxisLabels(deviceContext, layout, chartSpanMinutes);
    }

    /**
     * Draw measured tick labels right-aligned beside the Y axis.
     * @param deviceContext Target surface with the axis color already selected.
     * @param layout Plot geometry from calculateLayout().
     * @param scale Price minimum, range, and formatted ticks.
     */
    private function drawYAxisLabels(deviceContext, layout, scale) {
        var ticks = scale[:ticks];
        for (var index = 0; index < ticks.size(); index++) {
            var tickY = layout[:bottom] - (ticks[index][0] - scale[:minimum]) * layout[:height] / scale[:range];
            deviceContext.drawText(layout[:left] - Y_LABEL_GAP, tickY, _poppinsTinyFont, ticks[index][1], Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    /**
     * Draw six-hour labels, repeating clock hours for a two-day chart.
     * @param deviceContext Target surface with the axis color already selected.
     * @param layout Plot geometry from calculateLayout().
     * @param chartSpanMinutes Positive time range; spans over one day use seven labels.
     */
    private function drawXAxisLabels(deviceContext, layout, chartSpanMinutes) {
        var hourLabelOffsets;
        var hourLabels;
        if (chartSpanMinutes > MINUTES_PER_DAY) {
            hourLabelOffsets = [6, 12, 18, 24, 30, 36, 42];
            hourLabels = ["06", "12", "18", "00", "06", "12", "18"];
        } else {
            hourLabelOffsets = [6, 12, 18];
            hourLabels = ["06", "12", "18"];
        }
        for (var labelIndex = 0; labelIndex < hourLabels.size(); labelIndex++) {
            var labelX = layout[:left] + layout[:width] * hourLabelOffsets[labelIndex] / (chartSpanMinutes / MINUTES_PER_HOUR);
            deviceContext.drawText(labelX, layout[:bottom] + X_LABEL_GAP, _poppinsTinyFont, hourLabels[labelIndex], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    /**
     * Round a desired tick interval upward to the 1/2/5 times 10^n sequence.
     * @param rawTickStep Desired spacing in price units.
     * @return Readable positive spacing, or 1 for a nonpositive input.
     */
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
