class_name SoilState

## Defines the states of soil tiles in Night Harvest.
enum State {
	UNTILLED = 0,
	HOED = 1,
	WATERED = 2
}

static func get_state_name(state: State) -> String:
	match state:
		State.UNTILLED:
			return "UNTILLED"
		State.HOED:
			return "HOED"
		State.WATERED:
			return "WATERED"
	return "UNKNOWN"
