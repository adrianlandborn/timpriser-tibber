import Toybox.Application;
import Toybox.Lang;

class TibberTokenStore {
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

    /** App-settings token first, then the local development fallback. */
    static function getApiToken() as String {
        var token = "";
        try {
            token = normalize(Application.Properties.getValue("tibberToken"));
        } catch (e) {
            token = "";
        }
        if (token.length() == 0) {
            token = normalize(TibberSecrets.getApiToken());
        }
        return token;
    }

    private static function isBlank(character) as Boolean {
        return character.equals(" ") || character.equals("\n") || character.equals("\r") || character.equals("\t");
    }
}
