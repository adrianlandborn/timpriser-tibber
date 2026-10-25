import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberNetworkFeeDetailView extends WatchUi.View {
    private const BUTTON_RADIUS = 20;
    private const BUTTON_LEFT_INSET = 28;
    private var _feeOption;
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
        _fontCaption = captionFont;
        _fontBody = bodyFont;
        _fontDisplay = displayFont;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var isFixedFee = _feeOption == 2;
        var isEnergyTax = _feeOption == 5;
        var title = isEnergyTax ? "Energiskatt" : (isFixedFee ? "Fast nätavgift" : "Rörlig nätavgift");
        drawCentered(dc, width, 28, title, _fontBody, Graphics.COLOR_WHITE);

        if (isEnergyTax) {
            drawCentered(dc, width, 58, "Statlig skatt per kWh", _fontCaption, Graphics.COLOR_LT_GRAY);
            drawCentered(dc, width, 73, "Inklusive 25% moms", _fontCaption, Graphics.COLOR_LT_GRAY);
        } else if (isFixedFee) {
            drawCentered(dc, width, 58, "Fast avgift från nätägaren", _fontCaption, Graphics.COLOR_LT_GRAY);
            drawCentered(dc, width, 73, "Inklusive moms per kWh", _fontCaption, Graphics.COLOR_LT_GRAY);
        } else {
            drawCentered(dc, width, 58, "Timmens snittspotpris", _fontCaption, Graphics.COLOR_LT_GRAY);
            drawCentered(dc, width, 73, "inklusive moms", _fontCaption, Graphics.COLOR_LT_GRAY);
        }

        var numericValue = getFeeValue();
        var valueText = numericValue.format("%.0f");
        var valueCenterY = height * 0.57;
        var displayFont = fitDisplayFont(dc, valueText, width - 2 * (BUTTON_LEFT_INSET + BUTTON_RADIUS + 8));
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, valueCenterY, displayFont, valueText, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var unit = isFixedFee || isEnergyTax ? "öre/kWh" : "%";
        drawCentered(dc, width, valueCenterY + dc.getTextDimensions(valueText, displayFont)[1] / 2 + 12, unit, _fontCaption, Graphics.COLOR_LT_GRAY);

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
        var key = _feeOption == 5 ? "tibber_energy_tax_ore" : (_feeOption == 2 ? "tibber_network_fixed_ore" : "tibber_network_variable_percent");
        var defaultValue = _feeOption == 5 ? 45.0 : (_feeOption == 2 ? 20.0 : 5.0);
        var value = Storage.getValue(key);
        return (value instanceof Number || value instanceof Float) ? value : defaultValue;
    }

    private function fitDisplayFont(dc, text, availableWidth) {
        if (dc.getTextWidthInPixels(text, _fontDisplay) <= availableWidth) {
            return _fontDisplay;
        }
        return _fontBody;
    }

    private function drawCentered(dc, width, y, text, font, color) {
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawAdjustButton(dc, centerX, centerY, isPlus) {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
        dc.fillCircle(centerX, centerY, BUTTON_RADIUS);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLUE);
        dc.setPenWidth(3);
        dc.drawLine(centerX - 8, centerY, centerX + 8, centerY);
        if (isPlus) {
            dc.drawLine(centerX, centerY - 8, centerX, centerY + 8);
        }
        dc.setPenWidth(1);
    }

}