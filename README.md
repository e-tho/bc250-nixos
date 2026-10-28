# bc250-nixos

NixOS hardware support for the AMD BC-250.

> [!IMPORTANT]
> The defaults target stock BIOSes. Modded ones may include conflicting fixes.

## Usage

The project tracks NixOS unstable. Add the flake and import its module:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bc250 = {
      url = "github:e-tho/bc250-nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, bc250, ... }:
    {
      nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
        modules = [
          bc250.nixosModules.default
          # ...
        ];
      };
    };
}
```

The module applies its defaults on import.

The kernel comes from [Chaotic Nyx](https://github.com/chaotic-cx/nyx), and the other packages from this project's binary cache. To avoid building them locally on the first rebuild, pass both caches on the command line:

```console
sudo nixos-rebuild switch --flake .#my-host --option extra-substituters "https://nyx-cache.chaotic.cx/ https://bc250-nixos.cachix.org" --option extra-trusted-public-keys "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk= bc250-nixos.cachix.org-1:sOceaxECzHXj5Qx+TMIm183ISclrIp3lGJTcxS/V+dQ="
```

Later rebuilds use the caches configured by the module.

## Defaults

- **ACPI fix**: CPU frequency scaling and idle states, through [corrected ACPI tables](https://github.com/e-tho/bc250-acpi-fix).
- **Patched drivers**: fixes and optimizations for the kernel drivers and Mesa, from the [linux-cachyos-bc250](https://github.com/MastaG/linux-cachyos-bc250/blob/main/docs/PATCHES.md) patch series.
- **Kernel**: the CachyOS kernel from [Chaotic Nyx](https://github.com/chaotic-cx/nyx), which the patch series targets.
- **GPU governor**: adapts GPU clocks and voltage to load, through [cyan-skillfish-governor](https://github.com/filippor/cyan-skillfish-governor).
- **Sensors**: fan and board sensors, through [nct6687d](https://github.com/Fred78290/nct6687d).
- **Swap**: zswap with a 16 GB swap file. zram is refused, as it [crashes memory-hungry games](https://elektricm.github.io/amd-bc250-docs/system/power/#swap-and-zram-optimization) when the GPU takes memory on demand.
- **ntsync**: the kernel driver Proton uses for Windows synchronization primitives.

`bc250-cu-live-manager`, `bc250-detect` and `bc250memcfg` are on the PATH.

## Options

```nix
hardware.bc250 = {
  acpiFix.enable = true;
  driverPatch.enable = true;
  swapFile.enable = true;
  coreUnlock.enable = false;
  cuUnlock = {
    enable = false;
    exclude = [ ]; # pairs from bc250-cu-live-manager
  };
  vram = {
    split = null; # in MB, 6144 recommended
    dynamicLimit = null; # in MB, unset recommended
  };
};

services.cyan-skillfish-governor-smu = {
  enable = true;
  settings = { }; # merged into the default config
};

services.bc250-smu-oc = {
  enable = false;
  settings.overclock = { }; # values from bc250-detect
};
```

### CPU cores

`hardware.bc250.coreUnlock.enable` unlocks the 2 factory-disabled CPU cores, through [bc250-core-unlock](https://github.com/rw-r-r-0644/bc250-core-unlock). The unlock is reapplied on each cold boot and triggers a reboot to bring the cores up. Appending `bc250.nocoreunlock` to the kernel command line from the bootloader menu skips it for one boot. The cores stay unlocked until the board is powered off, even after disabling the option or appending the parameter. Stress-test the extra cores before use.

With the patched drivers, the SMU firmware is also patched at boot through [bc250-smu-patch](https://github.com/e-tho/bc250-smu-patch), so CPU metrics cover all 8 cores. The patch requires BIOS P3.00.

> [!WARNING]
> On BIOS versions other than P3.00, the core unlock and the patched drivers are incompatible: the driver then misreads the GPU temperature used for thermal throttling.

### Compute units

`hardware.bc250.cuUnlock.enable` unlocks the 16 factory-disabled GPU compute units, through the [patched driver](https://github.com/duggasco/bc250-40cu-unlock). Not every board is stable with all of them:

1. Run `sudo bc250-cu-live-manager` and enable units live to find the faulty ones. Do not use its save or service actions, as they write files that NixOS neither manages nor rolls back.
2. List the faulty pairs in `hardware.bc250.cuUnlock.exclude`, as the live manager reports them:

```nix
   hardware.bc250.cuUnlock.exclude = [ "1.0.4" ]; # shader engine 1, array 0, pair 4
