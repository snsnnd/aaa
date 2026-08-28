extends RefCounted

## 反馈分层（game-feel skill: importance tiers）：
## 把敌人受击层级映射到统一的反馈强度——hitstop 时长、震屏、SFX。
## 原则：hitstop/震屏只给重要时刻，且短暂、必回落（juice 是瞬态不是新常态）。

const TIERS := {
	"LIGHT":     {"hitstop": 0.0,  "hitstop_scale": 1.0,  "trauma": 0.05, "sfx": "sfx_impact_light",  "sfx_db": -6.0},
	"MEDIUM":    {"hitstop": 0.0,  "hitstop_scale": 1.0,  "trauma": 0.12, "sfx": "sfx_impact_medium", "sfx_db": -3.0},
	"HEAVY":     {"hitstop": 0.05, "hitstop_scale": 0.25, "trauma": 0.24, "sfx": "sfx_impact_heavy",  "sfx_db": 0.0},
	"BREAK":     {"hitstop": 0.08, "hitstop_scale": 0.2,  "trauma": 0.40, "sfx": "sfx_impact_break",  "sfx_db": 0.0},
	"FINISHER":  {"hitstop": 0.12, "hitstop_scale": 0.15, "trauma": 0.60, "sfx": "sfx_finisher",      "sfx_db": 2.0},
	"STAGGER":   {"hitstop": 0.04, "hitstop_scale": 0.3,  "trauma": 0.08, "sfx": "sfx_impact_light",  "sfx_db": -4.0},
	"INTERRUPT": {"hitstop": 0.05, "hitstop_scale": 0.25, "trauma": 0.20, "sfx": "sfx_impact_medium", "sfx_db": -2.0},
}


static func tier(level: String) -> Dictionary:
	return TIERS.get(level, TIERS["LIGHT"])
