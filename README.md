# cfgman

Config loader for V with support for:

- JSON config files
- environment variable overrides
- `.env` file loading
- nested struct field mapping
- python-dotenv-style parsing for env files

`cfgman` is useful when you want a typed config struct in V and want values to come from both a config file and environment variables.

## Features

- Load JSON into a typed V struct
- Override struct fields from environment variables
- Load variables from a `.env` file before applying overrides
- Support nested structs with prefix expansion
- Parse `.env` values with support for:
	- comments
	- `export KEY=value`
	- quoted values
	- inline comments for unquoted values
	- `${VAR}` expansion from earlier parsed variables or the process environment

## Installation
```shell
v install --git https://github.com/Te4nick/cfgman.git
```
Add import into .v files
```v
import cfgman
```

## Quick Start

Given this config struct:

```v
module main

import cfgman

struct AppConfig {
pub:
	port int
	addr string
}
```

And a `config.json` file:

```json
{
  "port": 8080,
  "addr": "127.0.0.1"
}
```

You can load it like this:

```v
module main

import cfgman

struct AppConfig {
pub:
	port int
	addr string
}

fn main() {
	cfg := cfgman.load[AppConfig](cfg_file_path: 'config.json')!

	println(cfg.port)
	println(cfg.addr)
}
```

## How Loading Works

`cfgman.load[T]()` applies sources in this order:

1. Start with `T{}`
2. If `cfg_load_file` is enabled, parse the JSON config file into the struct
3. If `env_load_file` is enabled, load variables from the `.env` file into the process environment
4. If `env_overrides` is enabled, apply matching environment variables onto the struct fields

## Primary API

### `load[T](params CfgParams) !T`

Loads a typed config struct from JSON and environment variables.

```v
cfg := cfgman.load[MyConfig](
	cfg_file_path: 'config.json'
	env_file_path: '.env'
	env_load_file: true
	env_prefix: 'MYAPP'
	env_overrides: true
)!
```

### `parse_json_file[T](path string) !T`

Parses a JSON file into a struct without applying any environment variables.

```v
cfg := cfgman.parse_json_file[MyConfig]('config.json')!
```

### `env_values(data string) !map[string]string`

Parses raw `.env` text.

```v
values := cfgman.env_values('PORT=8080\nHOST=127.0.0.1\n')!
```

### `parse_env_file(path string) !map[string]string`

Parses a `.env` file and returns its key/value pairs without mutating the process environment.

```v
values := cfgman.parse_env_file('.env')!
println(values['DATABASE_URL'])
```

### `load_env_file(path string, overrides bool) !map[string]string`

Loads a `.env` file into the process environment.

- When `overrides` is `false`, existing process environment values are preserved.
- When `overrides` is `true`, file values replace existing environment variables.

```v
loaded := cfgman.load_env_file('.env', false)!
println(loaded)
```

## `CfgParams`

```v
@[params]
pub struct CfgParams {
pub:
	env_overrides bool = true
	env_prefix string = 'CFGMAN'
	env_load_file bool
	env_file_path string = '.env'
	cfg_load_file bool = true
	cfg_file_path string = 'config.json'
}
```

### Fields

#### `env_overrides`

If `true`, environment variables override values loaded from JSON.

#### `env_prefix`

Prefix used to map environment variables to struct fields.

Default:

```text
CFGMAN
```

A field named `port` becomes:

```text
CFGMAN_PORT
```

#### `env_load_file`

If `true`, `load_env_file()` is called before environment overrides are applied.

#### `env_file_path`

Path to the `.env` file.

Default:

```text
.env
```

#### `cfg_load_file`

If `true`, the JSON config file is loaded.

#### `cfg_file_path`

Path to the JSON config file.

Default:

```text
config.json
```

## Environment Variable Mapping

Field names are mapped using:

```text
<PREFIX>_<FIELD_NAME_UPPERCASE>
```

Example:

```v
struct AppConfig {
pub:
	port int
	addr string
}
```

With prefix `MYAPP`, the loader reads:

```text
MYAPP_PORT
MYAPP_ADDR
```

### Nested Structs

Nested structs extend the prefix recursively.

```v
struct DatabaseConfig {
pub:
	host string
	port int
}

struct AppConfig {
pub:
	debug bool
	database DatabaseConfig
}
```

With `env_prefix: 'MYAPP'`, the supported variables are:

