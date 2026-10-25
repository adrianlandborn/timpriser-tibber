import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
import Toybox.Application.Storage;

class TibberWidgetSettingsView extends WatchUi.View {
    private const HEADER_HEIGHT = 54;
    private const HEADER_TOP_INSET = 20;
    private const VERTICAL_INSET = 26;
    private const SECTION_GAP = 10;
    private const OPTION_ROW_HEIGHT = 60;
    private const FEE_ROW_HEIGHT = 60;
    private const RESOLUTION_ROW_HEIGHT = 44;
    private const SELECTION_SIDE_INSET = 16;
    private const FEE_LABEL_X = 24;
    private const FEE_VALUE_RIGHT_INSET = 24;
    private const FOCUS_LINE_X = 8;
    private const OPTION_COUNT = 6;

    private var _widgetView;
    private var _priceToggle;
    private var _resolutionControl;
    private var _fontCaption;
    private var _fontOption;
    private var _fontDisplay;
    private var _selectedOption;
    private var _optionOrder;
    private var _screenHeight;
    private var _screenWidth;
    private var _scrollOffset;

    function initialize(widgetView, tinyFont, smallFont, displayFont) {
        View.initialize();
        _widgetView = widgetView;
        _priceToggle = new Toggle();
        _resolutionControl = new TibberSegmentedControl();
        _fontCaption = tinyFont;
        _fontOption = smallFont;
        _fontDisplay = displayFont;
        _optionOrder = [4, 0, 1, 2, 3, 5];
        _selectedOption = _optionOrder[0];
        _screenHeight = 0;
        _screenWidth = 0;
        _scrollOffset = 0;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        _screenHeight = height;
        _screenWidth = width;
        scrollSelectionIntoView();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        drawCenteredRow(dc, width, VERTICAL_INSET + HEADER_TOP_INSET, "INSTÄLLNINGAR", _fontOption);
        var bodyTop = VERTICAL_INSET + HEADER_HEIGHT - SECTION_GAP;
        dc.setClip(0, bodyTop, width, height - bodyTop);
        var rowsTop = getListTop() - _scrollOffset;
        var taxesIncluded = _widgetView.getCurrentPriceType().equals("TOTAL");
        _priceToggle.setEnabled(true);
        _priceToggle.draw(dc, width, rowsTop + getOptionTop(0), OPTION_ROW_HEIGHT,
            "Skatter & avgifter", taxesIncluded, _selectedOption == 0,
            _fontOption, _fontCaption);

        var networkFeesIncluded = getNetworkFeesIncluded();
        _priceToggle.setEnabled(taxesIncluded);
        _priceToggle.draw(dc, width, rowsTop + getOptionTop(1), OPTION_ROW_HEIGHT,
            "Nätavgifter (beta)", networkFeesIncluded, _selectedOption == 1, _fontOption, _fontCaption);

        drawFeeOption(dc, width, rowsTop + getOptionTop(2), 2, "Fast nätavgift",
            getFixedNetworkFee().format("%.0f") + " öre", networkFeesIncluded);
        drawFeeOption(dc, width, rowsTop + getOptionTop(3), 3, "Rörlig nätavgift",
            getVariableNetworkFee().format("%.0f") + "%", networkFeesIncluded);
        drawResolutionControl(dc, width, rowsTop + getOptionTop(4));
        var energyTax = new TibberPriceCache();
        drawFeeOption(dc, width, rowsTop + getOptionTop(5), 5, "Energiskatt",
            energyTax.getEnergyTax().format("%.0f") + " öre", networkFeesIncluded);
        dc.clearClip();
    }

    function moveSelection(direction) {
        for (var index = 0; index < OPTION_COUNT; index += 1) {
            if (_optionOrder[index] == _selectedOption) {
                _selectedOption = _optionOrder[(index + direction + OPTION_COUNT) % OPTION_COUNT];
                break;
            }
        }
        scrollSelectionIntoView();
        WatchUi.requestUpdate();
        return true;
    }

