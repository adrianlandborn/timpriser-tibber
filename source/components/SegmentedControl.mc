import Toybox.Graphics;

class TibberSegmentedControl {
    private const SIDE_INSET = 16;
    private const TRACK_INSET = 2;
    private const SEGMENT_GAP = 2;

    function draw(dc, left, top, width, height, firstLabel, secondLabel, selectedIndex, font) {
        var outerRadius = height / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.fillRectangle(left + outerRadius, top, width - height, height);
        dc.fillCircle(left + outerRadius, top + outerRadius, outerRadius);
        dc.fillCircle(left + width - outerRadius, top + outerRadius, outerRadius);

        var innerLeft = left + TRACK_INSET;
        var innerTop = top + TRACK_INSET;
        var innerHeight = height - TRACK_INSET * 2;
        var innerWidth = width - TRACK_INSET * 2;
        var segmentWidth = (innerWidth - SEGMENT_GAP) / 2;
        drawSegment(dc, innerLeft, innerTop, segmentWidth, innerHeight, firstLabel, selectedIndex == 0, font);
        drawSegment(dc, innerLeft + segmentWidth + SEGMENT_GAP, innerTop, segmentWidth, innerHeight, secondLabel, selectedIndex == 1, font);
    }

    function getIndexAt(x, left, width) {
        return x < left + width / 2 ? 0 : 1;
    }

    private function drawSegment(dc, left, top, width, height, label, isActive, font) {
        var textColor = isActive ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        if (isActive) {
            var radius = height / 2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
            dc.fillRectangle(left + radius, top, width - height, height);
            dc.fillCircle(left + radius, top + radius, radius);
            dc.fillCircle(left + width - radius, top + radius, radius);
        }
        dc.setColor(textColor, isActive ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY);
        dc.drawText(left + width / 2, top + height / 2, font, label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}