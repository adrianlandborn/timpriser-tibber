import Toybox.Graphics;

/**
 * Design tokens for the app. Raw palette values come first; screens and
 * components should only use the semantic tokens below them.
 */
module Theme {
    // Palette
    const PALETTE_BLACK = Graphics.COLOR_BLACK;
    const PALETTE_WHITE = Graphics.COLOR_WHITE;
    const PALETTE_GRAY_LIGHT = Graphics.COLOR_LT_GRAY;
    const PALETTE_GRAY_DARK = Graphics.COLOR_DK_GRAY;
    const PALETTE_BLUE = Graphics.COLOR_BLUE;
    const PALETTE_BLUE_MUTED = 0x2A55AA;
    const PALETTE_ORANGE = Graphics.COLOR_ORANGE;
    const PALETTE_ORANGE_MUTED = 0xAA5500;

    // Surfaces
    const BACKGROUND = PALETTE_BLACK;
    const SURFACE_TRACK = PALETTE_GRAY_DARK;

    // Text
    const TEXT_PRIMARY = PALETTE_WHITE;
    const TEXT_SECONDARY = PALETTE_GRAY_LIGHT;
    const TEXT_DISABLED = PALETTE_GRAY_DARK;
    const TEXT_ON_LIGHT = PALETTE_BLACK;

    // Interactive
    const ACCENT = PALETTE_BLUE;
    const FOCUS = PALETTE_BLUE;
    const TOGGLE_ON = PALETTE_BLUE;
    const TOGGLE_OFF = PALETTE_GRAY_LIGHT;
    const TOGGLE_DISABLED = PALETTE_GRAY_DARK;
    const SEGMENT_ACTIVE = PALETTE_WHITE;

    // Chart
    const CHART_AXIS = PALETTE_GRAY_LIGHT;
    const CHART_AVERAGE = PALETTE_GRAY_LIGHT;
    const CHART_MARKER = PALETTE_ORANGE;
    const CHART_MARKER_OUTLINE = PALETTE_WHITE;
    const CHART_DEFAULT_LINE = PALETTE_BLUE;

    // Price levels, from very cheap (1) to very expensive (5)
    const LEVEL_1 = PALETTE_BLUE;
    const LEVEL_2 = PALETTE_BLUE_MUTED;
    const LEVEL_3 = PALETTE_GRAY_DARK;
    const LEVEL_4 = PALETTE_ORANGE_MUTED;
    const LEVEL_5 = PALETTE_ORANGE;

    // Spacing and shape
    const SPACE_SIDE_INSET = 16;
    const SPACE_LABEL_X = 24;
    const FOCUS_BAR_X = 8;
    const FOCUS_BAR_INSET = 8;
    const FOCUS_BAR_WIDTH = 3;
    const ROW_HEIGHT = 60;
}
