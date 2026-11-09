import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Application.Storage;

(:glance)
class TibberGlanceView extends WatchUi.GlanceView {
    var _priceCache;
    var _priceData;
    var _hourBar;
    var _microFont;
    var _priceFonts;

    /** Free glance heap (bytes) required before the Poppins bitmap fonts are loaded; below it system fonts are used. */
    private const POPPINS_MIN_FREE_BYTES = 40000;

    function initialize() {
        GlanceView.initialize();
        _priceCache = new TibberPriceCache();
        _priceData = null;
        _hourBar = new TibberHourLevelBar();
        loadFonts();
    }

    /** Use Poppins where the glance heap has room, otherwise system fonts (small-memory devices). */
    private function loadFonts() {
        _microFont = Graphics.FONT_XTINY;
        _priceFonts = [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY];
        var stats = System.getSystemStats();
        if (stats.freeMemory < POPPINS_MIN_FREE_BYTES) {
            return;
        }
        _microFont = WatchUi.loadResource(Rez.Fonts.PoppinsMicro) as WatchUi.FontResource;
        _priceFonts = [
            WatchUi.loadResource(Rez.Fonts.PoppinsLarge) as WatchUi.FontResource,
            WatchUi.loadResource(Rez.Fonts.PoppinsMedium) as WatchUi.FontResource,
            WatchUi.loadResource(Rez.Fonts.PoppinsSmall) as WatchUi.FontResource,
            WatchUi.loadResource(Rez.Fonts.PoppinsTiny) as WatchUi.FontResource
        ];
    }

    function onShow() {
        var priceResolution = Storage.getValue("tibber_price_resolution");
        if (!(priceResolution instanceof String) ||
            (!(priceResolution as String).equals("HOURLY") && !(priceResolution as String).equals("QUARTER_HOURLY"))) {
            priceResolution = "QUARTER_HOURLY";
        }

        var currentPriceData = _priceCache.getCurrentPrice(priceResolution);
        if (currentPriceData instanceof Dictionary) {
            _priceData = currentPriceData;
        } else {
            _priceData = null;
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        dc.clear();

        var textX = 12;
        var availableWidth = width - textX - 12;
        var metadataLine = "";
        var priceLine = str(Rez.Strings.OpenTibber);
        var selectedPriceFont = null;
        var priceType = Storage.getValue("tibber_price_type");
        if (!(priceType instanceof String) || !((priceType as String).equals("TOTAL") || (priceType as String).equals("SPOT"))) {
            priceType = "TOTAL";
        }

        var hasPrice = false;
        if (_priceData != null) {
            var price = _priceCache.getDisplayPrice(_priceData, priceType);
            var currency = _priceData.get("currency");
            if (price instanceof String) {
                var unit = TibberCurrency.unitLabel(currency);
                hasPrice = true;
                priceLine = (price as String) + " " + unit;
                var startTime = _priceData.get("current_time");
                var intervalMinutes = _priceData.get("interval_minutes");
                var intervalRange = _priceCache.formatIntervalRange(startTime, intervalMinutes);
                metadataLine = intervalRange instanceof String ? intervalRange as String : "";
            }
        }

        var hourLevels = _priceData != null ? _priceData.get("hour_levels") : null;
        var showBar = _hourBar.isValid(hourLevels);
        var markerHeight = _hourBar.getHeight();
        var barGap = 0;
        var reservedBarHeight = showBar ? markerHeight + barGap : 0;

        var intervalGap = 8;
        var intervalWidth = metadataLine.length() > 0 ? dc.getTextWidthInPixels(metadataLine, _microFont) : 0;
        var priceAvailableWidth = availableWidth - (intervalWidth > 0 ? intervalWidth + intervalGap : 0);
        // Keep the interval unless the price cannot fit beside it even in the smallest font;
        // otherwise the price font shrinks first (fitPriceFont).
        if (intervalWidth > 0 && dc.getTextWidthInPixels(priceLine, (_priceFonts as Array)[3] as Graphics.FontType) > priceAvailableWidth) {
            metadataLine = "";
            intervalWidth = 0;
            priceAvailableWidth = availableWidth;
        }

        if (hasPrice) {
            selectedPriceFont = fitPriceFont(dc, priceLine, priceAvailableWidth, height - reservedBarHeight - 4);
        } else {
            // Large/Medium Poppins hold only price glyphs (no lowercase p, i, b...), so the text message
            // uses the largest system font that fits.
            selectedPriceFont = fitFont(
                dc, priceLine,
                [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY],
                priceAvailableWidth, height - 4
            );
        }
        priceLine = fitText(dc, priceLine, selectedPriceFont, priceAvailableWidth);
        var priceHeight = dc.getTextDimensions(priceLine, selectedPriceFont)[1];
        var contentHeight = priceHeight + reservedBarHeight;
        var rowY = (height - contentHeight) / 2;
        dc.drawText(textX, rowY, selectedPriceFont, priceLine, Graphics.TEXT_JUSTIFY_LEFT);
        if (metadataLine.length() > 0) {
            var priceWidth = dc.getTextWidthInPixels(priceLine, selectedPriceFont);
            var baselineY = rowY + Graphics.getFontAscent(selectedPriceFont);
            dc.setColor(Theme.TEXT_SECONDARY, Theme.BACKGROUND);
            dc.drawText(
                textX + priceWidth + intervalGap,
                baselineY - Graphics.getFontAscent(_microFont),
                _microFont,
                metadataLine,
                Graphics.TEXT_JUSTIFY_LEFT
            );
        }
        if (showBar) {
            _hourBar.draw(dc, textX, rowY + priceHeight + barGap, availableWidth, hourLevels as String);
        }
    }

    /** Pick the largest font whose text fits the given width and height. */
    private function fitPriceFont(dc, text, availableWidth, availableHeight) {
        return fitFont(dc, text, _priceFonts as Array, availableWidth, availableHeight);
    }

    /** First font in the list (largest first) that fits; the last one if none does. */
    private function fitFont(dc as Graphics.Dc, text, fontList, availableWidth, availableHeight) {
        var fonts = fontList as Array;
        for (var i = 0; i < fonts.size() - 1; i++) {
            var font = fonts[i] as Graphics.FontType;
            if (dc.getTextWidthInPixels(text, font) <= availableWidth && dc.getTextDimensions(text, font)[1] <= availableHeight) {
                return font;
            }
        }
        return fonts[fonts.size() - 1] as Graphics.FontType;
    }

    private function fitText(dc, text, font, availableWidth) {
        if (text == null || text.length() == 0 || dc.getTextWidthInPixels(text, font) <= availableWidth) {
            return text == null ? "" : text;
        }

        var shortened = text;
        while (shortened.length() > 3 && dc.getTextWidthInPixels(shortened + "...", font) > availableWidth) {
            shortened = shortened.substring(0, shortened.length() - 1);
        }
        return shortened.length() > 3 ? shortened + "..." : shortened;
    }

    private function str(resource) {
        return WatchUi.loadResource(resource) as String;
    }
}