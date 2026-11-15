import Toybox.Test;

(:test)
function testTokenStoreNormalize(logger) {
    Test.assertEqual(TibberTokenStore.normalize(null), "");
    Test.assertEqual(TibberTokenStore.normalize(42), "");
    Test.assertEqual(TibberTokenStore.normalize("   \n"), "");
    Test.assertEqual(TibberTokenStore.normalize(" abc-DEF_1.2 \r\n"), "abc-DEF_1.2");
    return true;
}

(:test)
function testTokenStoreLooksValid(logger) {
    Test.assertEqual(TibberTokenStore.looksValid("abc"), false);
    Test.assertEqual(TibberTokenStore.looksValid("abcdefgh ijklmnopqrst"), false);
    Test.assertEqual(TibberTokenStore.looksValid("abcdefghijklmnopqrstuvwxyz-_1234567890"), true);
    return true;
}
