import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

class TibberPriceCache {
    private const STANDARD_ENERGY_TAX_ORE = 45.0;

    function getEnergyTax() {
        return getStoredFee("tibber_energy_tax_ore", STANDARD_ENERGY_TAX_ORE);
    }

    function getPriceWithNetworkFees(tibberTotal, spotAverageExcludingVat) {
        return tibberTotal + getNetworkFee(spotAverageExcludingVat);
    }

    function getDisplayPrice(priceData, priceType) {
        var priceKey = priceType.equals("SPOT") ? "current_spot_price" : "current_price";
        var priceText = priceData.get(priceKey);
        if (!(priceText instanceof String) || !priceType.equals("TOTAL")) {
            return priceText;
        }

        var valueKey = priceType.equals("SPOT") ? "current_spot_value" : "current_price_value";
        var price = priceData.get(valueKey);
        if (!(price instanceof Number || price instanceof Float)) {
            price = priceText.toFloat();
        }
        if (Storage.getValue("tibber_network_fees_enabled") != true) {
            return price.format("%.0f");
        }
        var spotAverage = priceData.get("hourly_spot_average");
        if (!(spotAverage instanceof Number || spotAverage instanceof Float)) {
            var resolution = priceData.get("resolution");
            if (resolution instanceof String && resolution.equals("QUARTER_HOURLY")) {
                return null;
            }
            spotAverage = priceData.get("current_spot_price").toFloat();
        }
        return getPriceWithNetworkFees(price, spotAverage).format("%.0f");
    }

    function getNetworkFee(spotAverageExcludingVat) {
        var fixedFee = getStoredFee("tibber_network_fixed_ore", 20.0);
        var variablePercent = getStoredFee("tibber_network_variable_percent", 5.0);
        var spotIncludingVat = spotAverageExcludingVat * 1.25;
        return fixedFee + spotIncludingVat * variablePercent / 100 + getEnergyTax();
    }

    private function getStoredFee(key, fallbackValue) {
        var value = Storage.getValue(key);
        return (value instanceof Number || value instanceof Float) ? value : fallbackValue;
    }

    function getCurrentPrice(priceResolution) {
        var currentPrice = readCurrentPrice(priceResolution);
        var includeTomorrow = priceResolution.equals("HOURLY");
        var dailyPrices = getDailyPrices(priceResolution, includeTomorrow, true);
        if (dailyPrices == null && includeTomorrow) {
            dailyPrices = getDailyPrices(priceResolution, false, true);
        }
        if (dailyPrices == null) {
            var priceType = Storage.getValue("tibber_price_type");
            var spotOnly = priceType instanceof String && priceType.equals("SPOT");
            if (currentPrice != null && isCurrentPriceValid(currentPrice) &&
                (spotOnly || Storage.getValue("tibber_network_fees_enabled") != true || priceResolution.equals("HOURLY"))) {
                return currentPrice;
            }
            return null;
        }

        var derivedPrice = deriveCurrentPrice(dailyPrices, priceResolution);
        if (derivedPrice != null) {
            storeCurrentPrice(priceResolution, derivedPrice);
        }
        return derivedPrice;
    }

    function storeCurrentPrice(priceResolution, priceData) {
        var prefix = getCurrentCachePrefix(priceResolution);
        try {
            Storage.setValue(prefix + "r", false);
            Storage.setValue(prefix + "d", getDateKey());
            Storage.setValue(prefix + "p", priceData.get("current_price"));
            Storage.setValue(prefix + "e", getStringValue(priceData.get("current_spot_price")));
            Storage.setValue(prefix + "t", priceData.get("current_time"));
            Storage.setValue(prefix + "c", getStringValue(priceData.get("currency")));
            Storage.setValue(prefix + "i", priceData.get("interval_minutes"));
            Storage.setValue(prefix + "r", true);
        } catch (ex) {
        }
    }

