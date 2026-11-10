import Toybox.Lang;

/**
 * Coarse screen-size class used to trim or enlarge UI elements.
 * Classified by the shorter display side so square and round screens agree.
 *   LOW  < 250 px  (218/240 MIP, e.g. fenix 5 Plus, fenix 7S)
 *   MID  250-300   (260/280 MIP, e.g. fenix 7, fenix 7X)
 *   HIGH > 300     (320+ AMOLED, e.g. venu, vivoactive 5/6, fenix 8 AMOLED)
 */
class TibberScreenTier {
    static const LOW = 0;
    static const MID = 1;
    static const HIGH = 2;

    static const LOW_BELOW = 250;
    static const MID_BELOW = 300;

    /** Classify a display by its pixel dimensions. */
    static function forSize(width, height) {
        var shortSide = width < height ? width : height;
        if (shortSide < LOW_BELOW) {
            return LOW;
        }
        return shortSide < MID_BELOW ? MID : HIGH;
    }

    /** Classify the drawing surface a view is rendering to. */
    static function forDc(deviceContext) {
        return forSize(deviceContext.getWidth(), deviceContext.getHeight());
    }
}
