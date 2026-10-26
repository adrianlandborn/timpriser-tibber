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
        var dailyPrices = readDailyPrices(priceResolution, includeTomorrow, true, true);
        if (dailyPrices == null && includeTomorrow) {
            dailyPrices = readDailyPrices(priceResolution, false, true, true);
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
            Storage.setValue(prefix + "l", getStringValue(priceData.get("hour_levels")));
            Storage.setValue(prefix + "r", true);
        } catch (ex) {
        }
    }

    function getDailyPrices(priceResolution, includeTomorrow, allowStaleTomorrow) {
        return readDailyPrices(priceResolution, includeTomorrow, allowStaleTomorrow, false);
    }

    /** Compact reads keep intervals as the flat stored array to save memory in the glance. */
    private function readDailyPrices(priceResolution, includeTomorrow, allowStaleTomorrow, compact) {
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
            if (!(flatIntervals instanceof Array) || (flatIntervals as Array).size() % 4 != 0 ||
                spanMinutes == null || resolutionMinutes == null || checkedMinute == null) {
                return null;
            }

            var intervals = flatIntervals as Array;
            if (!compact) {
                intervals = [];
                var values = flatIntervals as Array;
                for (var index = 0; index < values.size(); index += 4) {
                    intervals.add([values[index], values[index + 1], values[index + 2], values[index + 3]]);
                }
            }

            var currency = currencyValue instanceof String && (currencyValue as String).length() > 0 ? currencyValue : null;
            var data = {
                "resolution" => priceResolution,
                "resolution_minutes" => resolutionMinutes,
                "currency" => currency,
                "span_minutes" => spanMinutes,
                "tomorrow_available" => tomorrowAvailable == true,
                "intervals" => intervals,
                "flat" => compact
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
                    flatIntervals.add((interval as Array).size() >= 4 ? (interval as Array)[3] : 0);
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
            var hourLevels = Storage.getValue(prefix + "l");
            if (!(price instanceof String) || !(spotPrice instanceof String) || !(startTime instanceof String) || intervalMinutes == null) {
                return null;
            }

            var currency = currencyValue instanceof String && (currencyValue as String).length() > 0 ? currencyValue : null;
            return {
                "current_price" => price,
                "current_spot_price" => spotPrice,
                "current_time" => startTime,
                "currency" => currency,
                "hour_levels" => hourLevels,
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

        var flat = dailyPrices.get("flat") == true;
        var stride = flat ? 4 : 1;
        var nowMinute = getCurrentMinuteOfDay();
        var activeStartMinute = nowMinute - (nowMinute % intervalMinutes);
        var matchingPrice = null;
        var matchingSpot = null;
        var matchCount = 0;
        var hourStartMinute = nowMinute - (nowMinute % 60);
        var hourlySpotTotal = 0.0;
        var hourlySpotCount = 0;
        var levelSums = new [24];
        var levelCounts = new [24];
        for (var hour = 0; hour < 24; hour++) {
            levelSums[hour] = 0;
            levelCounts[hour] = 0;
        }
        var values = intervals as Array;
        for (var index = 0; index < values.size(); index += stride) {
            var startMinute;
            var price;
            var spot;
            var level;
            if (flat) {
                startMinute = values[index];
                price = values[index + 1];
                spot = values[index + 2];
                level = values[index + 3];
            } else {
                var interval = values[index];
                if (!(interval instanceof Array) || (interval as Array).size() < 3) {
                    continue;
                }
                startMinute = interval[0];
                price = interval[1];
                spot = interval[2];
                level = (interval as Array).size() >= 4 ? interval[3] : 0;
            }

            if (startMinute < 1440 && level > 0) {
                levelSums[startMinute / 60] += level;
                levelCounts[startMinute / 60] += 1;
            }
            if (startMinute >= hourStartMinute && startMinute < hourStartMinute + 60) {
                hourlySpotTotal += spot;
                hourlySpotCount += 1;
            }
            if (startMinute == activeStartMinute) {
                matchingPrice = price;
                matchingSpot = spot;
                matchCount++;
            }
        }

        if (matchCount != 1 || matchingPrice == null) {
            return null;
        }

        var hourLevels = "";
        for (var hour = 0; hour < 24; hour++) {
            var hourClass = "3";
            if (levelCounts[hour] > 0) {
                var averageLevel = levelSums[hour].toFloat() / levelCounts[hour];
                hourClass = (averageLevel + 0.5).toNumber().toString();
            }
            hourLevels += hourClass;
        }

        return {
            "hour_levels" => hourLevels,
            "current_price" => (matchingPrice as Float).format("%.0f"),
            "current_spot_price" => (matchingSpot as Float).format("%.0f"),
            "current_price_value" => matchingPrice,
            "current_spot_value" => matchingSpot,
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
        return "pd5" + resolutionKey + horizonKey;
    }

    private function getCurrentCachePrefix(priceResolution) {
        return "pc5" + (priceResolution.equals("HOURLY") ? "h" : "q");
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