    function selectCurrentOption() {
        applyOption(_selectedOption);
        return true;
    }

    function selectOptionAt(x, y) {
        var bodyTop = VERTICAL_INSET + HEADER_HEIGHT - SECTION_GAP;
        if (x < 0 || x >= _screenWidth || y < bodyTop || y >= _screenHeight) {
            return true;
        }
        var bodyY = y - getListTop() + _scrollOffset;
        for (var option = 0; option < OPTION_COUNT; option++) {
            var optionTop = getOptionTop(option);
            if (bodyY >= optionTop && bodyY < optionTop + getOptionHeight(option)) {
                _selectedOption = option;
                if (option == 4) {
                    var selectedIndex = _resolutionControl.getIndexAt(x, SELECTION_SIDE_INSET, _screenWidth - SELECTION_SIDE_INSET * 2);
                    setResolutionForIndex(selectedIndex);
                } else {
                    applyOption(option);
                }
                return true;
            }
        }
        return true;
    }

    private function applyOption(option) {
        _selectedOption = option;
        if (option == 0) {
            var nextPriceType = _widgetView.getCurrentPriceType().equals("SPOT") ? "TOTAL" : "SPOT";
            if (nextPriceType.equals("SPOT")) {
                Storage.setValue("tibber_network_fees_enabled", false);
            }
            _widgetView.setCurrentPriceType(nextPriceType);
        } else if (option == 1) {
            if (_widgetView.getCurrentPriceType().equals("TOTAL")) {
                Storage.setValue("tibber_network_fees_enabled", !getNetworkFeesIncluded());
            }
        } else if (option == 2 || option == 3) {
            if (getNetworkFeesIncluded()) {
                openNetworkFeeDetails(option);
            }
        } else if (option == 5) {
            if (getNetworkFeesIncluded()) {
                openNetworkFeeDetails(option);
            }
        } else {
            var nextResolution = _widgetView.getCurrentPriceResolution().equals("HOURLY") ? "QUARTER_HOURLY" : "HOURLY";
            _widgetView.setCurrentPriceResolution(nextResolution);
        }
        WatchUi.requestUpdate();
    }

    function openSelectedNetworkFeeDetails() {
        if (getNetworkFeesIncluded() && (_selectedOption == 2 || _selectedOption == 3)) {
            openNetworkFeeDetails(_selectedOption);
        } else if (_selectedOption == 5 && getNetworkFeesIncluded()) {
            openNetworkFeeDetails(_selectedOption);
        }
        return true;
    }

    private function openNetworkFeeDetails(feeOption) {
        var detailView = new TibberNetworkFeeDetailView(feeOption, _fontCaption, _fontOption, _fontDisplay);
        var detailDelegate = new TibberNetworkFeeDetailDelegate(detailView);
        WatchUi.pushView(detailView, detailDelegate, WatchUi.SLIDE_UP);
    }

    function adjustNetworkFee(feeOption, direction) {
        if (!getNetworkFeesIncluded()) {
            return true;
        }
        if (feeOption == 2) {
            var fixedFee = getFixedNetworkFee() + direction;
            if (fixedFee < 0) {
                fixedFee = 0;
            } else if (fixedFee > 1000) {
                fixedFee = 1000;
            }
            Storage.setValue("tibber_network_fixed_ore", fixedFee);
        } else if (feeOption == 3) {
            var variableFee = getVariableNetworkFee() + direction;
            if (variableFee < 0) {
                variableFee = 0;
            } else if (variableFee > 100) {
                variableFee = 100;
            }
            Storage.setValue("tibber_network_variable_percent", variableFee);
        }
        WatchUi.requestUpdate();
        return true;
    }

