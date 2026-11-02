import Toybox.Lang;

// Store builds (monkey-release.jungle) use this stub instead of the local,
// git-ignored token class so no personal token is ever shipped.
class TibberSecrets {
    static function getApiToken() as String {
        return "";
    }
}
