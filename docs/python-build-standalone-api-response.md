# Python Build Standalone API Response Requirements

## Scope

This document defines only the API response requirements for Python Build Standalone release metadata.

The API data source is GitHub Releases and release assets. The API must only return fields that are available from GitHub Release data or can be reliably parsed from release asset names.

The response must not describe unavailable concepts or client-specific behavior.

## Data Source

The API reads release information from:

```text
https://github.com/astral-sh/python-build-standalone/releases
```

For each GitHub Release, the API may use:

- Release tag name
- Release asset name
- Release asset download URL
- Release asset size
- Release asset content type
- Release asset created time
- Release asset updated time
- Release asset digest

GitHub Release assets currently include a `digest` field in the following format:

```text
sha256:<hex-encoded-sha256>
```

Example:

```text
sha256:f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8
```

## Response Shape

The API returns a JSON object with an `items` array.

```json
{
  "items": [
    {
      "implementation": "cpython",
      "version": "3.10.20",
      "display_version": "3.10.20",
      "variant": "default",
      "release": "20260414",
      "filename": "cpython-3.10.20+20260414-aarch64-apple-darwin-install_only.tar.gz",
      "url": "https://github.com/astral-sh/python-build-standalone/releases/download/20260414/cpython-3.10.20%2B20260414-aarch64-apple-darwin-install_only.tar.gz",
      "platform": {
        "os": "darwin",
        "arch": "aarch64",
        "libc": null
      },
      "asset": {
        "size": 19408836,
        "content_type": "application/octet-stream",
        "created_at": "2026-04-14T17:26:12Z",
        "updated_at": "2026-04-14T17:26:13Z",
        "digest": "sha256:f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8",
        "sha256": "f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8"
      }
    }
  ]
}
```

## Top-Level Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `items` | array | Yes | List of recognized Python Build Standalone release assets. |

## Item Fields

Each item represents one recognized release asset.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `implementation` | string | Yes | Python implementation parsed from the asset name, such as `cpython`. |
| `version` | string | Yes | Python version parsed from the asset name, such as `3.10.20`. |
| `display_version` | string | Yes | Version string for display. Free-threaded builds use the `t` suffix. |
| `variant` | string | Yes | Build variant, such as `default` or `freethreaded`. |
| `release` | string | Yes | GitHub Release tag name, such as `20260414`. |
| `filename` | string | Yes | GitHub Release asset name. |
| `url` | string | Yes | GitHub Release asset download URL. |
| `platform` | object | Yes | Platform information parsed from the asset name. |
| `asset` | object | No | GitHub Release asset metadata and derived checksum fields. |

## Platform Fields

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `os` | string | Yes | Operating system parsed from the asset name, such as `linux`, `darwin`, or `windows`. |
| `arch` | string | Yes | CPU architecture parsed from the asset name, such as `x86_64` or `aarch64`. |
| `libc` | string or null | No | Linux libc parsed from the asset name, such as `gnu` or `musl`; otherwise `null`. |

## Asset Fields

The `asset` object contains metadata from the GitHub Release asset. If a field is not present in the GitHub Release asset data, the API must not invent it.

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `size` | number | No | Asset size in bytes from GitHub Release asset metadata. |
| `content_type` | string | No | Asset MIME type from GitHub Release asset metadata. |
| `created_at` | string | No | Asset creation time from GitHub Release asset metadata. |
| `updated_at` | string | No | Asset update time from GitHub Release asset metadata. |
| `digest` | string | No | Asset digest from GitHub Release asset metadata, such as `sha256:<hex>`. |
| `sha256` | string | No | Hex-encoded SHA-256 checksum derived from `digest` when `digest` starts with `sha256:`. |

## Parsing Rules

### Version

The `version` field is parsed from the Python version segment of the asset name.

Example:

```text
cpython-3.10.20+20260414-aarch64-apple-darwin-install_only.tar.gz
```

Produces:

```json
{
  "version": "3.10.20"
}
```

### Display Version

Default builds use the original version string:

```json
{
  "version": "3.10.20",
  "display_version": "3.10.20",
  "variant": "default"
}
```

Free-threaded builds append `t`:

```json
{
  "version": "3.13.3",
  "display_version": "3.13.3t",
  "variant": "freethreaded"
}
```

### Variant

The API currently recognizes:

| Variant | Rule |
| --- | --- |
| `default` | Asset name does not contain the free-threaded marker. |
| `freethreaded` | Asset name contains the free-threaded marker. |

### SHA-256

When GitHub Release asset metadata contains:

```json
{
  "digest": "sha256:f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8"
}
```

The API may return both the original `digest` and the normalized `sha256` value:

```json
{
  "digest": "sha256:f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8",
  "sha256": "f76cc83c7db16cfc8794bf6e44d834152b57d8bab4e04e823cbc59ed23ec22f8"
}
```

If `digest` is missing or does not use the `sha256:` prefix, `sha256` must be omitted.

## Filtering Rules

The API should only return release assets that can be recognized and parsed.

The API should exclude assets when:

- The implementation cannot be parsed.
- The Python version cannot be parsed.
- The platform cannot be parsed.
- The asset is not a target Python Build Standalone release asset.
- The asset filename does not match the expected format.

## Sorting Rules

The API should return versions from newest to oldest.

For the same Python version, default builds should be ordered before free-threaded builds.

## Acceptance Criteria

- The response contains a top-level `items` array.
- Each item represents one recognized GitHub Release asset.
- Each item contains `implementation`, `version`, `display_version`, `variant`, `release`, `filename`, `url`, and `platform`.
- `release` comes from the GitHub Release tag name.
- `filename` comes from the GitHub Release asset name.
- `url` comes from the GitHub Release asset download URL.
- `asset.digest` is returned when GitHub Release asset metadata provides it.
- `asset.sha256` is returned when it can be derived from a `sha256:<hex>` digest.
- Fields that are not present in GitHub Release data and cannot be reliably parsed are not returned.
- Unrecognized assets are excluded.
