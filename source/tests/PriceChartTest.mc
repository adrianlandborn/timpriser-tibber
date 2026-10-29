import Toybox.Graphics;
import Toybox.Math;

(:test)
class PriceChartTestDc {
    var lines = [];
    var texts = [];
    var circles = [];
    private var _size;
    private var _fontHeights;

    function initialize(size, fontHeights) {
        _size = size;
        _fontHeights = fontHeights;
    }

    function getWidth() { return _size; }
    function getHeight() { return _size; }
    function getFontHeight(font) { return _fontHeights[font]; }
    function getTextWidthInPixels(text, font) { return text.length() * _fontHeights[font] / 2; }
    function setColor(foreground, background) {}
    function setPenWidth(width) {}
    function drawLine(x1, y1, x2, y2) { lines.add([x1, y1, x2, y2]); }
    function drawText(x, y, font, text, justification) { texts.add([x, y, font, text, justification]); }
    function fillCircle(x, y, radius) { circles.add([x, y, radius]); }
    function drawCircle(x, y, radius) {}
}

(:test)
function testPriceChartLayoutBaseline(logger) {
    var sizes = [240, 480];
    var fonts = [[12, 16, 24], [16, 22, 32]];
    for (var index = 0; index < sizes.size(); index++) {
        var size = sizes[index];
        var dc = new PriceChartTestDc(size, fonts[index]);
        var chart = new TibberPriceChart(0, 1, 2);
        chart.draw(dc, [[0, 200.0, 1], [720, 600.0, 5]], 1440, null, "SEK", "IDAG | 15 MIN", null);
        var expectedLeft = size * 0.1 + 3 * fonts[index][0] / 2 + 6;
        var expectedRight = size * 0.9 - 5;
        var expectedTop = size * 0.21 + 8;
        var expectedBottom = size * 0.79 - 25;
        var footerLimit = size - fonts[index][2] - fonts[index][0] * 2 - 12 - size * 0.06;
        if (expectedBottom > footerLimit) {
            expectedBottom = footerLimit;
        }
        var yAxis = dc.lines[0];
        var xAxis = dc.lines[1];
        if (Math.abs(yAxis[0] - expectedLeft) > 0.01 ||
            Math.abs(yAxis[1] - expectedTop) > 0.01 ||
            Math.abs(xAxis[2] - expectedRight) > 0.01 ||
            Math.abs(xAxis[3] - expectedBottom) > 0.01) {
            logger.debug("Chart axes changed from the pre-refactor layout");
            return false;
        }
        if (!dc.texts[1][3].equals("200") || !dc.texts[2][3].equals("400") ||
            !dc.texts[3][3].equals("600") || dc.circles.size() != 0) {
            return false;
        }
        var averageY = (expectedBottom + expectedTop) / 2;
        var firstDash = dc.lines[2];
        var stepStart = dc.lines[dc.lines.size() - 3];
        var stepEnd = dc.lines[dc.lines.size() - 1];
        if (Math.abs(firstDash[1] - averageY) > 0.01 || firstDash[2] - firstDash[0] != 4 ||
            Math.abs(stepStart[0] - expectedLeft) > 0.01 ||
            Math.abs(stepStart[1] - expectedBottom) > 0.01 ||
            Math.abs(stepStart[2] - (expectedLeft + expectedRight) / 2) > 0.01 ||
            Math.abs(stepEnd[1] - expectedTop) > 0.01 ||
            Math.abs(stepEnd[2] - expectedRight) > 0.01) {
            logger.debug("Step-series projection or average-line geometry changed");
            return false;
        }
    }
    return true;
}

(:test)
function testPriceChartTicksAndFooter(logger) {
    var series = [
        [[0, 300.0], [720, 300.0]],
        [[0, -100.0], [720, 100.0]],
        [[0, 0.1], [720, 0.3]]
    ];
    var firstLabels = ["300", "-100", "0.10"];
    for (var index = 0; index < series.size(); index++) {
        var dc = new PriceChartTestDc(480, [16, 22, 32]);
        var chart = new TibberPriceChart(0, 1, 2);
        chart.draw(dc, series[index], 2880, 60, "SEK", "2 DAGAR | TIMPRIS", "Imorgon saknas");
        if (!dc.texts[2][3].equals(firstLabels[index]) || dc.circles.size() != 1) {
            logger.debug("Flat, negative or fractional price ticks changed");
            return false;
        }
        var count = dc.texts.size();
        var price = dc.texts[count - 3];
        var unit = dc.texts[count - 2];
        var time = dc.texts[count - 1];
        if (!unit[3].equals("öre") || Math.abs(price[1] - 402.7) > 0.01 ||
            price[1] != unit[1] || Math.abs(time[1] - 428.7) > 0.01 ||
            time[0] != 240) {
            logger.debug("Footer positioning changed from the pre-refactor layout");
            return false;
        }
        var hourLabels = 0;
        for (var textIndex = 0; textIndex < count; textIndex++) {
            if (dc.texts[textIndex][3].equals("06")) {
                hourLabels++;
            }
        }
        if (hourLabels != 2) {
            return false;
        }
    }
    var emptyDc = new PriceChartTestDc(240, [12, 16, 24]);
    var emptyChart = new TibberPriceChart(0, 1, 2);
    emptyChart.draw(emptyDc, [], 1440, 15, "SEK", "Empty", null);
    emptyChart.draw(emptyDc, null, 1440, 15, "SEK", "Empty", null);
    return emptyDc.lines.size() == 0 && emptyDc.texts.size() == 0;
}

(:test)
function testPriceChartFooterFontFallback(logger) {
    var units = ["USD", "ABCDEFGHIJKLMNO", "ABCDEFGHIJKLMNOP"];
    var expectedFonts = [2, 1, 0];
    for (var index = 0; index < units.size(); index++) {
        var dc = new PriceChartTestDc(240, [16, 22, 32]);
        var chart = new TibberPriceChart(0, 1, 2);
        chart.draw(dc, [[0, 12345678.0]], 1440, 15, units[index], "Price", null);
        var count = dc.texts.size();
        if (dc.texts[count - 3][2] != expectedFonts[index] ||
            !dc.texts[count - 2][3].equals(units[index])) {
            logger.debug("Footer font fallback or non-SEK unit changed");
            return false;
        }
    }
    var noCurrencyDc = new PriceChartTestDc(240, [12, 16, 24]);
    var noCurrencyChart = new TibberPriceChart(0, 1, 2);
    noCurrencyChart.draw(noCurrencyDc, [[0, 300.0]], 1440, 15, null, "Price", null);
    return noCurrencyDc.circles.size() == 1 &&
        noCurrencyDc.texts[noCurrencyDc.texts.size() - 1][3].equals("18");
}
