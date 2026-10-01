# bb-auth-noctalia-nix

Home Manager integration for [`bb-auth`](https://github.com/branrgx/bb-auth) and its
[Noctalia UI plugin](https://github.com/branrgx/noctalia-plugins/tree/main/bb-auth),
for Polkit, GPG pinentry and GNOME Keyring prompts.

## Requirements

- Linux, a systemd user session, Wayland and Noctalia v5 with plugin API 23.
- Home Manager with TOML-based `programs.noctalia.settings` and
  `services.gpg-agent.pinentry` options.
- A desktop session that starts Noctalia and `wayland.systemd.target`, importing
  `WAYLAND_DISPLAY` into the systemd user environment before starting the target.

Host Polkit and GNOME Keyring services, storage and PAM unlock are outside this
module's scope.

## Installation

Add the flake input:

```nix
inputs.bb-auth-noctalia.url = "github:mvanderloo/bb-auth-noctalia-nix";
```

Import the module in Home Manager, passing `inputs` through `extraSpecialArgs`:

```nix
{ inputs, ... }:
{
  imports = [ inputs.bb-auth-noctalia.homeModules.default ];
  programs.noctalia.bb-auth.enable = true;
}
```

This disables Noctalia's built-in Polkit agent, configures GPG to use
`pinentry-bb`, and registers bb-auth for keyring prompts. Disable any separately
configured Polkit agents too. The module enables Noctalia's Home Manager
configuration and plugin; it does not launch Noctalia. The bb-auth user service
starts with `wayland.systemd.target`.

### Plugin catalogs

The module declares a local `branrgx` catalog. This replaces Noctalia's implicit
catalog defaults, but merges with explicitly configured source and enabled-plugin
lists. To retain the official/community catalogs, declare them once:

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

## Options

To retain an existing GPG agent/pinentry or keyring prompter, disable the
corresponding integration:

```nix
programs.noctalia.bb-auth = {
  gpgAgent.enable = false;
  keyring.enable = false;
};
```

Both default to `true`. Remove conflicting pinentry/SystemPrompter declarations
or opt out; the module does not force overrides.

`programs.noctalia.bb-auth.package` and `pluginPackage` override the backend and
plugin packages. Replacements must preserve the executable/D-Bus file layout and
`branrgx/bb-auth` catalog entry. Defaults use your Home Manager `pkgs`; the optional
`overlays.default` exposes both packages but is not required by the module.

## Checks

```sh
nix build --no-link .#bb-auth .#noctalia-bb-auth-plugin
nix flake check
nix flake check --all-systems --no-build
```

The backend runs upstream C++ tests during builds. Home Manager checks cover
module configuration and generated files, not live authentication or D-Bus
activation. `--all-systems --no-build` only evaluates; it does not build ARM
packages. The pinned Home Manager input is used only by checks.

### Manual desktop check

On a configured desktop, with authentication caches cleared or expired:

- Trigger Polkit authentication, a passphrase-protected GPG operation and a locked
  GNOME Keyring prompt. Confirm each uses the Noctalia UI.
- For each prompt, check successful submission, cancellation and retry after an
  incorrect password. Confirm the requesting application receives the result.
- With Noctalia stopped and bb-auth running, repeat the requests and record
  fallback behavior, including any errors or hangs. Restart Noctalia afterward.

These are manual checks to perform, not automated test results.
