extends RefCounted

# 孩子的五种守兵。间隔单位是秒，价格单位是墨滴。
const UNITS: Dictionary = {
	"砚": {"cost": 50, "cooldown": 3.0, "hp": 60.0, "damage": 0.0, "interval": 30.0},
	"弓": {"cost": 100, "cooldown": 5.0, "hp": 80.0, "damage": 30.0, "interval": 1.0},
	"盾": {"cost": 50, "cooldown": 10.0, "hp": 1200.0, "damage": 0.0, "interval": 0.0},
	"冰": {"cost": 150, "cooldown": 5.0, "hp": 81.0, "damage": 30.0, "interval": 1.0},
	"雷": {"cost": 25, "cooldown": 20.0, "hp": 60.0, "damage": 1800.0, "interval": 15.0},
}
