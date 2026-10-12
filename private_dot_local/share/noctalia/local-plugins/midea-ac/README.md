# Midea AC (local)

Bar widget and panel for the Midea air conditioner exposed by the `midea_ac`
Home Assistant integration on jackdaw.

- **Widget**: mode glyph and room temperature; red while Turbo is on.
  Left-click opens the panel, right-click toggles power.
- **Panel**: power, target temperature, mode, preset (Normal / Eco / Sleep /
  Turbo), fan speed, swing, display and purifier switches.

Turbo is Home Assistant's `boost` preset; `midea_ac` only offers it in Cool
and Auto, so the button disappears in Dry and Fan.

Settings: `ha_url`, `ha_token` (long-lived access token), and the entity IDs
(defaults match `climate.adryan_ac` and its `adryan_ac_*` companions).
