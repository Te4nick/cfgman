module cfgman

import os
import x.json2

pub const require_struct_error = error('passed type must be unembedded struct')

@[params]
pub struct CfgParams {
pub:
	env_overrides bool   = true     // if env variables overrides values from config file
	env_prefix    string = 'CFGMAN' // prefix for env variables
	env_load_file bool // wether to load env file with variables
	env_file_path string = '.env'        // path to env file to load
	cfg_load_file bool   = true          // wether to load config file
	cfg_file_path string = 'config.json' // path to config file to load (only json)
}

const field_source_both = 'both'
const field_source_json = 'json'
const field_source_env = 'env'
const field_source_disabled = '-'

pub fn load[T](params CfgParams) !T {
	mut result := T{}
	if params.cfg_load_file {
		json_value := parse_json_file[T](params.cfg_file_path)!
		$if T is $struct {
			merge_from_json(mut result, json_value)!
		} $else {
			result = json_value
		}
	}

	if params.env_load_file {
		load_env_file(params.env_file_path, params.env_overrides)!
	}

	if params.env_overrides {
		$if T is $struct {
			insert_from_env(mut result, params.env_prefix)!
		}
	}

	return result
}

@[inline]
fn get_json_decoded[T](_ T, data string) !T {
	$if T is string {
		return data
	}
	return json2.decode[T](data)!
}

fn insert_from_env[T](mut val T, env_prefix string) ! {
	environ := os.environ()
	unsafe {
		$for field in T.fields {
			attrs := field.attrs
			source := field_source(attrs)
			if source != field_source_json && source != field_source_disabled {
				env_name := env_field_name(attrs, field.name, env_prefix)
				$if field.unaliased_typ is $struct {
					insert_from_env(mut val.$(field.name), env_name)!
				} $else {
					if env_name in environ {
						env_val := os.getenv(env_name)
						val.$(field.name) = get_json_decoded(val.$(field.name), env_val)!
					}
				}
			}
		}
	}
}

fn merge_from_json[T](mut result T, json_value T) ! {
	unsafe {
		$for field in T.fields {
			source := field_source(field.attrs)
			if source != field_source_env && source != field_source_disabled {
				$if field.unaliased_typ is $struct {
					merge_from_json(mut result.$(field.name), json_value.$(field.name))!
				} $else {
					result.$(field.name) = json_value.$(field.name)
				}
			}
		}
	}
}

// parse_json_file parses json file from provided path into provided type
@[inline]
pub fn parse_json_file[T](path string) !T {
	return json2.decode[T](os.read_file(path)!)!
}

fn field_source(attrs []string) string {
	for attr in attrs {
		name, value := parse_attr(attr)
		if name != 'cfgman' {
			continue
		}
		normalized := normalize_attr_value(value)
		for part in normalized.split(',') {
			item := part.trim_space()
			if item == field_source_json {
				return field_source_json
			}
			if item == field_source_env {
				return field_source_env
			}
			if item == field_source_both {
				return field_source_both
			}
			if item == field_source_disabled {
				return field_source_disabled
			}
		}
	}
	return field_source_both
}

fn env_field_name(attrs []string, field_name string, env_prefix string) string {
	for attr in attrs {
		name, value := parse_attr(attr)
		if name != 'cfgman' {
			continue
		}
		normalized := normalize_attr_value(value)
		for part in normalized.split(',') {
			item := part.trim_space()
			if item.starts_with('env:') {
				custom := item[4..].trim_space()
				if custom != '' {
					return custom
				}
			}
		}
	}
	return '${env_prefix}_${field_name.to_upper()}'
}

fn normalize_attr_value(value string) string {
	mut normalized := value.trim_space()
	if normalized.len >= 2 {
		if (normalized[0] == `"` && normalized[normalized.len - 1] == `"`)
			|| (normalized[0] == `'` && normalized[normalized.len - 1] == `'`) {
				normalized = normalized[1..normalized.len - 1]
		}
	}
	return normalized
}

fn parse_attr(attr string) (string, string) {
	mut raw := attr.trim_space()
	if raw.contains(':') {
		idx := raw.index(':') or { return raw, '' }
		return raw[..idx].trim_space(), raw[idx + 1..].trim_space()
	}
	if raw.contains('=') {
		idx := raw.index('=') or { return raw, '' }
		return raw[..idx].trim_space(), raw[idx + 1..].trim_space()
	}
	return raw, ''
}
