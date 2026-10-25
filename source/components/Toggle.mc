import Toybox.Graphics;
import Toybox.Lang;

class Toggle {
    private const LABEL_X = 24;
    private const LABEL_GAP = 8;
    private const RIGHT_INSET = 16;
    private const FOCUS_LINE_X = 8;
    private const WIDTH = 44;
    private const HEIGHT = 20;
    private var _isEnabled = true;

    function setEnabled(isEnabled) {
        _isEnabled = isEnabled;
    }

    function draw(dc, width, top, rowHeight, label, isOn, isSelected, optionFont, captionFont) {
        var backgroundColor = Graphics.COLOR_BLACK;
        var textColor = _isEnabled ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY;
        var trackColor = !_isEnabled ? Graphics.COLOR_DK_GRAY : (isOn ? Graphics.COLOR_BLUE : Graphics.COLOR_LT_GRAY);
        var trackLeft = width - WIDTH - RIGHT_INSET;
        var trackTop = top + (rowHeight - HEIGHT) / 2;
        var radius = HEIGHT / 2;

        if (isSelected) {
            dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
            dc.setPenWidth(3);
            dc.drawLine(FOCUS_LINE_X, top + 8, FOCUS_LINE_X, top + rowHeight - 8);
            dc.setPenWidth(1);
        }

        dc.setColor(textColor, backgroundColor);
        var labelFont = optionFont;
        var availableLabelWidth = trackLeft - LABEL_X - LABEL_GAP;
        if (dc.getTextWidthInPixels(label, labelFont) > availableLabelWidth) {
            labelFont = captionFont;
        }
        dc.drawText(LABEL_X, top + rowHeight / 2, labelFont, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(trackColor, backgroundColor);
        dc.fillRectangle(trackLeft + radius, trackTop, WIDTH - HEIGHT, HEIGHT);
        dc.fillCircle(trackLeft + radius, trackTop + radius, radius);
        dc.fillCircle(trackLeft + WIDTH - radius, trackTop + radius, radius);

        var thumbX = isOn ? trackLeft + WIDTH - radius : trackLeft + radius;
        dc.setColor(_isEnabled ? Graphics.COLOR_WHITE : Graphics.COLOR_LT_GRAY, trackColor);
        dc.fillCircle(thumbX, trackTop + radius, radius - 3);
    }
}