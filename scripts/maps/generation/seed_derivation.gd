extends RefCounted

# Explicit 31-bit integer arithmetic; independent of Godot RNG implementation.
# The largest intermediate is below signed int64 overflow on every platform.
const MODULUS := 2147483647
const MULTIPLIER := 48271
var _state: int=1

static func derive(seed_value: int, domain: String) -> int:
	var value: int=seed_value & 0x7fffffff
	for byte in domain.to_utf8_buffer(): value=((value ^ byte)*16777619) & 0x7fffffff
	return value % (MODULUS-1)+1

static func stream(seed_value: int, domain: String) -> RefCounted:
	var result:=new()
	result._state=derive(seed_value,domain)
	return result

func next_int() -> int:
	_state=(_state*MULTIPLIER)%MODULUS
	return _state

func between(low: int, high: int) -> int:
	assert(high>=low and high-low<MODULUS-1)
	var span:=high-low+1
	var limit: int=(MODULUS-1)-((MODULUS-1)%span)
	var value:=next_int()-1
	while value>=limit: value=next_int()-1
	return low+value%span
