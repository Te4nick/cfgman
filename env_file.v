module cfgman

import os

// env_values parses env content using python-dotenv style rules.
pub fn env_values(data string) !map[string]string {
	mut values := map[string]string{}
	for raw_line in data.split_into_lines() {
		l := raw_line.trim_space()
		if l == '' || l.starts_with('#') {
			continue
		}
		k, v := parse_env_line(l)!
		values[k] = expand_variables(v, values)
	}
	return values
}

// parse_env_file parses a env file without mutating the process environment.
pub fn parse_env_file(path string) !map[string]string {
	return env_values(os.read_file(path)!)!
}

// load_env_file sets env variables from file. Existing env values are kept when overrides=false.
pub fn load_env_file(path string, overrides bool) !map[string]string {
	values := parse_env_file(path)!
	for k, v in values {
		os.setenv(k, v, overrides)
	}

	return values
}

fn parse_env_line(line string) !(string, string) {
	mut src := line
	if src.starts_with('export ') {
		src = src[7..].trim_space()
	}

	eq_idx := src.index('=') or { return error('invalid env line: missing =') }
	key := src[..eq_idx].trim_space()
	if !valid_env_key(key) {
		return error('invalid env key')
	}

	raw_val := src[eq_idx + 1..].trim_space()
	return key, parse_env_value(raw_val)!
}

fn valid_env_key(key string) bool {
	if key == '' {
		return false
	}
	for i, ch in key {
		if ch.is_letter() || ch.is_digit() || ch == `_` || (i == 0 && ch == `.`) {
			continue
		}
		return false
	}
	return true
}

fn parse_env_value(raw string) !string {
	if raw == '' {
		return ''
	}

	if raw[0] == `'` {
		return parse_env_quoted_value(raw, `'`, false)
	}
	if raw[0] == `"` {
		return parse_env_quoted_value(raw, `"`, true)
	}

	mut out := []u8{}
	for i := 0; i < raw.len; i++ {
		ch := raw[i]
		if ch == `#` && (i == 0 || raw[i - 1].is_space()) {
			break
		}
		out << ch
	}
	return out.bytestr().trim_space()
}

fn parse_env_quoted_value(raw string, quote u8, escapes bool) !string {
	mut out := []u8{}
	mut escaped := false
	for i := 1; i < raw.len; i++ {
		ch := raw[i]
		if escaped {
			if escapes {
				out << match ch {
					`n` { `\n` }
					`r` { `\r` }
					`t` { `\t` }
					else { ch }
				}
			} else {
				out << ch
			}
			escaped = false
			continue
		}

		if ch == `\\` {
			escaped = true
			continue
		}
		if ch == quote {
			return out.bytestr()
		}
		out << ch
	}
	return error('unterminated quoted env value')
}

fn expand_variables(value string, values map[string]string) string {
	mut out := []u8{}
	mut i := 0
	for i < value.len {
		if i + 2 < value.len && value[i] == `$` && value[i + 1] == `{` {
			end := value[i + 2..].index('}') or {
				out << value[i]
				i++
				continue
			}
			name := value[i + 2..i + 2 + end]
			if name in values {
				out << values[name].bytes()
			} else {
				out << os.getenv(name).bytes()
			}
			i += end + 3
			continue
		}
		out << value[i]
		i++
	}
	return out.bytestr()
}
