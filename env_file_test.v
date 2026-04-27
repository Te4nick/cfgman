module cfgman

import os

fn test_dotenv_values() {
	os.setenv('EXTERNAL_DOTENV_VALUE', 'from_env', true)
	values :=
		env_values('# comment\nexport APP_NAME=cfgman\nPASSWORD = "pa#ss word" # ignored\nSINGLE="raw value"\nURL=\${APP_NAME}-\${EXTERNAL_DOTENV_VALUE}\nINLINE=hello # comment\nEMPTY=\n')!
	assert values['APP_NAME'] == 'cfgman'
	assert values['PASSWORD'] == 'pa#ss word'
	assert values['SINGLE'] == 'raw value'
	assert values['URL'] == 'cfgman-from_env'
	assert values['INLINE'] == 'hello'
	assert values['EMPTY'] == ''
}

fn test_load_env_file_respects_overrides() {
	path := '${os.vtmp_dir()}/cfgman_test.env'
	os.write_file(path, 'CFGMAN_DOTENV_TEST=file\nCFGMAN_DOTENV_NEW=value\n')!
	os.setenv('CFGMAN_DOTENV_TEST', 'existing', true)

	load_env_file(path, false)!
	assert os.getenv('CFGMAN_DOTENV_TEST') == 'existing'
	assert os.getenv('CFGMAN_DOTENV_NEW') == 'value'

	load_env_file(path, true)!
	assert os.getenv('CFGMAN_DOTENV_TEST') == 'file'
}
