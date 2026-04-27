module cfgman

import os
import x.json2

pub const require_struct_error = error("passed type must be unembedded struct")

@[params]
pub struct CfgParams {
pub:
	env_overrides bool = true // if env variables overrides values from config file
	env_prefix string = "CFGMAN" // prefix for env variables
	env_load_file bool // wether to load env file with variables
	env_file_path string = '.env' // path to env file to load
	cfg_load_file bool = true // wether to load config file
	cfg_file_path string = 'config.json' // path to config file to load (only json)
}

pub fn parse[T](params CfgParams) !T {
	mut result := T{}
	if params.cfg_load_file {
		mut from_file := load_json_file[T](params.cfg_file_path)!
		if params.env_overrides {
			insert_from_env(mut from_file, params.env_prefix)!
		}
		return from_file
	}

	return result
}

@[inline]
fn in_env(key string) bool {
	return key in os.environ()
}

@[inline]
fn get_json_decoded[T](val T, data string) !T {
	$if T is string {
		return data
	}
	return json2.decode[T](data)!
}

fn insert_from_env[T](mut val T, env_prefix string) ! {
	unsafe {
		$for field in T.fields {
			env_name := "${env_prefix}_${field.name.to_upper()}"
			$if field.unaliased_typ is $struct {
				insert_from_env(mut val.$(field.name), env_name)!
			} $else {
				if in_env(env_name) {
					env_val := os.getenv(env_name)
					val.$(field.name) = get_json_decoded(val.$(field.name), env_val)!
					// $if field.unaliased_typ is i8 {
					// 		val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is i16 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is i32 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is i64 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is u8 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is u16 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is u32 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is u64 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is int {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is isize {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is usize {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is f32 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else $if field.unaliased_typ is f64 {
					// 	val.$(field.name) = json2.decode[field.unaliased_typ](env_val)!
					// } $else {
					// 	return error("`decode_number_from_string` cannot decode ${T.name} type")
					// }
				}
			}
			
			println(field)
		}
	}
}

@[inline]
pub fn load_json_file[T](path string) !T {
	return json2.decode[T](os.read_file(path)!)!
}

// load_env_file sets env variables from file (overrides existing env if overrides=true)
pub fn load_env_file(path string, overrides bool) ! {
	env_file_content := os.read_file(path)!
}
