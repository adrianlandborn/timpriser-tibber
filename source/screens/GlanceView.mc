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

    function initialize() {
        GlanceView.initialize();
        _priceCache = new TibberPriceCache();
        _priceData = null;
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
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
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

        metadataLine = fitText(dc, metadataLine, _microFont, availableWidth);

        var metadataHeight = metadataLine.length() > 0 ? dc.getTextDimensions(metadataLine, _microFont)[1] : 0;
        var reservedTextHeight = metadataHeight > 0 ? metadataHeight + rowSpacing : 0;
        selectedPriceFont = fitPriceFont(dc, priceLine, availableWidth, height - reservedTextHeight - 4);
        priceLine = fitText(dc, priceLine, selectedPriceFont, availableWidth);
        var priceHeight = dc.getTextDimensions(priceLine, selectedPriceFont)[1];
        var contentHeight = priceHeight + reservedTextHeight;
        var rowY = (height - contentHeight) / 2;
        drawRow(dc, textX, rowY, priceLine, selectedPriceFont, priceHeight);
        if (metadataHeight > 0) {
            rowY += priceHeight + rowSpacing;
            drawRow(dc, textX, rowY, metadataLine, _microFont, metadataHeight);
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