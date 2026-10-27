import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class TibberGlanceView extends WatchUi.GlanceView {
    var _priceCache;
    var _priceData;
    var _microFont;
    var _tinyFont;
    var _smallFont;
    var _mediumFont;
    var _largeFont;
    var _hourBar;

    function initialize() {
        GlanceView.initialize();
        _priceCache = new TibberPriceCache();
        _priceData = null;
        _hourBar = new HourLevelBar();
        _microFont = WatchUi.loadResource(Rez.Fonts.PoppinsMicro) as WatchUi.FontResource;
        _tinyFont = WatchUi.loadResource(Rez.Fonts.PoppinsTiny) as WatchUi.FontResource;
        _smallFont = WatchUi.loadResource(Rez.Fonts.PoppinsSmall) as WatchUi.FontResource;
        _mediumFont = WatchUi.loadResource(Rez.Fonts.PoppinsMedium) as WatchUi.FontResource;
        _largeFont = WatchUi.loadResource(Rez.Fonts.PoppinsLarge) as WatchUi.FontResource;
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
            storeGlancePriceData(currentPriceData as Dictionary);
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
        var priceLine = "Öppna Tibber";
        var selectedPriceFont = _largeFont;
        var rowSpacing = 2;
        var priceType = Storage.getValue("tibber_price_type");
        if (!(priceType instanceof String) || !((priceType as String).equals("TOTAL") || (priceType as String).equals("SPOT"))) {
            priceType = "TOTAL";
        }

        if (_priceData != null) {
            var price = _priceCache.getDisplayPrice(_priceData, priceType);
            var currency = _priceData.get("currency");
            if (price instanceof String) {
                var unit = currency != null && !currency.equals("SEK") ? currency : "öre";
                priceLine = (price as String) + " " + unit;
                var startTime = _priceData.get("current_time");
                var intervalMinutes = _priceData.get("interval_minutes");
                metadataLine = formatIntervalRange(startTime, intervalMinutes);
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
        if (priceAvailableWidth < availableWidth / 2) {
            metadataLine = "";
            intervalWidth = 0;
            priceAvailableWidth = availableWidth;
        }

        selectedPriceFont = fitPriceFont(dc, priceLine, priceAvailableWidth, height - reservedBarHeight - 4);
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

    private function drawRow(dc, x, top, text, font, rowHeight) {
        dc.drawText(
            x,
            top + rowHeight / 2,
            font,
            text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    private function fitPriceFont(dc, text, availableWidth, availableHeight) {
        var largeHeight = dc.getTextDimensions(text, _largeFont)[1];
        if (dc.getTextWidthInPixels(text, _largeFont) <= availableWidth && largeHeight <= availableHeight) {
            return _largeFont;
        }

        var mediumHeight = dc.getTextDimensions(text, _mediumFont)[1];
        if (dc.getTextWidthInPixels(text, _mediumFont) <= availableWidth && mediumHeight <= availableHeight) {
            return _mediumFont;
        }

        var smallHeight = dc.getTextDimensions(text, _smallFont)[1];
        if (dc.getTextWidthInPixels(text, _smallFont) <= availableWidth && smallHeight <= availableHeight) {
            return _smallFont;
        }
        return _tinyFont;
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

    private function formatIntervalRange(startTime, intervalMinutes) {
        if (!(startTime instanceof String) || intervalMinutes == null || startTime.length() < 5) {
            return "";
        }

        var startHour = startTime.substring(0, 2).toNumber();
        var startMinute = startTime.substring(3, 5).toNumber();
        if (startHour == null || startMinute == null) {
            return "";
        }

        var endMinuteOfDay = (startHour * 60 + startMinute + intervalMinutes) % 1440;
        var endTime = (endMinuteOfDay / 60).format("%02d") + ":" + (endMinuteOfDay % 60).format("%02d");
        return startTime.substring(0, 5) + "-" + endTime;
    }

    private function storeGlancePriceData(priceData as Dictionary) {
        try {
            Storage.setValue("tibber_glance_ready", false);
            Storage.setValue("tibber_glance_price", priceData.get("current_price"));
            Storage.setValue("tibber_glance_spot_price", priceData.get("current_spot_price"));
            Storage.setValue("tibber_glance_currency", priceData.get("currency"));
            Storage.setValue("tibber_glance_time", priceData.get("current_time"));
            Storage.setValue("tibber_glance_interval", priceData.get("interval_minutes"));
            Storage.setValue("tibber_glance_ready", true);
        } catch (ex) {
        }
    }
}