    private function drawCenteredRow(dc, width, y, label, font) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, y, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawFeeOption(dc, width, top, option, label, value, isEnabled) {
        if (_selectedOption == option) {
            drawFocusLine(dc, top, FEE_ROW_HEIGHT);
        }

        var textColor = isEnabled ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY;
        dc.setColor(textColor, Graphics.COLOR_BLACK);
        dc.drawText(SELECTION_SIDE_INSET + 8, top + FEE_ROW_HEIGHT / 2, _fontCaption, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(width - SELECTION_SIDE_INSET - 8, top + FEE_ROW_HEIGHT / 2, _fontCaption, value + "  >", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function getNetworkFeesIncluded() {
        return _widgetView.getCurrentPriceType().equals("TOTAL") && Storage.getValue("tibber_network_fees_enabled") == true;
    }

    private function getFixedNetworkFee() {
        var fee = Storage.getValue("tibber_network_fixed_ore");
        return (fee instanceof Number || fee instanceof Float) ? fee : 20.0;
    }

    private function getVariableNetworkFee() {
        var fee = Storage.getValue("tibber_network_variable_percent");
        return (fee instanceof Number || fee instanceof Float) ? fee : 5.0;
    }

    private function drawResolutionControl(dc, width, top) {
        if (_selectedOption == 4) {
            drawFocusLine(dc, top + (RESOLUTION_ROW_HEIGHT - OPTION_ROW_HEIGHT) / 2, OPTION_ROW_HEIGHT);
        }
        var selectedIndex = _widgetView.getCurrentPriceResolution().equals("QUARTER_HOURLY") ? 0 : 1;
        _resolutionControl.draw(
            dc,
            SELECTION_SIDE_INSET,
            top,
            width - SELECTION_SIDE_INSET * 2,
            RESOLUTION_ROW_HEIGHT,
            "15 min",
            "1 timme",
            selectedIndex,
            _fontOption
        );
    }

    private function drawFocusLine(dc, top, height) {
        dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
        dc.setPenWidth(3);
        dc.drawLine(FOCUS_LINE_X, top + 8, FOCUS_LINE_X, top + height - 8);
        dc.setPenWidth(1);
    }

    private function setResolutionForIndex(selectedIndex) {
        _widgetView.setCurrentPriceResolution(selectedIndex == 0 ? "QUARTER_HOURLY" : "HOURLY");
        WatchUi.requestUpdate();
    }

    private function getContentHeight() {
        var lastOption = OPTION_COUNT - 1;
        var lastHeight = getOptionHeight(lastOption);
        var bottomPadding = (_screenHeight - lastHeight) / 2;
        return getListTop() + getOptionTop(lastOption) + lastHeight + bottomPadding;
    }

    private function getListTop() {
        return (_screenHeight - RESOLUTION_ROW_HEIGHT) / 2;
    }

    private function getPriceRowTop() {
        return RESOLUTION_ROW_HEIGHT + SECTION_GAP;
    }

    private function getResolutionRowTop() {
        return 0;
    }

    private function getOptionTop(option) {
        if (option == 4) {
            return getResolutionRowTop();
        }
        var rowIndex = option == 5 ? 4 : option;
        return getPriceRowTop() + rowIndex * (OPTION_ROW_HEIGHT + SECTION_GAP);
    }

    private function getOptionHeight(option) {
        return option == 4 ? RESOLUTION_ROW_HEIGHT : (option == 2 || option == 3 ? FEE_ROW_HEIGHT : OPTION_ROW_HEIGHT);
    }

    private function scrollSelectionIntoView() {
        _scrollOffset = getListTop() + getOptionTop(_selectedOption) +
            getOptionHeight(_selectedOption) / 2 - _screenHeight / 2;
        clampScrollOffset();
    }

    private function clampScrollOffset() {
        var maximumScroll = getContentHeight() - _screenHeight;
        if (maximumScroll < 0) {
            maximumScroll = 0;
        }
        if (_scrollOffset < 0) {
            _scrollOffset = 0;
        } else if (_scrollOffset > maximumScroll) {
            _scrollOffset = maximumScroll;
        }
    }
}