# Home (local)

Home Assistant panel for the Noctalia bar, grouped by area. Replaces
`pozzoo/hassio`.

- **Widget**: house icon, highlighted with a count when anything is on;
  tooltip shows the priority room's temperature.
- **Panel**: one card per area, priority area first and expanded. Each card
  has a sensor strip (temperature, humidity, power, battery) and controls for
  lights (toggle + brightness), switches, fans, climate (power, target ±, and
  a button opening the AC panel), media players, covers and locks.

Areas and devices come from Home Assistant's area assignments; hidden
entities are skipped. Settings: `ha_url`, `ha_token`, `priority_area`
(area ID or name), `climate_panel`.
