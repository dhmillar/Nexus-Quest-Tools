# NQTDB route data attribution and source

**Shortest Path Forever by cjber and contributors**, version 1.49.2, [source revision 9b0058a](https://github.com/cjber/shortest-path-forever/tree/9b0058ab4b8913196b8899d87952958e3f49bf24). The derived grid in `NQTDBRouteTiles.lua` is distributed under [GPL-3.0-or-later](RouteData.License.txt).

Corresponding input and build instructions:
- [Nav2991.lua](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/Nav/Nav2991.lua) (SHA-256 f1955bc5fd3012710248f9863d3def4b449ca7eb22ab0f2ca8d351469d33890a)
- [Nav2991_1.lua](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/Nav/Nav2991_1.lua) (SHA-256 c61c7cdf6bf438b250339823eb656b3f8381c693acac96b1737a3b336a47d470)
- Upstream [terrain bake and third-party attribution](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/THIRD_PARTY.md) and [baker source](https://github.com/cjber/shortest-path-forever/tree/9b0058ab4b8913196b8899d87952958e3f49bf24/tools/baker).
- From the tagged NQT repository, run `node tools/import-spf-grid.cjs <directory-containing-both-files> NQT/NQTDBRouteTiles.lua`.

The upstream files describe terrain baked from Forever build 71037 with TrinityCore e3916b2adcf2f8a70ae33817fc57b6c0266e2fb0. NQT keeps the dry base grid only and discards ambiguous floors, one-way edges, drops and restricted clearance. It includes no upstream runtime, Polestar trails, Blizzard client files, world textures, or transportation data. NQT's own solver reads the converted tile data without loading Shortest Path Forever.