```text
MYAPP_DEBUG
MYAPP_DATABASE_HOST
MYAPP_DATABASE_PORT
```

Example:

```v
module main

import cfgman

struct DatabaseConfig {
pub:
	host string
	port int
}

struct AppConfig {
pub:
	debug bool
	database DatabaseConfig
}

fn main() {
	cfg := cfgman.load[AppConfig](
		cfg_file_path: 'config.json'
		env_prefix: 'MYAPP'
	) or {
		panic(err)
	}

	println(cfg.debug)
	println(cfg.database.host)
	println(cfg.database.port)
}
```

## Type Conversion Rules

Environment variable values are assigned using JSON decoding for non-string fields.

That means these work naturally:

```text
MYAPP_PORT=8080
MYAPP_DEBUG=true
MYAPP_RATIO=1.25
```

For string fields, the raw environment value is used directly.

Example:

```v
struct AppConfig {
pub:
	port int
	debug bool
	name string
}
```

```text
MYAPP_PORT=3000
MYAPP_DEBUG=true
MYAPP_NAME=demo
```

## Full Example

### `config.json`

```json
{
  "port": 8080,
  "addr": "127.0.0.1",
  "database": {
    "host": "localhost",
    "port": 5432
  }
}
```

### `.env`

```dotenv
export MYAPP_PORT=9000
MYAPP_DATABASE_HOST=db.internal
```

### V code

```v
module main

import cfgman

struct DatabaseConfig {
pub:
	host string
	port int
}

struct AppConfig {
pub:
	port int
	addr string
	database DatabaseConfig
}

fn main() {
	cfg := cfgman.load[AppConfig](
		cfg_file_path: 'config.json'
		env_load_file: true
		env_file_path: '.env'
		env_prefix: 'MYAPP'
	) or {
		panic(err)
	}

	println(cfg)
}
```

### Result

- `port` becomes `9000` from `.env`
- `addr` stays `127.0.0.1` from JSON
- `database.host` becomes `db.internal` from `.env`
- `database.port` stays `5432` from JSON

## Working With `.env` Files

The parser supports a practical subset of python-dotenv-style syntax.

### Basic assignments

```dotenv
PORT=8080
HOST=127.0.0.1
DEBUG=true
```

### Comments

```dotenv
# full-line comment
PORT=8080 # inline comment
```

### `export`

```dotenv
export APP_NAME=myapp
```

### Double-quoted values

```dotenv
PASSWORD="pa#ss word"
MESSAGE="hello\nworld"
```

### Single-quoted values

```dotenv
TOKEN='raw value'
```

### Empty values

```dotenv
EMPTY=
```

### Variable expansion

```dotenv
APP_NAME=cfgman
URL=https://example.com/${APP_NAME}
```

Expansion can resolve from:

- variables parsed earlier in the same `.env` content
- variables already present in the process environment

Example:

```v
module main

import cfgman
import os

fn main() {
	os.setenv('DOMAIN', 'example.com', true)
	values := cfgman.env_values('APP=demo\nURL=https://\${DOMAIN}/\${APP}\n') or {
		panic(err)
	}
	println(values['URL'])
}
```

Output:

```text
https://example.com/demo
```

## Parsing `.env` Without Loading It

Use `parse_env_file()` when you want to inspect values without mutating the environment:

```v
module main

import cfgman

fn main() {
	values := cfgman.parse_env_file('.env') or {
		panic(err)
	}

	for k, v in values {
		println('${k}=${v}')
	}
}
```

## Loading `.env` Into The Process Environment

Use `load_env_file()` when you want a `.env` file to populate `os.getenv()` values:

```v
module main

import cfgman
import os

fn main() {
	cfgman.load_env_file('.env', false) or {
		panic(err)
	}

	println(os.getenv('DATABASE_URL'))
}
```

## Error Cases

The env parser returns an error for malformed lines such as:

- missing `=`
- invalid key names
- unterminated quoted values

## Current Limitations

These points reflect the current implementation.

- JSON loading depends on `x.json2.decode`
- Environment overrides are applied to struct fields only
- Field names map directly from V field names to uppercase env names
- `.env` expansion supports `${VAR}` syntax, not `$VAR`
- Recursive or circular expansion is not specially handled
- Single-quoted values are treated as literal text
- Double-quoted values support basic escape sequences only: `\n`, `\r`, `\t`
