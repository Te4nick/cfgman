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

pub fn load[T](params CfgParams) !T {
	mut result := T{}
	if params.cfg_load_file {
		result = parse_json_file[T](params.cfg_file_path)!
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
			env_name := '${env_prefix}_${field.name.to_upper()}'
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

// parse_json_file parses json file from provided path into provided type
@[inline]
pub fn parse_json_file[T](path string) !T {
	return json2.decode[T](os.read_file(path)!)!
}