    function getDailyPrices(priceResolution, includeTomorrow, allowStaleTomorrow) {
        var prefix = getDailyCachePrefix(priceResolution, includeTomorrow);
        try {
            var cacheReady = Storage.getValue(prefix + "r");
            var cachedDay = Storage.getValue(prefix + "d");
            var currentDay = getDateKey();
            if (cacheReady != true || !(cachedDay instanceof String) || !(cachedDay as String).equals(currentDay)) {
                return null;
            }

            var flatIntervals = Storage.getValue(prefix + "i");
            var spanMinutes = Storage.getValue(prefix + "s");
            var resolutionMinutes = Storage.getValue(prefix + "m");
            var currencyValue = Storage.getValue(prefix + "c");
            var tomorrowAvailable = Storage.getValue(prefix + "t");
            var checkedMinute = Storage.getValue(prefix + "n");
            if (!(flatIntervals instanceof Array) || (flatIntervals as Array).size() % 3 != 0 ||
                spanMinutes == null || resolutionMinutes == null || checkedMinute == null) {
                return null;
            }

            var intervals = [];
            var values = flatIntervals as Array;
            for (var index = 0; index < values.size(); index += 3) {
                intervals.add([values[index], values[index + 1], values[index + 2]]);
            }

            var currency = currencyValue instanceof String && (currencyValue as String).length() > 0 ? currencyValue : null;
            var data = {
                "resolution" => priceResolution,
                "resolution_minutes" => resolutionMinutes,
                "currency" => currency,
                "span_minutes" => spanMinutes,
                "tomorrow_available" => tomorrowAvailable == true,
                "intervals" => intervals
            };

            if (includeTomorrow && tomorrowAvailable != true && !isMissingTomorrowCacheFresh(checkedMinute) && !allowStaleTomorrow) {
                return null;
            }
            return data;
        } catch (ex) {
            return null;
        }
    }

    function storeDailyPrices(priceResolution, includeTomorrow, priceData) {
        var prefix = getDailyCachePrefix(priceResolution, includeTomorrow);
        try {
            var sourceIntervals = priceData.get("intervals");
            if (!(sourceIntervals instanceof Array)) {
                return;
            }

            var flatIntervals = [];
            for (var index = 0; index < (sourceIntervals as Array).size(); index++) {
                var interval = (sourceIntervals as Array)[index];
                if (interval instanceof Array && (interval as Array).size() >= 3) {
                    flatIntervals.add((interval as Array)[0]);
                    flatIntervals.add((interval as Array)[1]);
                    flatIntervals.add((interval as Array)[2]);
                }
            }

            Storage.setValue(prefix + "r", false);
            Storage.setValue(prefix + "d", getDateKey());
            Storage.setValue(prefix + "i", flatIntervals);
            Storage.setValue(prefix + "s", priceData.get("span_minutes"));
            Storage.setValue(prefix + "m", priceData.get("resolution_minutes"));
            Storage.setValue(prefix + "c", getStringValue(priceData.get("currency")));
            Storage.setValue(prefix + "t", priceData.get("tomorrow_available") == true);
            Storage.setValue(prefix + "n", getCurrentMinuteOfDay());
            Storage.setValue(prefix + "r", true);
        } catch (ex) {
        }
    }

    private function readCurrentPrice(priceResolution) {
        var prefix = getCurrentCachePrefix(priceResolution);
        try {
            var cacheReady = Storage.getValue(prefix + "r");
            var cachedDay = Storage.getValue(prefix + "d");
            var currentDay = getDateKey();
            if (cacheReady != true || !(cachedDay instanceof String) || !(cachedDay as String).equals(currentDay)) {
                return null;
            }

            var price = Storage.getValue(prefix + "p");
            var spotPrice = Storage.getValue(prefix + "e");
            var startTime = Storage.getValue(prefix + "t");
            var currencyValue = Storage.getValue(prefix + "c");
            var intervalMinutes = Storage.getValue(prefix + "i");
            if (!(price instanceof String) || !(spotPrice instanceof String) || !(startTime instanceof String) || intervalMinutes == null) {
                return null;
            }

            var currency = currencyValue instanceof String && (currencyValue as String).length() > 0 ? currencyValue : null;
            return {
                "current_price" => price,
                "current_spot_price" => spotPrice,
                "current_time" => startTime,
                "currency" => currency,
                "resolution" => priceResolution,
                "interval_minutes" => intervalMinutes
            };
        } catch (ex) {
            return null;
        }
    }