```

### VRAM

`hardware.bc250.vram.split` sets the memory reserved for the GPU, in MB. The stock BIOS reserves 8192. The value is written to CMOS when the configuration is activated and takes effect on the next boot. Unsetting the option does not revert it. After a CMOS clear, the system boots once with the stock split. Check the stored split with `sudo bc250memcfg`. 2048 is refused, as it prevents the graphics driver from starting.

6144 is the recommended value, as smaller ones can crash the session when a game fills the reserved memory ([details](https://elektricm.github.io/amd-bc250-docs/bios/vram/#a-second-crash-mechanism-the-kernel-parameter-does-not-fix)).

`hardware.bc250.vram.dynamicLimit` sets the system RAM the GPU may take on demand beyond the split, in MB. By default, the kernel allows half of the system RAM left after the split.

Leaving it unset is recommended. With a split below 6144, raise the limit, or memory-hungry games crash. A higher limit does not prevent the session crash when the reserved memory fills up.

### GPU governor

`services.cyan-skillfish-governor-smu.settings` is merged into the default config. Use `frequency-range` to limit the GPU clocks, and `safe-points` to tune the voltage-frequency curve. See the [governor's README](https://github.com/filippor/cyan-skillfish-governor) for the available settings.

### CPU tuning

Find stable overclocking and undervolting values with `bc250-detect`, as described in [bc250_smu_oc](https://github.com/bc250-collective/bc250_smu_oc), then copy them into `services.bc250-smu-oc.settings.overclock`:

```nix
services.bc250-smu-oc = {
  enable = true;
  settings.overclock = {
    frequency = 3500;
    scale = -35;
    max_temperature = 90;
  };
};
```

> [!WARNING]
> Raising the frequency without undervolting can push the CPU voltage past safe limits and permanently damage the board.

## Proton

`proton-cachyos-slr-bc250` and `protonge-latest-bc250` are Proton builds with [HelixSR and FSR4 upscaling](https://github.com/MastaG/linux-cachyos-bc250/blob/main/docs/FSR4-PROTON.md) through OptiScaler. They require the patched drivers and are unfree, since they include NVIDIA components.

```nix
programs.steam.extraCompatPackages = [
  pkgs.proton-cachyos-slr-bc250
  pkgs.protonge-latest-bc250
];
```

Select them per game in Steam, under Properties > Compatibility. They override the game's upscaler (ideally DLSS) with HelixSR in DirectX 12 games and FSR4 in DirectX 11 and Vulkan games. Set `PROTON_USE_OPTISCALER=fsr411f` in the launch options to use FSR4 in DirectX 12 games. OptiScaler's in-game overlay (opened by pressing Insert) shows the active upscaler.

## UGREEN DP-to-HDMI adapter firmware

`bc250-ch7218-fw` flashes UGREEN DP-to-HDMI 2.1 adapters built on a Chrontel CH7218A. It includes UGREEN's updater, UGREEN's firmware and copies with a [watchdog fix](https://github.com/MastaG/linux-cachyos-bc250/blob/main/packages/bc250-ch7218-fw/README.md) for black screens after the display is turned off. The package is unfree, since UGREEN's files carry no license:

```nix
environment.systemPackages = [ pkgs.bc250-ch7218-fw ];
```

Flash from SSH, as the picture turns off during the write:

```console
sudo bc250-ch7218-flash status
sudo bc250-ch7218-flash flash tmds --dry-run
sudo bc250-ch7218-flash flash tmds
```

The new firmware runs after the adapter is power-cycled.

## See also

- [BC-250 documentation](https://elektricm.github.io/amd-bc250-docs/)
- [BC-250 community Discord](https://discord.gg/8eZfFWhczz)

## License

MIT. The packaged projects keep their own licenses.
