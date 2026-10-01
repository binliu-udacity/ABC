extends RefCounted

# 守兵数值。间隔单位是秒，价格单位是墨滴。
const UNITS: Dictionary = {
	"砚": {"cost": 50, "cooldown": 3.0, "hp": 60.0, "damage": 0.0, "interval": 30.0},
	"弓": {"cost": 100, "cooldown": 5.0, "hp": 80.0, "damage": 30.0, "interval": 1.0},
	"盾": {"cost": 50, "cooldown": 10.0, "hp": 1200.0, "damage": 0.0, "interval": 0.0},
	"冰": {"cost": 150, "cooldown": 5.0, "hp": 81.0, "damage": 30.0, "interval": 1.0},
	"雷": {"cost": 25, "cooldown": 20.0, "hp": 60.0, "damage": 1800.0, "interval": 15.0},
	"焰": {"cost": 200, "cooldown": 6.0, "hp": 80.0, "damage": 38.0, "interval": 1.0},
	"霜": {"cost": 250, "cooldown": 8.0, "hp": 95.0, "damage": 35.0, "interval": 1.0},
	"弩": {"cost": 180, "cooldown": 6.0, "hp": 80.0, "damage": 32.0, "interval": 0.75},
	"电": {"cost": 250, "cooldown": 8.0, "hp": 91.0, "damage": 28.0, "interval": 1.0},
	"闪": {"cost": 300, "cooldown": 8.0, "hp": 90.0, "damage": 25.0, "interval": 1.0},
}
