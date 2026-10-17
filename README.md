# ESPHome Device Configuration

[![](https://github.com/nlowe/hass-config/workflows/CI/badge.svg)](https://github.com/nlowe/hass-config/actions) [![License](https://img.shields.io/badge/license-MIT-brightgreen)](./LICENSE)

Configuration for my ESPHome Devices.

## Layout

```
.
├── devices
│   └── <manufacturer>
│       └── <model>
│           ├──
│           └── <device name>.yaml
├── packages
│   └── <name>.yaml
└── secrets.dummy.yaml
```

Devices are stored under `devices/<manufacturer>/<model>/<device name>.yaml`. ESPHome does not support storing devices
in folders. We can't just use symlinks, because these don't appear to get packed properly for remote builds (which I
use), so I have tasks in the `Makefile` that creates "link" files with names like
`<manufacturer>__<modeL>__<device_name>.yaml` in the configuration root of my ESPHome container(s). The file contents
look like this:

```yaml
<<: !include '/data/configs/devices/<manufacturer>/<model>/<device_name>.yaml'
```

> [!IMPORTANT]
> All files use absolute paths for `!include`s for better compatibility with remote builds, again because ESPHome sucks
> at working with files outside of the configuration root directory.

Configuration snippets used by multiple devices that share a model and/or manufacturer are stored in `.common.yaml` in
the appropriate model or manufacturer folder.

Shared packages provide helpers and utilities for commonly used configuration snippets are stored in `packages/`. This
includes things like configuring wifi, a BLE Proxy, or a static ethernet IP address.

`secrets.dummy.yaml` contains dummy secrets used by devices. It will be copied to `secrets.yaml` for linting (including
in CI).
