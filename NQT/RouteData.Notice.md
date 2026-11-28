# NQTDB route data attribution and source

**Shortest Path Forever by cjber and contributors**, version 1.49.2, [source revision 9b0058a](https://github.com/cjber/shortest-path-forever/tree/9b0058ab4b8913196b8899d87952958e3f49bf24). The derived grid in `NQTDBRouteTiles.lua` is distributed under [GPL-3.0-or-later](RouteData.License.txt).

Corresponding input and build instructions:
- [Nav2991.lua](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/Nav/Nav2991.lua) (SHA-256 f1955bc5fd3012710248f9863d3def4b449ca7eb22ab0f2ca8d351469d33890a)
- [Nav2991_1.lua](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/Nav/Nav2991_1.lua) (SHA-256 c61c7cdf6bf438b250339823eb656b3f8381c693acac96b1737a3b336a47d470)
- Upstream [terrain bake and third-party attribution](https://github.com/cjber/shortest-path-forever/blob/9b0058ab4b8913196b8899d87952958e3f49bf24/THIRD_PARTY.md) and [baker source](https://github.com/cjber/shortest-path-forever/tree/9b0058ab4b8913196b8899d87952958e3f49bf24/tools/baker).
- From the tagged NQT repository, run `node tools/import-spf-grid.cjs <directory-containing-both-files> NQT/NQTDBRouteTiles.lua`.

The upstream files describe terrain baked from Forever build 71037 with TrinityCore e3916b2adcf2f8a70ae33817fc57b6c0266e2fb0. NQT keeps dry base edges only and discards one-way edges, drops and restricted clearance. The original Zephras slice discards cells with stacked layers. The newer continent grids mark verified lower-floor edges for transit only and never use a stacked cell as an unverified start or destination. It includes no upstream runtime, Polestar trails, Blizzard client files, world textures, or transportation data. NQT's own solver reads the converted tile data without loading Shortest Path Forever.

## Eastern Kingdoms and Kalimdor

The two continent payloads, `NQTDBRouteWorld0.lua` and `NQTDBRouteWorld1.lua`, also use the GPL-3.0-or-later dry grid conversion described above. Their inputs are the corresponding Nav0 and Nav1 headers and numbered files in the [pinned upstream Nav directory](https://github.com/cjber/shortest-path-forever/tree/9b0058ab4b8913196b8899d87952958e3f49bf24/Nav). The 58 Git blob IDs are recorded in `tools/spf-1.49.2-continent-blobs.tsv` in the NQT release source. From the tagged NQT repository, run:

```sh
node tools/verify-spf-continent-source.cjs /path/to/upstream/Nav
node tools/import-spf-grid.cjs /path/to/upstream/Nav NQT/NQTDBRouteWorld0.lua 0 --layer-transit
node tools/import-spf-grid.cjs /path/to/upstream/Nav NQT/NQTDBRouteWorld1.lua 1 --layer-transit
```

The same reciprocal dry-step filters apply. Completely empty tiles are omitted. The continent files store run-length encoded empty cells, direction masks, and height deltas; the client only decodes tiles needed for the current search. The route engine does not load Shortest Path Forever or Polestar.
