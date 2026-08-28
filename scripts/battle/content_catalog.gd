extends RefCounted

## 内容目录：全部玩法数据（卡牌/招式/敌人）。
## 只含规则字段（费用/伤害/阶段/血量/权重），零表现数据。
## 表现数据（颜色/标题/图标/立绘/音频）在 presentation_catalog.gd。

const CARD_DATA := {
	"attack": {"title": "斩纸", "class": "斩", "cost": 1, "damage": 5},
	"shatter": {"title": "还刃", "class": "斩", "cost": 2, "damage": 12, "bonus": 6},
	"guard": {"title": "镇煞", "class": "御", "cost": 2, "damage": 6, "stagger": 0.35},
	"shift": {"title": "续灯", "class": "佑", "cost": 2, "heal": 7},
	"duannian": {"title": "断念", "class": "斩", "cost": 2, "damage": 8, "discard_random": true},
	"dengxin": {"title": "灯芯", "class": "佑", "cost": 1, "heal": 4},
	"zhuangzhong": {"title": "撞钟", "class": "斩", "cost": 2, "damage": 5, "stagger": 0.2},
	"anhun": {"title": "安魂", "class": "御", "cost": 1, "cleanse": true},
	"duanxiang": {"title": "断香", "class": "御", "cost": 1, "suppress_fake": true},
	"tinggeng": {"title": "听更", "class": "佑", "cost": 1, "reveal_next": true},
	"jieshi": {"title": "借势", "class": "御", "cost": 1, "force_perfect": true},
	"tongjing": {"title": "铜镜", "class": "御", "cost": 1, "mirror": 1},
	"podan": {"title": "破胆", "class": "御", "cost": 2, "fear_mul": 0.6},
	"jinshen": {"title": "金身", "class": "御", "cost": 2, "golden": 1},
}

const MOVES := {
	"red": {
		"id": "red", "title": "蓄势慢刀", "duration": 2.8, "damage": 16,
		"window": 0.30, "fake": 1.25,
		"phases": [
			{"name": "raise", "until": 1.00},
			{"name": "hold", "until": 1.90, "cue": true},
			{"name": "commit", "until": 2.80, "cue": true},
			{"name": "recover", "until": 3.42},
		],
	},
	"blue": {
		"id": "blue", "title": "变拍二连", "duration": 2.05, "damage": 7,
		"window": 0.20, "strikes": [0.82, 1.56],
		"phases": [
			{"name": "raise", "until": 0.69},
			{"name": "commit", "until": 0.82, "cue": true},
			{"name": "reset", "until": 1.43},
			{"name": "commit", "until": 1.56, "cue": true},
			{"name": "recover", "until": 2.26},
		],
	},
	"green": {
		"id": "green", "title": "佯攻擒拿", "duration": 1.9, "damage": 10,
		"window": 0.34, "fake": 0.78, "unblockable": true,
		"phases": [
			{"name": "feint", "until": 0.79},
			{"name": "reveal", "until": 1.14, "cue": true},
			{"name": "reach", "until": 1.90},
			{"name": "recover", "until": 2.52},
		],
	},
	"quick": {
		"id": "quick", "title": "疾斩", "duration": 1.0, "damage": 9,
		"window": 0.22, "strikes": [0.90],
		"phases": [
			{"name": "raise", "until": 0.55},
			{"name": "commit", "until": 0.90, "cue": true},
			{"name": "recover", "until": 1.32},
		],
	},
}

const ENEMIES := {
	"watchman": {"name": "前任更夫", "hp": 46, "moves": ["red", "blue", "green"], "opening": "red"},
	"lantern_imp": {"name": "灯笼小鬼", "hp": 30, "dmg_mul": 0.8, "moves": ["quick", "red"], "opening": "quick", "reactive": true},
	"patrol_corpse": {"name": "更练尸", "hp": 38, "dmg_mul": 0.9, "moves": ["blue", "red"], "opening": "blue", "reactive": true},
	"barber_ghost": {"name": "剃头匠", "hp": 28, "dmg_mul": 1.0, "moves": ["blue", "quick"], "opening": "blue", "reactive": true},
	"paper_apprentice": {"name": "纸扎学徒", "hp": 24, "dmg_mul": 0.9, "moves": ["red", "green"], "opening": "red", "reactive": true},
	"well_sisters": {"name": "井中姐弟", "hp": 30, "dmg_mul": 1.0, "moves": ["blue", "green"], "opening": "blue", "reactive": true},
	"gambler_ghost": {"name": "赌鬼", "hp": 30, "dmg_mul": 0.9, "moves": ["quick", "blue", "red"], "opening": "quick", "reactive": true},
	"mortuary_warden": {"name": "义庄看守", "hp": 36, "dmg_mul": 1.1, "moves": ["red", "blue", "green", "quick"], "opening": "red", "reactive": true},
	"lantern_keeper": {"name": "守灯人", "hp": 40, "dmg_mul": 1.15, "moves": ["red", "quick", "blue", "green"], "opening": "red", "reactive": true},
}
