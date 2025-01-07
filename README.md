---
title: Extensible NixOS Modules
sub_title: Encouraging Words for Sisyphus
author: Jesse Gibson
theme:
  name: catppuccin-frappe
---

<!--
Notes:
- NixOS is wonderful and horrible.
- Infinite recursion, userspace errors.
- No conventions for organizing configs. (Programs, services, sure.)
- No two dotfiles look alike.
- Many ways to
-->

<!-- jump_to_middle -->

# NixOS Modules are Wonderful

<!-- pause -->

<!-- incremental_lists: true -->

<!--
Notes:
I don't need to know how `programs.zsh` works to use it.
I don't need to know Alacritty changed from Yaml to Toml. The right format is generated under the hood.
`programs.zsh` can use `environment.etc`. The module system is a rising tide.
-->

- **Encapsulating**: `programs.foo.enable` is all I need to know.
- **Unifying**: Settings are Nix expressions.
- **Composable**: Modules can use other modules.

<!-- end_slide -->
<!-- jump_to_middle -->

# NixOS Modules are Horrible

<!-- pause -->

<!-- incremental_lists: true -->

<!--
Notes:
No safety in refactoring. Evaluation errors only happen when the branches are hit.
No useful stack traces. It's guesswork. Module system is userspace so the experience is always 2nd class.
Global writable namespace. Unless you're disciplined, you'll have a bad time.
-->

