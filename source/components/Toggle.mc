import Toybox.Graphics;
import Toybox.Lang;

class Toggle {
    private const LABEL_X = Theme.SPACE_LABEL_X;
    private const LABEL_GAP = 8;
    private const RIGHT_INSET = Theme.SPACE_SIDE_INSET;
    private const FOCUS_LINE_X = Theme.FOCUS_BAR_X;
    private const WIDTH = 44;
    private const HEIGHT = 20;
    private var _isEnabled = true;

    function setEnabled(isEnabled) {
        _isEnabled = isEnabled;
    }

    function draw(dc, width, top, rowHeight, label, isOn, isSelected, optionFont, captionFont) {
        var backgroundColor = Theme.BACKGROUND;
        var textColor = _isEnabled ? Theme.TEXT_PRIMARY : Theme.TEXT_DISABLED;
        var trackColor = !_isEnabled ? Theme.TOGGLE_DISABLED : (isOn ? Theme.TOGGLE_ON : Theme.TOGGLE_OFF);
        var trackLeft = width - WIDTH - RIGHT_INSET;
        var trackTop = top + (rowHeight - HEIGHT) / 2;
        var radius = HEIGHT / 2;

        if (isSelected) {
            dc.setColor(Theme.FOCUS, Theme.BACKGROUND);
            dc.setPenWidth(Theme.FOCUS_BAR_WIDTH);
            dc.drawLine(FOCUS_LINE_X, top + Theme.FOCUS_BAR_INSET, FOCUS_LINE_X, top + rowHeight - Theme.FOCUS_BAR_INSET);
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
        dc.setColor(_isEnabled ? Theme.TEXT_PRIMARY : Theme.TEXT_SECONDARY, trackColor);
        dc.fillCircle(thumbX, trackTop + radius, radius - 3);
    }
}