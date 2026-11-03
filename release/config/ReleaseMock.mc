import Toybox.Lang;

// Store builds (monkey-release.jungle) use this stub instead of source/mock/TibberMock.mc,
// so no mock data or mock token handling ships to users.
class TibberMock {
    static function isMockToken(token) as Boolean {
        return false;
    }

    static function bypassCache() as Boolean {
        return false;
    }

    static function buildResponse(token, requestKind, priceResolution, includeTomorrow) {
        return null;
    }
}