- **Dynamically Typed**: Errors happen at evaluation. (If you're lucky.)
- **Infinite Recursion**: Good luck bisecting.
- **Discoverability**: Where did that setting come from?

<!-- end_slide -->

<!-- jump_to_middle -->

<!-- column_layout: [1, 2, 1] -->
<!-- column: 1 -->

Good patterns avoid the pain and leverage the power.

<!-- end_slide -->

## Baseline Experience

<!--
Notes:
The file grows. Pick and choose from the manual.
If you only ever have one host, this is fine.
-->

```bash
nixos-generate-config
```

```nix
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";

  # ...
}
```

<!-- pause -->

<!-- jump_to_middle -->

... but it never stops at just one host.

<!-- end_slide -->

# Configs Split into "Profiles"

---

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

### Personal Config

```nix
# profiles/personal.nix
{
  environment.systemPackages = [
    pkgs.some-cool-tech
    pkgs.probably-malware
  ];
}
```

```nix
# Personal Config
{
  imports = [
    ./profiles/common.nix
    ./profiles/personal.nix
  ];

  # ...
}
```

<!-- column: 1 -->

### Work Config

```nix
# profiles/work.nix
{
  environment.systemPackages = [
    pkgs.business-software
    pkgs.bazel # eww
  ];
}
```

```nix
# Work Config
{
  imports = [
    ./profiles/common.nix
    ./profiles/work.nix
  ];

  # ...
}
```

<!-- end_slide -->

#### Kaboom

```
error: Package ‘somepkg-2.2.0’ in /nix/store/ynjyhwksmz6rxipx3r0h8gyj42lvd4ak-source/pkgs/some-pkg.nix

a) To temporarily allow broken packages, you can use an environment variable
  for a single invocation of the nix tools.

    $ export NIXPKGS_ALLOW_BROKEN=1

  Note: When using `nix shell`, `nix build`, `nix develop`, etc with a flake,
        then pass `--impure` in order to allow use of environment variables.

b) For `nixos-rebuild` you can set
  { nixpkgs.config.allowBroken = true; }
in configuration.nix to override this.

c) For `nix-env`, `nix-build`, `nix-shell` or any other Nix command you can add
  { allowBroken = true; }
to ~/.config/nixpkgs/config.nix.
```

<!-- pause -->

- The new package broke your workflow and you want to downgrade.
- An option isn't supported by some of your environments (`NixOS` vs `nix-darwin`).

<!-- pause -->

Upgrades shouldn't force you to solve every problem at once.

<!-- end_slide -->

## Profiles Split into "Presets"

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

### Personal Config

```nix
# presets/some-cool-tech.nix
{
  options.presets.some-cool-tech = {
    enable = lib.mkEnableOption "Use pkgs.some-cool-tech";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.some-cool-tech
    ];
  };
}
```

```nix
# profiles/personal.nix
{
  presets.some-cool-tech.enable = true;
  presets.probably-malware.enable = true;
}
```

```nix
# Personal Config
{
  imports = [
    ./profiles/common.nix
    ./profiles/personal.nix
  ];

  # ...
}
```

<!-- column: 1 -->

### Work Config

```nix
# presets/business-software.nix
{
  options.presets.business-software = {
    enable = lib.mkEnableOption "Use pkgs.business-software";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.business-software
    ];
  };
}
```

```nix
# profiles/work.nix
{
  presets.business-software.enable = true;
  presets.bazel.enable = true;
}
```

```nix
# Work Config
{
  imports = [
    ./profiles/common.nix
    ./profiles/work.nix
  ];

  # ...
}
```

<!-- end_slide -->

#### Kaboom?

```
package ‘business-software-2.2.0’ failed to evaluate!
```

<!-- pause -->

```nix
{
  # Disable it and go about your day.
  presets.business-software.enable = lib.mkForce false;
}
```

<!-- end_slide -->

## Anatomy of a Good Preset

```nix
{
  options.presets.programs.alacritty = {
    enable = lib.mkEnableOption "Install and configure Alacritty";
  };

  config.programs.alacritty = lib.mkIf cfg.enable {
    enable = true;
    package = pkgs.unstable.alacritty;

    settings = {
      # ...
    };
  };
}
```

- **Single Responsibility**: Only manages one program or service.
- **Clearly Named**: Mirrors the module it configures.
- **Deferred**: No side effects unless enabled.

Config files should live with the preset.

<!-- end_slide -->

## Anatomy of a Good Profile

```nix
{
  options.profiles.common = {
    enable = lib.mkEnableOption "Use common presets";
  };

  config = lib.mkIf cfg.enable {
    presets = {
      programs.foo.enable = lib.mkDefault true;
      programs.bar.enable = lib.mkDefault true;
      services.baz.enable = lib.mkDefault true;
    };

    programs.basic.enable = lib.mkDefault true;
  };
}
```

```nix
# hosts/personal.nix
{
  # ...
  profiles.common.enable = true;
}
```

- **Deferred**: No side effects unless enabled.
- **Defaults**: Easy to disable presets without `lib.mkForce`.
- **Pragmatic**: Doesn't force everything into a preset.

Profiles can evolve into presets.

<!-- end_slide -->

## Extending the Platform

```nix
{
  options.presets.programs.glow = {
    enable = lib.mkEnableOption "Install and configure pkgs.glow";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.glow # NO!
    ];
  };
}
```

Not everything exists in `programs.*`.

<!--
Notes:
You can't remove items from lists. You can't downgrade or patch them.
-->

<!-- end_slide -->

## Extending the Platform

```nix
{
  options.programs.glow = {
    enable = lib.mkEnableOption "Whether to enable the `glow` markdown viewer";
    package = lib.mkPackageOption pkgs "glow" {};
    settings = lib.mkOption {
      type = yaml.type;
      default = { };
      description = "Configuration written to `$XDG_CONFIG_HOME/glow/glow.yml`";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."glow/glow.yml".source = yaml.generate "glow.yml" cfg.settings;
  };
}
```

- **Overridable**: Package can be configured, patched, or downgraded.
- **Few Assumptions**: Useful even without the preset. Another cut point.
- **Nix-based Settings**: [RFC-0042](https://github.com/NixOS/rfcs/blob/master/rfcs/0042-config-option.md)

<!--
Notes:
Just like you can't remove a package from a list, you can't remove config from `extraConfig`.
Avoid it. Generate whatever you can.
-->

<!-- end_slide -->

## Format and Language Generators

- `pkgs.formats.*` (json, toml, yaml, ini, ...)
- `lib.generators.*` (lua, plist, ...)
- `lib.hm.*` (zsh, nushell, hyprconf, ...)

<!-- pause -->

... or your own binding:

```nix
{
  extraConfig = ''
    settings = json.loads(${json.generate "settings.json" cfg.settings})
  '';
}
```

<!-- end_slide -->

## Keep Settings in Nix

```nix
{
  programs.foo.settings = {
    run = pkgs.writers.writeRust "do-something" { } "...";
    theme = ./themes/onedark;
  };
}
```

```nix
{
  programs.jujusu.settings.user = {
    name = config.programs.git.userName;
    email = config.programs.git.userEmail;
  };
}
```

- Easily use paths and derivations like `pkgs.writers.*`.
- Settings are shared with all other modules.
- Extensible and mutable in downstream hosts.

<!-- end_slide -->

## Going further: Meta-Modules

For complex services, design higher-level modules.

- `lab.profiles.router`
  - `lab.services.dns`
    - `services.coredns`
  - `lab.services.dhcp`
    - `services.kea`
  - `lab.services.gateway`
    - (NixOS networking stuff)

<!-- pause -->

For simpler DSLs, merge it into the existing program or service.

```nix
{
  options.programs.nushell.libraries = {
    enable = lib.mkEnableOption "Manage the library search path";
    path = lib.mkOption {
      type = types.listOf (types.either types.str types.path);
      description = "Libraries visible in the search path";
      default = [ ];
    };
  };

  config.programs.nushell = lib.mkIf cfg.enable {
    # ...
  };
}
```

<!-- end_slide -->

## Summary of Patterns

- **Presets**: Very opinionated configs and services. Specific to a single program or service.
- **Profiles**: Enables groups of programs, services, and **presets**.
- **Platforms**: Extends the native platforms with new programs, services, and module options. NO CONFIGS.

<!-- end_slide -->

## Code Structure

<!-- column_layout: [1, 2] -->

<!-- column: 0 -->

```
platforms/
  nixos/*
  home-manager/
    modules/
      programs/*
      services/*
      $USERNAME/
        presets/
          services/*
          programs/
            glow.nix
        profiles/
          common.nix
```

<!-- column: 1 -->

```nix
{
  options.psychollama.profiles.common = {
    enable = lib.mkEnableOption "Use common programs and services";
  };
}
```

```nix
{
  options.psychollama.presets.programs.glow = {
    enable = lib.mkEnableOption "Install and configure pkgs.glow";
  };
}
```

<!-- reset_layout -->

- **Organized by Platform**: It's clear what platform options are available by the file's location.
- **Options Mirror the File System**: It's easy to find the definition for any option.
- **Namespaced**: Organized under username. (More on this later.)

<!-- end_slide -->

## Flake Exports

Organize `nixosModules` by **platforms** and **configs**:

```nix
# flake.nix
{
  nixosModules = {
    nixos-platform = ./platforms/nixos/modules;
    nixos-configs = ./platforms/nixos/modules/USERNAME;

    nix-darwin-platform = ./platforms/nix-darwin/modules;
    nix-darwin-configs = ./platforms/nix-darwin/modules/USERNAME;

    home-manager-platform = ./platforms/home-manager/modules;
    home-manager-configs = ./platforms/home-manager/modules/USERNAME;
  };
}
```

### Advantages

1. Extend your profiles from other machines and private flakes.
2. Like your DSLs? Pull them into your other flakes.
3. Share it with the world (scary).

<!-- end_slide -->

<!-- jump_to_middle -->

# Questions?

(Tips and tricks to follow)

<!-- end_slide -->

## Utility Functions

```nix
{
  options.lab.services.dhcp = {
    lib.toClientId = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      description = ''
        Convert an IPv4 address to a DHCP client identifier. Useful when you
        want to "hard-code" the IP but keep the router, DNS, and other fields
        dynamic.
      '';

      default =
        ip4:
        lib.pipe ip4 [
          # ["127", "0", "0", "1"]
          (lib.splitString ".")

          # [127, 0, 0, 1]
          (lib.map lib.strings.toInt)

          # ["7F", "0", "0", "1"]
          (lib.map lib.trivial.toHexString)

          # ["7F", "00", "00", "01"]
          (lib.map (lib.strings.fixedWidthString 2 "0"))

          # "7F:00:00:01"
          (lib.concatStringsSep ":")

          # "FE:01:7F:00:00:01"
          (id: "FE:01:${id}")
        ];
    };
  };
}
```

<!-- end_slide -->

## Eval for Faster Feedback

```bash
nix eval '.#nixosConfigurations.my-machine.config.*'
```

- Faster iteration while developing DSLs.
- Incrementally build expressions.

<!-- end_slide -->

## Testing

```nix
pkgs.testers.runNixOSTest {
  imports = [
    self.nixosModules.nixos-platform

    {
      name = "my-test";
      nodes.machine = {
        # ...
      };

      testScript = ''
        machine.start()
        machine.shell_interact()
      '';
    }
  ];
}
```

### Recommendations

- Test platforms, not configs.
- Ideal when realizing the config is dangerous, stateful, or scheduled.
- Create a `sandbox` test.

<!-- end_slide -->

## Custom Module Namespaces

```nix
let mod = lib.evalModules {
  modules = [
    # ...
  ];
};
```

```nix
mod.config # ...
```

<!-- end_slide -->

## Recommendations

- [Noogle.dev](https://noogle.dev)
- `lib.pipe` for complex functions
- Use `home-manager` as a default
- Comment EVERYTHING

<!-- end_slide -->

<!-- jump_to_middle -->

## Rules

1. **Presets**, **Profiles**, **Platforms**.
2. Modules should not have side effects.
3. The file system should match the module system.
4. Aggressively extend the platform with DSLs.

<!-- end_slide -->

# FINAL SLIDE

Jesse Gibson

https://github.com/PsychoLlama/dotfiles
