module cfgman

import os
import x.json2

fn set_envs[T](envs T, env_prefix string) {
	$if T !is $struct {
		panic('set_envs generics should be structs')
	}

	$for field in T.fields {
		env_name := '${env_prefix}_${field.name.to_upper()}'
		$if field.unaliased_typ is $struct {
			set_envs(envs.$(field.name), env_name)
		} $else {
			envs_empty := T{}
			if envs.$(field.name) != envs_empty.$(field.name) {
				env_str_val := envs.$(field.name).str()
				os.setenv(env_name, env_str_val, false)
				println('set_envs: ${env_name}=${env_str_val}')
			}
		}
	}
}

fn pre_test[T](cfg T, envs T, params CfgParams) {
	println('ENVS: ${envs}')
	$if T !is $struct {
		panic('pre_test generics should be structs')
	}

	os.write_file(params.cfg_file_path, json2.encode(cfg)) or { panic(err) }

	if envs != T{} {
		set_envs(envs, params.env_prefix)
	}
}

fn test_basic() {
	struct TestCfg {
	pub:
		port int
		addr string
	}

	tcfg := TestCfg{
		port: 2112
		addr: '127.0.0.1'
	}
	envs := TestCfg{
		port: 1234
	}
	cfg_file_path := '${os.vtmp_dir()}/test1.json'
	pre_test(tcfg, envs, cfg_file_path: cfg_file_path)
	cfg := load[TestCfg](cfg_file_path: cfg_file_path)!
	assert cfg.port == envs.port
	assert cfg.addr == tcfg.addr
}

fn test_included_struct() {
	struct Info {
	pub:
		first_name string
		last_name  string
	}

	struct Cfg {
	pub:
		username string
		info     Info
	}

	cfg := Cfg{
		username: 'Te4nick'
		info:     Info{
			first_name: 'Jack'
			last_name:  'London'
		}
	}
	envs := Cfg{
		info: Info{
			last_name: 'Daniels'
		}
	}
	cfg_file_path := '${os.vtmp_dir()}/test_included_struct.json'
	pre_test(cfg, envs, cfg_file_path: cfg_file_path)
	out := load[Cfg](cfg_file_path: cfg_file_path)!
	assert out.username == cfg.username
	assert out.info.first_name == cfg.info.first_name
	assert out.info.last_name == envs.info.last_name
}

fn test_field_source_attributes() {
	struct AttrCfg {
	pub:
		json_only string @[cfgman: 'json']
		env_only  string @[cfgman: 'env']
		disabled  string @[cfgman: '-']
		both      string
	}

	path := '${os.vtmp_dir()}/cfgman_attr_test.json'
	os.write_file(path, '{"json_only":"from_json","env_only":"ignored_json","disabled":"ignored_json","both":"json_value"}') or { panic(err) }
	os.setenv('CFGMAN_JSON_ONLY', 'from_env', true)
	os.unsetenv('CFGMAN_ENV_ONLY')
	os.setenv('CFGMAN_DISABLED', 'from_env', true)
	os.setenv('CFGMAN_BOTH', 'from_env', true)

	mut cfg := load[AttrCfg](cfg_file_path: path)!
	assert cfg.json_only == 'from_json'
	assert cfg.env_only == ''
	assert cfg.disabled == ''
	assert cfg.both == 'from_env'
	assert cfg.json_only != 'from_env'
	assert cfg.both != 'json_value'

	os.setenv('CFGMAN_ENV_ONLY', 'from_env', true)
	cfg = load[AttrCfg](cfg_file_path: path)!
	assert cfg.env_only == 'from_env'
	assert cfg.disabled == ''
}

fn test_custom_env_name_attribute() {
	struct NamedCfg {
	pub:
		port int @[cfgman: 'env:CUSTOM_PORT']
		addr string
	}

	path := '${os.vtmp_dir()}/cfgman_named_attr_test.json'
	os.write_file(path, '{"port":1000,"addr":"127.0.0.1"}') or { panic(err) }
	os.setenv('CUSTOM_PORT', '4321', true)
	os.setenv('CFGMAN_PORT', '1111', true)

	cfg := load[NamedCfg](cfg_file_path: path)!
	assert cfg.port == 4321
	assert cfg.addr == '127.0.0.1'
}
