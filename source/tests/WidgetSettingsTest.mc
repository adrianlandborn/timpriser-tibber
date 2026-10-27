import Toybox.Application.Storage;
import Toybox.Graphics;

(:test)
class SettingsScrollTestWidget {
    var resolution = "QUARTER_HOURLY";
    var priceType = "TOTAL";

    function getCurrentPriceType() { return priceType; }
    function setCurrentPriceType(value) { priceType = value; }
    function getCurrentPriceResolution() { return resolution; }
    function setCurrentPriceResolution(value) { resolution = value; }
}

(:test)
class SettingsScrollTestDc {
    var focusCenter;
    var focusHeight;
    var focusVisible;
    var networkLabelColor;
    var energyTaxLabelColor;
    var resolutionCenter;
    private var _size;
    private var _clipTop;
    private var _clipBottom;
    private var _foreground;

    function initialize(size) { _size = size; }
    function getWidth() { return _size; }
    function getHeight() { return _size; }
    function clear() { focusCenter = null; focusVisible = false; }
    function setColor(foreground, background) { _foreground = foreground; }
    function setPenWidth(width) {}
    function fillRectangle(left, top, width, height) {}
    function fillCircle(centerX, centerY, radius) {}
    function drawText(left, top, font, text, justification) {
        if (text.equals("Nätavgifter (beta)")) {
            networkLabelColor = _foreground;
        } else if (text.equals("Energiskatt")) {
            energyTaxLabelColor = _foreground;
        } else if (text.equals("15 min")) {
            resolutionCenter = top;
        }
    }
    function getTextWidthInPixels(text, font) { return text.length() * 5; }
    function clearClip() {}

    function setClip(left, top, width, height) {
        _clipTop = top;
        _clipBottom = top + height;
    }

    function drawLine(startX, startY, endX, endY) {
        if (startX == 8 && endX == 8) {
            focusCenter = (startY + endY) / 2;
            focusHeight = endY - startY;
            focusVisible = startY >= _clipTop && endY <= _clipBottom;
        }
    }
}

(:test)
function testSettingsSelectionCentered(logger) {
    var sizes = [208, 240, 260, 280];
    for (var sizeIndex = 0; sizeIndex < sizes.size(); sizeIndex += 1) {
        var size = sizes[sizeIndex];
        var widget = new SettingsScrollTestWidget();
        var view = new TibberWidgetSettingsView(widget, null, null, null);
        var dc = new SettingsScrollTestDc(size);
        for (var option = 0; option < 6; option += 1) {
            view.onUpdate(dc);
            if (option == 0 && dc.resolutionCenter != size / 2) {
                return false;
            }
            if (dc.focusCenter != size / 2 || dc.focusHeight != 44 || !dc.focusVisible) {
                logger.debug("Selected row is not centered with a visible focus line");
                return false;
            }
            if (option < 5) {
                view.moveSelection(1);
            }
        }
        view.moveSelection(1);
        view.onUpdate(dc);
        view.selectOptionAt(size * 3 / 4, size / 2);
        view.onUpdate(dc);
        if (!widget.resolution.equals("HOURLY") || dc.focusCenter != size / 2) {
            return false;
        }
        view.moveSelection(-1);
        view.onUpdate(dc);
        if (dc.focusCenter != size / 2 || !dc.focusVisible) {
            return false;
        }
        view.moveSelection(1);
        view.onUpdate(dc);
        if (dc.focusCenter != size / 2 || !dc.focusVisible) {
            return false;
        }
    }
    return true;
}

(:test)
function testNetworkFeesRequireTaxes(logger) {
    var enabledKey = "tibber_network_fees_enabled";
    var fixedKey = "tibber_network_fixed_ore";
    var originalEnabled = Storage.getValue(enabledKey);
    var originalFixed = Storage.getValue(fixedKey);
    Storage.setValue(enabledKey, false);
    Storage.setValue(fixedKey, 20.0);
    var widget = new SettingsScrollTestWidget();
    widget.priceType = "SPOT";
    var view = new TibberWidgetSettingsView(widget, null, null, null);
    var dc = new SettingsScrollTestDc(280);
    view.onUpdate(dc);
    var disabledColor = dc.networkLabelColor;
    view.moveSelection(1);
    view.moveSelection(1);
    view.selectCurrentOption();
    var blockedToggle = Storage.getValue(enabledKey) == false;
    view.adjustNetworkFee(2, 1);
    var blockedAdjustment = Storage.getValue(fixedKey) == 20.0;
    view.moveSelection(-1);
    view.selectCurrentOption();
    view.onUpdate(dc);
    var taxBlockedWithoutNetwork = dc.energyTaxLabelColor == Theme.TEXT_DISABLED;
    view.moveSelection(1);
    view.selectCurrentOption();
    view.onUpdate(dc);
    var enabled = Storage.getValue(enabledKey) == true && dc.networkLabelColor == Theme.TEXT_PRIMARY &&
        dc.energyTaxLabelColor == Theme.TEXT_PRIMARY;
    view.moveSelection(-1);
    view.selectCurrentOption();
    view.onUpdate(dc);
    var switchedOff = Storage.getValue(enabledKey) == false &&
        widget.priceType.equals("SPOT") && dc.networkLabelColor == Theme.TEXT_DISABLED;
    if (originalEnabled == null) {
        Storage.deleteValue(enabledKey);
    } else {
        Storage.setValue(enabledKey, originalEnabled);
    }
    if (originalFixed == null) {
        Storage.deleteValue(fixedKey);
    } else {
        Storage.setValue(fixedKey, originalFixed);
    }
    return disabledColor == Theme.TEXT_DISABLED && blockedToggle && blockedAdjustment &&
        taxBlockedWithoutNetwork && enabled && switchedOff;
}

(:test)
function testNetworkToggleDoesNotDisableTaxes(logger) {
    var key = "tibber_network_fees_enabled";
    var originalValue = Storage.getValue(key);
    Storage.setValue(key, false);
    var widget = new SettingsScrollTestWidget();
    var view = new TibberWidgetSettingsView(widget, null, null, null);
    var dc = new SettingsScrollTestDc(280);
    view.onUpdate(dc);
    view.moveSelection(1);
    view.moveSelection(1);
    view.onUpdate(dc);
    view.selectCurrentOption();
    var enabled = Storage.getValue(key) == true && widget.priceType.equals("TOTAL");
    view.selectCurrentOption();
    var disabled = Storage.getValue(key) == false && widget.priceType.equals("TOTAL");
    view.selectOptionAt(250, 140);
    view.onUpdate(dc);
    var touched = Storage.getValue(key) == true && widget.priceType.equals("TOTAL");
    view.selectOptionAt(250, 69);
    var headerIgnored = Storage.getValue(key) == true && widget.priceType.equals("TOTAL");
    if (originalValue == null) {
        Storage.deleteValue(key);
    } else {
        Storage.setValue(key, originalValue);
    }
    return enabled && disabled && touched && headerIgnored;
}