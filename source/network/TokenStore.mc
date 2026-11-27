import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Lang;

(:background)
class TibberTokenStore {
    /** Storage copy of the local development token (TibberSecrets) for the background fetch. */
    private static const DEV_TOKEN_KEY = "tibber_dev_token";

    /** Trim a raw settings value; return "" unless it is a non-blank String. */
    static function normalize(value) as String {
        if (!(value instanceof String)) {
            return "";
        }
        var text = value as String;
        var start = 0;
        var end = text.length();
        while (start < end && isBlank(text.substring(start, start + 1))) {
            start++;
        }
        while (end > start && isBlank(text.substring(end - 1, end))) {
            end--;
        }
        return text.substring(start, end) as String;
    }

    /** Cheap sanity check: long enough and no whitespace inside (typical copy/paste mistakes). */
    static function looksValid(token as String) as Boolean {
        if (token.length() < 16) {
            return false;
        }
        for (var i = 0; i < token.length(); i++) {
            if (isBlank(token.substring(i, i + 1))) {
                return false;
            }
        }
        return true;
    }

    /** Token from the app settings only. Safe in background scope (no TibberSecrets access). */
    static function getSettingsToken() as String {
        try {
            return normalize(Application.Properties.getValue("tibberToken"));
        } catch (e) {
            return "";
        }
    }

    /**
     * Token for the background fetch: the app setting, else the development token that the
     * foreground mirrored into Storage (TibberSecrets itself is not reachable in background scope).
     */
    static function getBackgroundToken() as String {
        var token = getSettingsToken();
        if (token.length() == 0) {
            token = normalize(Storage.getValue(DEV_TOKEN_KEY));
        }
        return token;
    }

    /** App-settings token first, then the local development fallback. Foreground only. */
    static function getApiToken() as String {
        var token = getSettingsToken();
        var devToken = "";
        if (token.length() == 0) {
            devToken = normalize(TibberSecrets.getApiToken());
            token = devToken;
        }
        mirrorDevToken(devToken);
        return token;
    }

    /**
     * Keep the Storage copy of the development token in sync for the background fetch. Store builds
     * return "" from TibberSecrets, so there the copy is never written (and any stale one is removed).
     */
    private static function mirrorDevToken(devToken as String) as Void {
        try {
            var stored = Storage.getValue(DEV_TOKEN_KEY);
            if (devToken.length() == 0) {
                if (stored != null) {
                    Storage.deleteValue(DEV_TOKEN_KEY);
                }
            } else if (!(stored instanceof String) || !(stored as String).equals(devToken)) {
                Storage.setValue(DEV_TOKEN_KEY, devToken);
            }
        } catch (e) {
        }
    }

    private static function isBlank(character) as Boolean {
        return character.equals(" ") || character.equals("\n") || character.equals("\r") || character.equals("\t");
    }
}