    private function isCurrentPriceValid(priceData) {
        var intervalMinutes = priceData.get("interval_minutes");
        var startTime = priceData.get("current_time");
        if (intervalMinutes == null || !(startTime instanceof String)) {
            return false;
        }

        var nowMinute = getCurrentMinuteOfDay();
        var activeStartMinute = nowMinute - (nowMinute % intervalMinutes);
        return formatMinuteOfDay(activeStartMinute).equals(startTime);
    }

    private function deriveCurrentPrice(dailyPrices, priceResolution) {
        var intervals = dailyPrices.get("intervals");
        var intervalMinutes = dailyPrices.get("resolution_minutes");
        if (!(intervals instanceof Array) || intervalMinutes == null) {
            return null;
        }

        var nowMinute = getCurrentMinuteOfDay();
        var activeStartMinute = nowMinute - (nowMinute % intervalMinutes);
        var matchingPrice = null;
        var matchCount = 0;
        var hourStartMinute = nowMinute - (nowMinute % 60);
        var hourlySpotTotal = 0.0;
        var hourlySpotCount = 0;
        for (var index = 0; index < (intervals as Array).size(); index++) {
            var interval = (intervals as Array)[index];
            if (interval instanceof Array && (interval as Array).size() >= 3 &&
                interval[0] >= hourStartMinute && interval[0] < hourStartMinute + 60) {
                hourlySpotTotal += interval[2];
                hourlySpotCount += 1;
            }
            if (interval instanceof Array && (interval as Array).size() >= 3 &&
                (interval as Array)[0] == activeStartMinute) {
                matchingPrice = (interval as Array)[1];
                var matchingSpotPrice = (interval as Array)[2];
                matchCount++;
                if (matchCount == 1) {
                    matchingPrice = [matchingPrice, matchingSpotPrice];
                }
            }
        }

        if (matchCount != 1 || matchingPrice == null) {
            return null;
        }

        return {
            "current_price" => (matchingPrice[0] as Float).format("%.0f"),
            "current_spot_price" => (matchingPrice[1] as Float).format("%.0f"),
            "current_price_value" => matchingPrice[0],
            "current_spot_value" => matchingPrice[1],
            "hourly_spot_average" => hourlySpotTotal / hourlySpotCount,
            "current_time" => formatMinuteOfDay(activeStartMinute),
            "currency" => dailyPrices.get("currency"),
            "resolution" => priceResolution,
            "interval_minutes" => intervalMinutes
        };
    }

    private function isMissingTomorrowCacheFresh(checkedMinute) {
        var ageMinutes = getCurrentMinuteOfDay() - checkedMinute;
        return ageMinutes >= 0 && ageMinutes < 180;
    }

    private function getDailyCachePrefix(priceResolution, includeTomorrow) {
        var resolutionKey = priceResolution.equals("HOURLY") ? "h" : "q";
        var horizonKey = includeTomorrow ? "t" : "d";
        return "pd3" + resolutionKey + horizonKey;
    }

    private function getCurrentCachePrefix(priceResolution) {
        return "pc3" + (priceResolution.equals("HOURLY") ? "h" : "q");
    }

    private function getDateKey() {
        var dateInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return dateInfo.year.toString() + "-" + dateInfo.month.toString() + "-" + dateInfo.day.toString();
    }

    private function getCurrentMinuteOfDay() {
        var timeInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        return timeInfo.hour * 60 + timeInfo.min;
    }

    private function formatMinuteOfDay(minuteOfDay) {
        return (minuteOfDay / 60).format("%02d") + ":" + (minuteOfDay % 60).format("%02d");
    }

    private function getStringValue(value) {
        return value instanceof String ? value : "";
    }
}