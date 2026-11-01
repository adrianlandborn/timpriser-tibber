import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberNetworkFeeDetailView extends WatchUi.View {
    private const BUTTON_RADIUS = 20;
    private const BUTTON_LEFT_INSET = 28;
    private var _feeOption;
    private var _priceCache;
    private var _fontCaption;
    private var _fontBody;
    private var _fontDisplay;
    private var _plusCenterX;
    private var _plusCenterY;
    private var _minusCenterX;
    private var _minusCenterY;

    function initialize(feeOption, captionFont, bodyFont, displayFont) {
        View.initialize();
        _feeOption = feeOption;
        _priceCache = new TibberPriceCache();
        _fontCaption = captionFont;
        _fontBody = bodyFont;
        _fontDisplay = displayFont;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        dc.clear();

        var isFixedFee = _feeOption == 2;
        var isEnergyTax = _feeOption == 5;
        var title = isEnergyTax ? str(Rez.Strings.EnergyTax) : (isFixedFee ? str(Rez.Strings.FixedNetworkFee) : str(Rez.Strings.VariableNetworkFee));
        var caption1 = isEnergyTax ? str(Rez.Strings.EnergyTaxCaption1) : (isFixedFee ? str(Rez.Strings.FixedFeeCaption1) : str(Rez.Strings.VariableFeeCaption1));
        var caption2 = isEnergyTax ? str(Rez.Strings.EnergyTaxCaption2) : (isFixedFee ? str(Rez.Strings.FixedFeeCaption2) : str(Rez.Strings.VariableFeeCaption2));

        var titleHeight = dc.getTextDimensions(title, _fontBody)[1];
        var captionHeight = dc.getTextDimensions(caption1, _fontCaption)[1];
        var topInset = height / 12;
        var titleY = topInset + titleHeight / 2;
        var caption1Y = titleY + titleHeight / 2 + captionHeight / 2 + captionHeight / 4;
        var caption2Y = caption1Y + captionHeight;
        drawCentered(dc, width, titleY, title, _fontBody, Theme.TEXT_PRIMARY);
        drawCentered(dc, width, caption1Y, caption1, _fontCaption, Theme.TEXT_SECONDARY);
        drawCentered(dc, width, caption2Y, caption2, _fontCaption, Theme.TEXT_SECONDARY);

        var numericValue = getFeeValue();
        var valueText = numericValue.format("%.0f");
        var valueCenterY = height * 0.57;
        var displayFont = fitDisplayFont(dc, valueText, width - 2 * (BUTTON_LEFT_INSET + BUTTON_RADIUS + 8));
        dc.setColor(Theme.TEXT_PRIMARY, Theme.BACKGROUND);
        dc.drawText(width / 2, valueCenterY, displayFont, valueText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var unit = isFixedFee || isEnergyTax ? str(Rez.Strings.PriceUnitOrePerKwh) : str(Rez.Strings.PercentUnit);
        var valueHeight = dc.getTextDimensions(valueText, displayFont)[1];
        drawCentered(dc, width, valueCenterY + valueHeight / 2 + captionHeight / 2, unit, _fontCaption, Theme.TEXT_SECONDARY);

        _plusCenterX = BUTTON_LEFT_INSET;
        _plusCenterY = height / 2;
        _minusCenterX = width * 0.18;
        _minusCenterY = height * 0.75;
        drawAdjustButton(dc, _plusCenterX, _plusCenterY, true);
        drawAdjustButton(dc, _minusCenterX, _minusCenterY, false);
    }

    function adjust(direction) {
        var value = getFeeValue() + direction;
        if (value < 0) {
            value = 0;
        } else if ((_feeOption == 2 || _feeOption == 5) && value > 1000) {
            value = 1000;
        } else if (_feeOption == 3 && value > 100) {
            value = 100;
        }

        if (_feeOption == 5) {
            Storage.setValue("tibber_energy_tax_ore", value);
        } else if (_feeOption == 2) {
            Storage.setValue("tibber_network_fixed_ore", value);
        } else {
            Storage.setValue("tibber_network_variable_percent", value);
        }
        WatchUi.requestUpdate();
        return true;
    }

    function adjustAt(x, y) {
        var hitRadius = BUTTON_RADIUS + 8;
        if (x >= _plusCenterX - hitRadius && x <= _plusCenterX + hitRadius &&
            y >= _plusCenterY - hitRadius && y <= _plusCenterY + hitRadius) {
            return adjust(1);
        } else if (x >= _minusCenterX - hitRadius && x <= _minusCenterX + hitRadius &&
                   y >= _minusCenterY - hitRadius && y <= _minusCenterY + hitRadius) {
            return adjust(-1);
        }
        return true;
    }

    private function getFeeValue() {
        if (_feeOption == 5) {
            return _priceCache.getEnergyTax();
        }
        if (_feeOption == 2) {
            return _priceCache.getFixedNetworkFee();
        }
        return _priceCache.getVariableNetworkFee();
    }

    private function fitDisplayFont(dc, text, availableWidth) {
        if (dc.getTextWidthInPixels(text, _fontDisplay) <= availableWidth) {
            return _fontDisplay;
        }
        return _fontBody;
    }

    private function drawCentered(dc, width, y, text, font, color) {
        dc.setColor(color, Theme.BACKGROUND);
        dc.drawText(width / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawAdjustButton(dc, centerX, centerY, isPlus) {
        dc.setColor(Theme.ACCENT, Theme.BACKGROUND);
        dc.fillCircle(centerX, centerY, BUTTON_RADIUS);
        dc.setColor(Theme.TEXT_PRIMARY, Theme.ACCENT);
        dc.setPenWidth(3);
        dc.drawLine(centerX - 8, centerY, centerX + 8, centerY);
        if (isPlus) {
            dc.drawLine(centerX, centerY - 8, centerX, centerY + 8);
        }
        dc.setPenWidth(1);
    }

    private function str(resource) {
        return WatchUi.loadResource(resource) as String;
    }

}
