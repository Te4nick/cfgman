module cfgman

import os
import x.json2


struct TestCfg {
pub:
	port int
	addr string
}

fn set_envs[T](envs T, env_prefix string) {
	$if T !is $struct {
		panic("set_envs generics should be structs")
	}

	$for field in T.fields {
		env_name := "${env_prefix}_${field.name.to_upper()}"
		$if field.unaliased_typ is $struct {
			set_envs(envs.$(field.name), env_name)
		} $else {
			envs_empty := T{}
			if envs.$(field.name) != envs_empty.$(field.name) {
				env_str_val:=envs.$(field.name).str()
				os.setenv(env_name, env_str_val, false)
				println("set_envs: ${env_name}=${env_str_val}")
			}
		}
	}
}

fn pre_test[T](cfg T, envs ?T, params CfgParams) {
	$if T !is $struct {
		panic("pre_test generics should be structs")
	}
	
	os.write_file(params.cfg_file_path, json2.encode(cfg)) or {panic(err)}

	if envs != none {
		set_envs(envs, params.env_prefix)
	}
}

fn test_basic() {
	tcfg := TestCfg{port: 2112, addr: "127.0.0.1"}
	envs := TestCfg{port: 1234}
	cfg_file_path := "${os.vtmp_dir()}/test1.json"
	pre_test(tcfg, envs, cfg_file_path: cfg_file_path)
	cfg := parse[TestCfg](cfg_file_path: cfg_file_path)!
	assert cfg.port == envs.port
	assert cfg.addr == tcfg.addr
}


struct Info {
	pub:
		first_name string
		last_name string
	}
	struct Cfg{
	pub:
		username string
		info Info
	}

fn test_included_struct() {
	
	cfg := Cfg{username: "Te4nick", info: Info{first_name: "Jack", last_name: "London"}}
	envs := Cfg{info: Info{last_name: "Daniels"}}
	cfg_file_path := "${os.vtmp_dir()}/test_included_struct.json"
	pre_test(cfg, envs, cfg_file_path: cfg_file_path)
	out := parse[Cfg](cfg_file_path: cfg_file_path)!
	assert out.username == cfg.username
	assert out.info.first_name == cfg.info.first_name
	assert out.info.last_name == envs.info.last_name
}