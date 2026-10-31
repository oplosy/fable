class_name Deathmatch
extends RefCounted

## Free-for-all: every kill scores a point and the first to `kill_limit` wins. Players are
## indexes, so the score knows nothing about fighters. A self-kill or a death with no
## killer changes nothing.

signal score_changed(player: int, kills: int)
signal match_ended(winner: int)

var kill_limit := 20
var kills: Array[int] = []
## Index of the winning player, -1 while the match runs.
var winner := -1


func _init(players: int) -> void:
	kills.resize(players)


func is_over() -> bool:
	return winner >= 0


## `killer` is -1 when nobody gets the credit. Kills after the match ended do not count.
func record_kill(victim: int, killer: int) -> void:
	if is_over() or killer < 0 or killer == victim:
		return
	kills[killer] += 1
	score_changed.emit(killer, kills[killer])
	if kills[killer] >= kill_limit:
		winner = killer
		match_ended.emit(winner)
