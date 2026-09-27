# bb-auth-noctalia-nix

Noctalia-themed authentication prompts for Polkit, GPG and keyring unlocks,
using [`bb-auth`](https://github.com/branrgx/bb-auth) and its
[Noctalia plugin](https://github.com/branrgx/noctalia-plugins/tree/main/bb-auth).

## Usage

1. Add the flake input:

   ```nix
   inputs.bb-auth-noctalia.url = "github:mvanderloo/bb-auth-noctalia-nix";
   ```

2. Import the Home Manager module and enable it:

   ```nix
   { inputs, ... }:
   {
     imports = [ inputs.bb-auth-noctalia.homeModules.default ];
     programs.noctalia.bb-auth.enable = true;
   }
   ```

   Pass `inputs` through Home Manager's `extraSpecialArgs` for this example.

That single switch enables Noctalia, installs its authentication plugin, starts
bb-auth, replaces Noctalia's built-in Polkit agent, configures Home Manager's
GPG agent with `pinentry-bb`, and registers keyring prompt activation. Importing
the module without enabling it has no effect.

## Session requirements

Use Linux with a systemd user session, Wayland, and Noctalia v5 supporting plugin
API 23. Home Manager must provide the TOML-based `programs.noctalia.settings`
and `services.gpg-agent.pinentry` options.

Start Noctalia through your desktop/session configuration; enabling its Home
Manager module does not launch the shell. The bb-auth service follows
`wayland.systemd.target`. Your session must start that target and import
`WAYLAND_DISPLAY` into the systemd user environment first.

System Polkit and keyring storage/PAM unlock remain the host's responsibility.
This module supplies their prompts, not those services. No greeter is required.

## Options

Most configurations need only `programs.noctalia.bb-auth.enable = true`.

To keep an existing GPG agent/pinentry or keyring prompter, opt out of that
integration before activation:

```nix
programs.noctalia.bb-auth = {
  gpgAgent.enable = false;
  keyring.enable = false;
};
```

Both integrations default to `true` when the module is enabled. Existing
conflicting pinentry or SystemPrompter declarations must be removed or opted out
of; this module does not force overrides.

Advanced users can override `programs.noctalia.bb-auth.package` and
`programs.noctalia.bb-auth.pluginPackage`. Defaults use this repository's package
recipes with your Home Manager `pkgs`; no overlay is needed. Replacements must
preserve the backend's executable/D-Bus file layout and the plugin's
`branrgx/bb-auth` catalog entry, respectively.

## Other plugins

The module adds the local `branrgx` source and merges with your existing plugin
lists. An explicit source list replaces Noctalia's built-in catalog defaults.
If you want official/community catalogs too, declare them once:

```nix
programs.noctalia.settings.plugins.source = [
  {
    name = "official";
    kind = "git";
    location = "https://github.com/noctalia-dev/official-plugins";
  }
  {
    name = "community";
    kind = "git";
    location = "https://github.com/noctalia-dev/community-plugins";
  }
];
```

Use an attribute set for `programs.noctalia.settings` so settings can merge.
Do not separately declare the `branrgx` source or enable `branrgx/bb-auth` again.

## Development

```sh
nix build .#bb-auth
nix build .#noctalia-bb-auth-plugin
nix flake check
nix flake check --all-systems --no-build
nix fmt
```

Checks cover the one-switch setup, disabled configuration, integration opt-outs,
existing catalogs/pinentry, package overrides and session targeting. They also
validate generated Noctalia configuration and GPG/D-Bus files. Live authentication
is not tested; cross-system evaluation does not build ARM packages.

The Home Manager input is pinned **only for these checks**. Importing the module
does not select or change the consumer's Home Manager version.

The optional `overlays.default` exposes both packages through `pkgs`; module
package overrides remain explicit.

## Packaging

Home Manager replaces upstream's imperative bootstrap. Only the graphical
fallback is Qt-wrapped, preserving the backend's `argv[0]` dispatch. The plugin
uses Nix's Python and hands transient prompt responses through the private
`XDG_RUNTIME_DIR`, removing them after reading.
