import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class TibberWidgetSettingsView extends WatchUi.View {
    private const HEADER_HEIGHT = 54;
    private const HEADER_TOP_INSET = 20;
    private const VERTICAL_INSET = 26;
    private const SECTION_GAP = 10;
    private const OPTION_ROW_HEIGHT = 60;
    private const RESOLUTION_ROW_HEIGHT = 44;
    private const SELECTION_SIDE_INSET = 16;
    private const FOCUS_LINE_X = 8;
    private var _widgetView;
    private var _priceToggle;
    private var _resolutionControl;
    private var _fontCaption;
    private var _fontOption;
    private var _selectedOption;
    private var _screenHeight;
    private var _screenWidth;
    private var _scrollOffset;

    function initialize(widgetView, tinyFont, smallFont) {
        View.initialize();
        _widgetView = widgetView;
        _priceToggle = new TibberSettingsToggle();
        _resolutionControl = new TibberSegmentedControl();
        _fontCaption = tinyFont;
        _fontOption = smallFont;
        _selectedOption = 0;
        _screenHeight = 0;
        _screenWidth = 0;
        _scrollOffset = 0;
    }

    function onUpdate(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();
        _screenHeight = height;
        _screenWidth = width;
        clampScrollOffset();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        drawCenteredRow(dc, width, VERTICAL_INSET + HEADER_TOP_INSET, "INSTÄLLNINGAR", _fontOption);
        var priceRowTop = VERTICAL_INSET + HEADER_HEIGHT - _scrollOffset;
        _priceToggle.draw(
            dc,
            width,
            priceRowTop,
            OPTION_ROW_HEIGHT,
            "Skatter & avgifter",
            _widgetView.getCurrentPriceType().equals("TOTAL"),
            _selectedOption == 0,
            _fontOption,
            _fontCaption
        );
        var resolutionRowTop = priceRowTop + OPTION_ROW_HEIGHT + SECTION_GAP;
        drawResolutionControl(dc, width, resolutionRowTop);
    }

    function moveSelection(direction) {
        _selectedOption = (_selectedOption + direction + 2) % 2;
        scrollSelectionIntoView();
        WatchUi.requestUpdate();
        return true;
    }

    function selectCurrentOption() {
        applyOption(_selectedOption);
        return true;
    }

    function selectOptionAt(x, y) {
        var bodyY = y - (VERTICAL_INSET + HEADER_HEIGHT) + _scrollOffset;
        if (bodyY >= getPriceRowTop() && bodyY < getPriceRowTop() + OPTION_ROW_HEIGHT) {
            applyOption(0);
        }

        var resolutionRowTop = getResolutionRowTop();
        if (bodyY >= resolutionRowTop && bodyY < resolutionRowTop + RESOLUTION_ROW_HEIGHT) {
            var selectedIndex = _resolutionControl.getIndexAt(x, SELECTION_SIDE_INSET, _screenWidth - SELECTION_SIDE_INSET * 2);
            setResolutionForIndex(selectedIndex);
        }
        return true;
    }

    private function applyOption(option) {
        _selectedOption = option;
        if (option == 0) {
            var nextPriceType = _widgetView.getCurrentPriceType().equals("SPOT") ? "TOTAL" : "SPOT";
            _widgetView.setCurrentPriceType(nextPriceType);
        } else {
            var nextResolution = _widgetView.getCurrentPriceResolution().equals("HOURLY") ? "QUARTER_HOURLY" : "HOURLY";
            _widgetView.setCurrentPriceResolution(nextResolution);
        }
        WatchUi.requestUpdate();
    }

    private function drawCenteredRow(dc, width, y, label, font) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(width / 2, y, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawResolutionControl(dc, width, top) {
        if (_selectedOption == 1) {
            drawFocusLine(dc, top, RESOLUTION_ROW_HEIGHT);
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
        return HEADER_HEIGHT + OPTION_ROW_HEIGHT + SECTION_GAP + RESOLUTION_ROW_HEIGHT;
    }

    private function getPriceRowTop() {
        return 0;
    }

    private function getResolutionRowTop() {
        return OPTION_ROW_HEIGHT + SECTION_GAP;
    }

    private function getOptionTop(option) {
        if (option == 0) {
            return getPriceRowTop();
        }

        return getResolutionRowTop();
    }

    private function getOptionHeight(option) {
        return option == 0 ? OPTION_ROW_HEIGHT : RESOLUTION_ROW_HEIGHT;
    }

    private function scrollSelectionIntoView() {
        var viewportHeight = _screenHeight - VERTICAL_INSET * 2 - HEADER_HEIGHT;
        var optionTop = getOptionTop(_selectedOption);
        if (optionTop < _scrollOffset) {
            _scrollOffset = optionTop;
        } else if (optionTop + getOptionHeight(_selectedOption) > _scrollOffset + viewportHeight) {
            _scrollOffset = optionTop + getOptionHeight(_selectedOption) - viewportHeight;
        }
        clampScrollOffset();
    }

    private function clampScrollOffset() {
        var viewportHeight = _screenHeight - VERTICAL_INSET * 2;
        var maximumScroll = getContentHeight() - viewportHeight;
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