# EvolutionX voor houji — zelfbouw

Zelfgebouwde **EvolutionX 11.11 (Android 16) met Google Apps** voor de
**Xiaomi 14** (codename `houji`).

> ⚠️ **Experimenteel:** houji wordt **niet officieel** door EvolutionX ondersteund.
> De device tree moet nog gevonden/geport worden (zie [Device tree](#device-tree)).
> Dit is een apart, geïsoleerd project naast het garnet-project.

De ROM wordt gebouwd uit de officiële EvolutionX-bron (branch `bka` = Android 16),
met een (nog te bepalen) houji device tree en vendor-blobs. Google Apps zitten er
standaard in (`WITH_GMS=true`).

## Resultaat

De flashbare ROM staat na een build op:

```
src/out/target/product/houji/EvolutionX-16.0-<datum>-houji-11.11-Unofficial.zip
```

> ⚠️ Dit is een **Unofficial** build, getekend met je eigen release keys (zie
> [Signing](#signing)). **Play Integrity / SafetyNet werkt niet out-of-the-box** —
> Google Pay, sommige bank-apps en Netflix kunnen weigeren (op te lossen met een
> Play Integrity Fix).

---

## Opzet / architectuur

| Onderdeel | Detail |
|---|---|
| Host | Ubuntu 26.04 LTS |
| Build-omgeving | Docker-container met **Ubuntu 24.04** |
| Build-image | `evolutionx-builder` (gedeeld met het garnet-project; zie `Dockerfile`) |
| Container | `houji-builder` (persistent, bind-mounts hieronder) |
| Broncode | `src/` → gemount op `/src` in de container |
| Ccache | `ccache/` → gemount op `/ccache` (50 GB) |
| Manifest | EvolutionX branch `bka` = Android 16 |
| Device tree | **nog te bepalen** → fork `Hayqe/device_xiaomi_houji` (productnaam `lineage_houji`) |
| Build-target | `lunch lineage_houji-userdebug` → `m evolution` |

### Device tree

houji staat **niet** op `Evolution-X-Devices` noch op `LineageOS` (beide 404 op
`device_xiaomi_houji`). Dit moet worden uitgezocht:

1. Zoek een community-fork van een houji device tree (EvolutionX/LineageOS) die
   compatibel is met branch `bka` — of port de LineageOS houji-tree naar `bka`.
2. Vul `local_manifests/houji.xml` in (device tree + vendor + kernel + dependencies).
3. Fork de device tree → `Hayqe/device_xiaomi_houji` en voeg de OTA-overlay
   (`UpdaterOverlayHouji`) + AVB-override toe (zelfde patroon als garnet).

---

## Vereisten (host)

- **Docker** (draaiend).
- **Schijfruimte**: bron ~178 GB + build-output ~100 GB + ccache 50 GB → reken op
  ≥ 400 GB vrij.
- **RAM**: de Soong-analyse piekt op ~30-40 GB. Deze machine (30 GB RAM) heeft
  daarom een eenmalige host-fix nodig (zie hieronder).

### Eenmalige host-fix: extra swap + systemd-oomd uit

Zonder deze fix wordt de build tijdens de Soong-analyse OOM-gekilled.

> Makkelijkst: draai `sudo ./fix-host.sh` — dat doet alles hieronder in één keer
> (en is idempotent, dus veilig om vaker te draaien).

```bash
sudo ./fix-host.sh
```

> Controleer na afloop: `free -h` (swap moet ~40 GB tonen) en
> `systemctl is-active systemd-oomd.service` (moet `inactive` zijn).

---

## Bestanden

| Bestand | Doel |
|---|---|
| `Dockerfile` | Bouwt de build-image (Ubuntu 24.04 + AOSP-deps + JDK 17 + `repo`) |
| `build.sh` | Sync + build (de "volgende build") |
| `check-updates.sh` | Controleert of er nieuwe upstream-commits zijn |
| `release.sh` | Publiceert een nieuwe build als OTA (SourceForge-upload + JSON) |
| `setup-keys.sh` | Kopieert release-signing keys naar de build-tree (release-keys) |
| `fix-host.sh` | Herstelt swap + systemd-oomd (host-voorwaarden voor de build) |
| `ota/houji.json` | OTA-metadata die de Updater-app op het toestel uitleest |
| `src/` | De volledige AOSP/EvolutionX-bron |
| `ccache/` | Persistente ccache (versnelt volgende builds) |

---

## Een nieuwe build maken

```bash
./build.sh
```

Dit start (indien nodig) de container, synct de bron (`repo sync`) en draait
`m evolution -j16`. Aan het einde vraagt het script of je de release direct wilt
publiceren (SourceForge-upload + OTA-JSON).

### Handmatig (zonder script)

```bash
docker exec houji-builder bash -c '
  cd /src
  export USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache
  repo sync -c -j16 --force-sync --no-clone-bundle --no-tags
  source build/envsetup.sh
  lunch lineage_houji-userdebug
  ccache -M 50G
  m evolution -j16
'
```

> Gebruik `-j16` (geen `-j22`) om geheugenpieken te beperken op 30 GB RAM.

---

## OTA-updates

De ROM ondersteunt OTA via de EvolutionX-**Updater**-app. Die leest een JSON uit
en downloadt de update; de JSON wordt in deze repo gehost, de ROM-zip op SourceForge.

### Hoe het werkt

1. De Updater-app vraagt
   `https://raw.githubusercontent.com/Hayqe/houji-evolutionx/main/ota/houji.json` op.
   Die URL wordt ingesteld via de RRO-overlay `UpdaterOverlayHouji` in de
   (geforkte) device tree.
2. De JSON bevat download-URL, md5, grootte en build-timestamp van de nieuwste
   build. Alleen een update met een `timestamp` *nieuwer* dan de geïnstalleerde
   build wordt getoond.
3. De app downloadt de zip van SourceForge en past hem toe via `update_engine`
   (virtuele A/B — geen dataverlies).

### Een update uitbrengen

```bash
PUBLISH=1 ./release.sh
```

### Vereisten (eenmalig)

- **SourceForge-project** `houji-evolutionx` met een SSH-key op je account.
- **GitHub-repo's** `houji-evolutionx` (deze repo) en een fork van de houji
  device tree met de `UpdaterOverlayHouji`-overlay.
- **Signing-keys** in `~/.android-certs-houji/` (eigen release key, zie hieronder).

### Signing

Voor OTA tussen builds is een *consistente* signeerkey nodig. Je bouwt met je eigen
release key (niet de publieke testkeys) door:

```bash
./setup-keys.sh
```

Dit kopieert de keys van `~/.android-certs-houji/` naar
`src/vendor/evolution-priv/keys/` en schrijft `keys.mk`. EvolutionX pikt die
automatisch op, waardoor de build met `release-keys` wordt getekend (in plaats van
`test-keys`). Daarnaast wordt een AVB-key (RSA-4096, `avb.pem`) gegenereerd.

> ⚠️ De private keys in `src/vendor/evolution-priv/keys/` worden **niet** gecommit
> (valt onder `src/` in `.gitignore`). Bewaar `~/.android-certs-houji/` veilig.

---

## Flashen op je toestel

> ⚠️ Nog in te vullen: de exacte flash-stappen (boot/vendor_boot/dtbo, recovery,
> sideload) volgen uit de houji device tree die in [Device tree](#device-tree) wordt
> gevonden. Controleer de instructies van die device tree vóór je flasht.
