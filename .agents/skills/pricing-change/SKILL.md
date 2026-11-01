---
name: pricing-change
description: "Safely change price calculation, VAT, network fees, energy tax, price resolution or price caching. Use when: editing source/network/PriceCache.mc or ApiClient.mc, changing fee/tax defaults, totals, rounding, hourly averaging, QUARTER_HOURLY/HOURLY handling, or anything that alters a displayed price."
---

# Pricing changes

Prices are user-facing money values. A silent regression is worse than a crash.

## Where the math lives

- `source/network/PriceCache.mc`: `getNetworkFee` (fixed + spot incl. 25% VAT × variable % + energy tax), `getDisplayPrice`, `getEnergyTax`, `getFixedNetworkFee`, `getVariableNetworkFee`, cache read/write. Storage keys: `tibber_energy_tax_ore`, `tibber_network_fixed_ore`, `tibber_network_variable_percent`, `tibber_network_fees_enabled`, `tibber_price_type`. Defaults: 45 öre tax, 20 öre fixed, 5% variable.
- `source/network/ApiClient.mc`: GraphQL queries, response parsing, hourly spot averages.
- Behavior spec: README sections "Energy tax and network fees" and "Pricing regression baseline". Read those sections only, not the whole README.

## Invariants (do not break without explicit user approval)

1. `final total = Tibber total + fixed fee + variable fee + configured energy tax`, only when network fees are enabled.
2. VAT (25%) is applied once, to the spot basis of the variable fee only.
3. Spot-only prices are never modified.
4. Quarter-hour totals with fees need the hourly spot average; if it's missing, return `null` instead of guessing.
5. `testConfirmedTibberPriceBaseline` expected values (272.50 / 265.00 / 260.50 / 227.50) must still pass unchanged.

## Procedure

1. Write or extend a `(:test)` case in `source/tests/NetworkFeeDetailTest.mc` that captures the intended behavior before changing code. Save and restore every `Storage` key you touch.
2. Make the change in `PriceCache`/`ApiClient`. Keep units explicit in names (`Ore`, `ExcludingVat`).
3. Run `scripts/test.sh testConfirmedTibberPriceBaseline`, then `scripts/check.sh full`.
4. If the formula, defaults, or tax year changed, update both README pricing sections and the baseline table. Never change expected baseline numbers just to make a test pass; ask first.
