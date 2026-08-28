extends RefCounted

## 内容目录：全部玩法数据（卡牌/招式/敌人/遗物/事件）。
## 只含规则字段（费用/伤害/阶段/血量/权重/效果），零表现数据。
## 表现数据（颜色/标题/图标/立绘/音频）在 presentation_catalog.gd。
##
## 招式可用的专属机制字段：
##   strike_damage: Array[int]  多段招每段独立伤害（缺省用 damage）
##   fake: float                佯攻释放时刻（考验误判）
##   unblockable: bool          鬼手，不可防范，需符牌/2点消解
##   pull: bool                 命中后拖走玩家一张手牌（井中姐弟专属）
##   dice: bool                 开招掷骰决定伤害/窗口倍率（赌鬼专属）
##   tempo: float               每次完整出招后窗口与命中永久提前（剃头匠专属）
##   vengeance: bool            玩家防范失误后下一招伤害 +6（义庄看守专属）
##
## 敌人专属特质字段（trait）：
##   "paper_armor"  纸胎甲：完美弹反前，符牌伤害 -5（纸扎学徒）
##   "skittish"     惊灯：被完美弹反后下一招必为 quick（灯笼小鬼）
##   "heavy"        重尸：未防范命中 +4 伤害（更练尸）
##   "tempo"        加速：窗口随出招次数收窄（剃头匠）
##   "dice"         骰运：见上（赌鬼）
##   "vengeance"    记仇：见上（义庄看守）
##   "pull"         拖拽：招式可拉走手牌（井中姐弟）
## Boss 专属：phases 按血量切换招式池与强化（守灯人）。

const CARD_DATA := {
	# 斩类 (12 张)
	"attack": {"title": "斩纸", "class": "斩", "cost": 1, "damage": 5,
		"effects": [{"type": "damage", "amount": 5}],
		"upgrade": {"effects": [{"type": "damage", "amount": 8}]}},
	"shatter": {"title": "还刃", "class": "斩", "cost": 2, "damage": 12, "bonus": 6,
		"effects": [{"type": "damage", "amount": 12}, {"type": "charged_bonus", "amount": 6}],
		"upgrade": {"effects": [{"type": "damage", "amount": 15}, {"type": "charged_bonus", "amount": 8}]}},
	"duannian": {"title": "断念", "class": "斩", "cost": 2, "damage": 8, "discard_random": true,
		"effects": [{"type": "damage", "amount": 8}, {"type": "discard_random"}],
		"upgrade": {"effects": [{"type": "damage", "amount": 11}, {"type": "discard_random", "optional": true}]}},
	"zhuangzhong": {"title": "撞钟", "class": "斩", "cost": 2, "damage": 5, "stagger": 0.2,
		"effects": [{"type": "damage", "amount": 5}, {"type": "stagger", "amount": 0.2}],
		"upgrade": {"effects": [{"type": "damage", "amount": 7}, {"type": "stagger", "amount": 0.3}]}},
	"zhuying": {"title": "逐影", "class": "斩", "cost": 1, "damage": 4,
		"effects": [{"type": "damage", "amount": 4}],
		"upgrade": {"effects": [{"type": "damage", "amount": 6}, {"type": "draw", "amount": 1}]}},
	"liebo": {"title": "裂帛", "class": "斩", "cost": 1, "damage": 6,
		"effects": [{"type": "damage", "amount": 6}],
		"upgrade": {"effects": [{"type": "damage", "amount": 9}]}},
	"xuezhang": {"title": "血账", "class": "斩", "cost": 2, "damage": 6,
		"effects": [{"type": "damage", "amount": 6, "bonus_cond": "player_wounded", "bonus": 6}],
		"upgrade": {"effects": [{"type": "damage", "amount": 6, "bonus_cond": "player_wounded", "bonus": 10}]}},
	"baiguyin": {"title": "白骨引", "class": "斩", "cost": 2, "damage": 0,
		"effects": [{"type": "force_perfect"}],
		"upgrade": {"effects": [{"type": "force_perfect"}, {"type": "points", "amount": 1}]}},
	"shoulian": {"title": "收殓", "class": "斩", "cost": 3, "damage": 10,
		"effects": [{"type": "damage", "amount": 10, "bonus_cond": "enemy_low", "bonus": 8}],
		"upgrade": {"effects": [{"type": "damage", "amount": 13, "bonus_cond": "enemy_low", "bonus": 10}]}},
	"shuangdeng": {"title": "双灯照", "class": "斩", "cost": 3, "damage": 7, "heal": 3,
		"effects": [{"type": "damage", "amount": 7}, {"type": "heal", "amount": 3}],
		"upgrade": {"effects": [{"type": "damage", "amount": 9}, {"type": "heal", "amount": 6}]}},
	"yuangui": {"title": "怨归", "class": "斩", "cost": 3, "damage": 14,
		"effects": [{"type": "damage", "amount": 14}],
		"upgrade": {"effects": [{"type": "damage", "amount": 19}]}},
	"tianping": {"title": "极·天平倒悬", "class": "斩", "cost": 5, "damage": 30,
		"effects": [{"type": "damage", "amount": 30}],
		"upgrade": {"effects": [{"type": "damage", "amount": 38}]}},
	# 御类 (12 张)
	"guard": {"title": "镇煞", "class": "御", "cost": 2, "damage": 6, "stagger": 0.35,
		"effects": [{"type": "damage", "amount": 6}, {"type": "stagger", "amount": 0.35}, {"type": "grab_cancel"}],
		"upgrade": {"effects": [{"type": "damage", "amount": 9}, {"type": "stagger", "amount": 0.45}, {"type": "grab_cancel"}]}},
	"difan": {"title": "低幡", "class": "御", "cost": 1, "stagger": 0.25,
		"effects": [{"type": "stagger", "amount": 0.25}],
		"upgrade": {"effects": [{"type": "stagger", "amount": 0.35}]}},
	"jieshi": {"title": "借势", "class": "御", "cost": 1, "force_perfect": true,
		"effects": [{"type": "force_perfect"}],
		"upgrade": {"effects": [{"type": "force_perfect"}, {"type": "heal", "amount": 3}]}},
	"tongjing": {"title": "铜镜", "class": "御", "cost": 1, "mirror": 1,
		"effects": [{"type": "mirror", "amount": 1}],
		"upgrade": {"effects": [{"type": "mirror", "amount": 2}]}},
	"fuhunsuo": {"title": "缚魂索", "class": "御", "cost": 2, "stagger": 0.5,
		"effects": [{"type": "stagger", "amount": 0.5}],
		"upgrade": {"effects": [{"type": "stagger", "amount": 0.6}, {"type": "damage", "amount": 3}]}},
	"jiedao": {"title": "借刀", "class": "御", "cost": 2, "interrupt": true,
		"effects": [{"type": "interrupt"}],
		"upgrade": {"effects": [{"type": "interrupt"}, {"type": "points", "amount": 1}]}},
	"jinshen": {"title": "金身", "class": "御", "cost": 2, "golden": 1,
		"effects": [{"type": "golden", "amount": 1}],
		"upgrade": {"effects": [{"type": "golden", "amount": 2}]}},
	"podan": {"title": "破胆", "class": "御", "cost": 2, "fear_mul": 0.6,
		"effects": [{"type": "fear", "mul": 0.6}],
		"upgrade": {"effects": [{"type": "fear", "mul": 0.45}]}},
	"duanxiang": {"title": "断香", "class": "御", "cost": 1, "suppress_fake": true,
		"effects": [{"type": "suppress_fake"}],
		"upgrade": {"effects": [{"type": "suppress_fake"}, {"type": "widen_window", "amount": 0.06}]}},
	"yandeng": {"title": "延灯", "class": "御", "cost": 1,
		"effects": [{"type": "delay_impact", "amount": 0.4}, {"type": "widen_window", "amount": 0.06}],
		"upgrade": {"effects": [{"type": "delay_impact", "amount": 0.6}, {"type": "widen_window", "amount": 0.1}]}},
	"jiezou": {"title": "劫奏", "class": "御", "cost": 2,
		"effects": [{"type": "skip_next_strike"}],
		"upgrade": {"effects": [{"type": "skip_next_strike"}, {"type": "stagger", "amount": 0.2}]}},
	"huangdeng": {"title": "晃灯", "class": "御", "cost": 1,
		"effects": [{"type": "widen_window", "amount": 0.08}, {"type": "points", "amount": 1}],
		"upgrade": {"effects": [{"type": "widen_window", "amount": 0.12}, {"type": "points", "amount": 1}]}},
	# 佑类 (10 张)
	"shift": {"title": "续灯", "class": "佑", "cost": 2, "heal": 7,
		"effects": [{"type": "heal", "amount": 7}],
		"upgrade": {"effects": [{"type": "heal", "amount": 10}]}},
	"dengxin": {"title": "灯芯", "class": "佑", "cost": 1, "heal": 4,
		"effects": [{"type": "heal", "amount": 4}],
		"upgrade": {"effects": [{"type": "heal", "amount": 6}]}},
	"tianyou": {"title": "添油", "class": "佑", "cost": 2, "heal": 6,
		"effects": [{"type": "heal", "amount": 6}],
		"upgrade": {"effects": [{"type": "heal", "amount": 9}]}},
	"wenlu": {"title": "问路", "class": "佑", "cost": 1, "scry": 3,
		"effects": [{"type": "scry", "amount": 3}],
		"upgrade": {"effects": [{"type": "scry", "amount": 3}, {"type": "draw", "amount": 1}]}},
	"zhima": {"title": "纸马", "class": "佑", "cost": 2, "summon": 2,
		"effects": [{"type": "summon_draw", "amount": 2}],
		"upgrade": {"effects": [{"type": "summon_draw", "amount": 2}, {"type": "heal", "amount": 3}]}},
	"changming": {"title": "长明", "class": "佑", "cost": 2, "max_hp": 6,
		"effects": [{"type": "max_hp", "amount": 6}],
		"upgrade": {"effects": [{"type": "max_hp", "amount": 9}]}},
	"jieshou": {"title": "借寿", "class": "佑", "cost": 1, "heal": 10,
		"effects": [{"type": "heal", "amount": 10}, {"type": "damage_self", "amount": 3}],
		"upgrade": {"effects": [{"type": "heal", "amount": 13}, {"type": "damage_self", "amount": 3}]}},
	"anhun": {"title": "安魂", "class": "佑", "cost": 1, "cleanse": true,
		"effects": [{"type": "cleanse"}],
		"upgrade": {"effects": [{"type": "cleanse"}, {"type": "stagger", "amount": 0.2}]}},
	"tinggeng": {"title": "听更", "class": "佑", "cost": 1, "reveal_next": true,
		"effects": [{"type": "reveal_next"}],
		"upgrade": {"effects": [{"type": "reveal_next"}, {"type": "points", "amount": 1}]}},
	"chageng": {"title": "查更", "class": "佑", "cost": 1,
		"effects": [{"type": "reveal_next"}, {"type": "widen_window_next", "amount": 0.06}],
		"upgrade": {"effects": [{"type": "reveal_next"}, {"type": "widen_window_next", "amount": 0.1}]}},
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
	# —— 赌鬼专属 ——
	"gamble_dice": {
		"id": "gamble_dice", "title": "骨牌三掷", "duration": 2.20, "damage": 10,
		"window": 0.22, "fake": 1.20, "strikes": [0.60, 1.20, 1.80], "dice": true,
		"strike_damage": [5, 8, 12],
		"phases": [
			{"name": "raise", "until": 0.50},
			{"name": "commit", "until": 0.60, "cue": true},
			{"name": "hold", "until": 1.20, "cue": true},
			{"name": "commit", "until": 1.80, "cue": true},
			{"name": "recover", "until": 2.20},
		],
	},
	"gamble_flip": {
		"id": "gamble_flip", "title": "孤注·掀桌", "duration": 2.40, "damage": 18,
		"window": 0.35, "fake": 1.10, "unblockable": true,
		"phases": [
			{"name": "feint", "until": 1.10},
			{"name": "reveal", "until": 1.50, "cue": true},
			{"name": "reach", "until": 2.40},
			{"name": "recover", "until": 3.00},
		],
	},
	# —— 井中姐弟专属 ——
	"sisters_twin_whip": {
		"id": "sisters_twin_whip", "title": "双生水鞭", "duration": 1.85, "damage": 8,
		"window": 0.20, "strikes": [0.75, 1.35], "strike_damage": [6, 10],
		"phases": [
			{"name": "raise", "until": 0.60},
			{"name": "commit", "until": 0.75, "cue": true},
			{"name": "reset", "until": 1.20},
			{"name": "commit", "until": 1.35, "cue": true},
			{"name": "recover", "until": 1.85},
		],
	},
	"sisters_drag": {
		"id": "sisters_drag", "title": "沉井拖拽", "duration": 2.00, "damage": 10,
		"window": 0.30, "fake": 0.85, "unblockable": true, "pull": true,
		"phases": [
			{"name": "feint", "until": 0.85},
			{"name": "reveal", "until": 1.20, "cue": true},
			{"name": "reach", "until": 2.00},
			{"name": "recover", "until": 2.60},
		],
	},
	# —— 纸扎学徒专属 ——
	"paper_storm": {
		"id": "paper_storm", "title": "纸刃分飞", "duration": 1.85, "damage": 5,
		"window": 0.18, "strikes": [0.55, 1.05, 1.55],
		"phases": [
			{"name": "raise", "until": 0.45},
			{"name": "commit", "until": 0.55, "cue": true},
			{"name": "reset", "until": 0.95},
			{"name": "commit", "until": 1.05, "cue": true},
			{"name": "reset", "until": 1.45},
			{"name": "commit", "until": 1.55, "cue": true},
			{"name": "recover", "until": 1.85},
		],
	},
	"paper_funeral_kite": {
		"id": "paper_funeral_kite", "title": "纸鸢引魂", "duration": 2.30, "damage": 14,
		"window": 0.26, "fake": 0.95,
		"phases": [
			{"name": "raise", "until": 0.80},
			{"name": "hold", "until": 1.55, "cue": true},
			{"name": "commit", "until": 2.30, "cue": true},
			{"name": "recover", "until": 2.90},
		],
	},
	# —— 更练尸专属 ——
	"corpse_gong": {
		"id": "corpse_gong", "title": "更夫三锣", "duration": 2.30, "damage": 8,
		"window": 0.22, "strikes": [0.65, 1.30, 1.95], "strike_damage": [6, 8, 10],
		"phases": [
			{"name": "raise", "until": 0.55},
			{"name": "commit", "until": 0.65, "cue": true},
			{"name": "reset", "until": 1.20},
			{"name": "commit", "until": 1.30, "cue": true},
			{"name": "reset", "until": 1.85},
			{"name": "commit", "until": 1.95, "cue": true},
			{"name": "recover", "until": 2.30},
		],
	},
	"corpse_shroud_slam": {
		"id": "corpse_shroud_slam", "title": "裹尸砸地", "duration": 2.10, "damage": 15,
		"window": 0.32, "fake": 1.05,
		"phases": [
			{"name": "raise", "until": 0.85},
			{"name": "hold", "until": 1.60, "cue": true},
			{"name": "commit", "until": 2.10, "cue": true},
			{"name": "recover", "until": 2.70},
		],
	},
	# —— 剃头匠专属 ——
	"razor_waltz": {
		"id": "razor_waltz", "title": "剃刀圆舞", "duration": 2.40, "damage": 7,
		"window": 0.22, "strikes": [0.80, 1.40, 2.00], "tempo": 0.05,
		"phases": [
			{"name": "raise", "until": 0.65},
			{"name": "commit", "until": 0.80, "cue": true},
			{"name": "reset", "until": 1.25},
			{"name": "commit", "until": 1.40, "cue": true},
			{"name": "reset", "until": 1.85},
			{"name": "commit", "until": 2.00, "cue": true},
			{"name": "recover", "until": 2.40},
		],
	},
	"shear_bind": {
		"id": "shear_bind", "title": "剪刃缠发", "duration": 1.80, "damage": 12,
		"window": 0.26, "fake": 0.80,
		"phases": [
			{"name": "feint", "until": 0.80},
			{"name": "hold", "until": 1.30, "cue": true},
			{"name": "commit", "until": 1.80, "cue": true},
			{"name": "recover", "until": 2.30},
		],
	},
	# —— 灯笼小鬼专属 ——
	"imp_flame_leap": {
		"id": "imp_flame_leap", "title": "窜火扑灯", "duration": 1.55, "damage": 11,
		"window": 0.24, "fake": 0.70,
		"phases": [
			{"name": "feint", "until": 0.70},
			{"name": "commit", "until": 1.55, "cue": true},
			{"name": "recover", "until": 2.00},
		],
	},
	# —— 守灯人（Boss）三阶段专属 ——
	"boss_ceremony": {
		"id": "boss_ceremony", "title": "大典三斩", "duration": 3.10, "damage": 12,
		"window": 0.22, "strikes": [0.90, 1.80, 2.70], "strike_damage": [10, 12, 14],
		"phases": [
			{"name": "raise", "until": 0.75},
			{"name": "commit", "until": 0.90, "cue": true},
			{"name": "reset", "until": 1.65},
			{"name": "commit", "until": 1.80, "cue": true},
			{"name": "reset", "until": 2.55},
			{"name": "commit", "until": 2.70, "cue": true},
			{"name": "recover", "until": 3.10},
		],
	},
	"boss_flame_domain": {
		"id": "boss_flame_domain", "title": "灯焰领域", "duration": 2.40, "damage": 16,
		"window": 0.35, "fake": 1.10, "unblockable": true,
		"phases": [
			{"name": "feint", "until": 1.10},
			{"name": "reveal", "until": 1.50, "cue": true},
			{"name": "reach", "until": 2.40},
			{"name": "recover", "until": 3.00},
		],
	},
	"keeper_ash_rain": {
		"id": "keeper_ash_rain", "title": "纸灰骤雨", "duration": 2.15, "damage": 6,
		"window": 0.20, "strikes": [0.55, 1.05, 1.55, 2.00],
		"phases": [
			{"name": "raise", "until": 0.40},
			{"name": "commit", "until": 0.55, "cue": true},
			{"name": "reset", "until": 0.90},
			{"name": "commit", "until": 1.05, "cue": true},
			{"name": "reset", "until": 1.40},
			{"name": "commit", "until": 1.55, "cue": true},
			{"name": "reset", "until": 1.85},
			{"name": "commit", "until": 2.00, "cue": true},
			{"name": "recover", "until": 2.15},
		],
	},
	"keeper_wick_snuff": {
		"id": "keeper_wick_snuff", "title": "掐芯灭灯", "duration": 2.00, "damage": 20,
		"window": 0.28, "fake": 0.95, "unblockable": true, "pull": true,
		"phases": [
			{"name": "feint", "until": 0.95},
			{"name": "reveal", "until": 1.30, "cue": true},
			{"name": "reach", "until": 2.00},
			{"name": "recover", "until": 2.60},
		],
	},
	"keeper_finale": {
		"id": "keeper_finale", "title": "极·长夜收灯", "duration": 3.60, "damage": 8,
		"window": 0.24, "strikes": [0.70, 1.30, 1.90, 2.50, 3.10],
		"strike_damage": [8, 8, 8, 12, 20],
		"phases": [
			{"name": "raise", "until": 0.55},
			{"name": "commit", "until": 0.70, "cue": true},
			{"name": "reset", "until": 1.15},
			{"name": "commit", "until": 1.30, "cue": true},
			{"name": "reset", "until": 1.75},
			{"name": "commit", "until": 1.90, "cue": true},
			{"name": "reset", "until": 2.35},
			{"name": "commit", "until": 2.50, "cue": true},
			{"name": "hold", "until": 2.90, "cue": true},
			{"name": "commit", "until": 3.10, "cue": true},
			{"name": "recover", "until": 3.60},
		],
	},
}

## 敌人定义。可选字段：
##   phases: [{below: 0.66, moves: [...], title, announce}]  Boss 阶段切换（血量比例）
##   trait:  专属规则 id（见文件头注释）
const ENEMIES := {
	"watchman": {"name": "前任更夫", "hp": 46, "moves": ["red", "blue", "green"], "opening": "red"},
	"lantern_imp": {"name": "灯笼小鬼", "hp": 30, "dmg_mul": 0.8, "moves": ["quick", "red"], "opening": "quick", "reactive": true, "trait": "skittish"},
	"patrol_corpse": {"name": "更练尸", "hp": 38, "dmg_mul": 0.9, "moves": ["corpse_gong", "corpse_shroud_slam"], "opening": "corpse_gong", "reactive": true, "trait": "heavy"},
	"barber_ghost": {"name": "剃头匠", "hp": 28, "dmg_mul": 1.0, "moves": ["razor_waltz", "shear_bind", "quick"], "opening": "razor_waltz", "reactive": true, "trait": "tempo"},
	"paper_apprentice": {"name": "纸扎学徒", "hp": 24, "dmg_mul": 0.9, "moves": ["paper_storm", "paper_funeral_kite"], "opening": "paper_storm", "reactive": true, "trait": "paper_armor"},
	"well_sisters": {"name": "井中姐弟", "hp": 30, "dmg_mul": 1.0, "moves": ["sisters_twin_whip", "sisters_drag"], "opening": "sisters_twin_whip", "reactive": true, "trait": "pull"},
	"gambler_ghost": {"name": "赌鬼", "hp": 30, "dmg_mul": 0.9, "moves": ["gamble_dice", "gamble_flip"], "opening": "gamble_dice", "reactive": true, "trait": "dice"},
	"mortuary_warden": {"name": "义庄看守", "hp": 36, "dmg_mul": 1.1, "moves": ["red", "corpse_gong", "green"], "opening": "red", "reactive": true, "trait": "vengeance"},
	"lantern_keeper": {
		"name": "守灯人", "hp": 40, "dmg_mul": 1.15, "opening": "boss_ceremony", "reactive": true,
		"moves": ["boss_ceremony", "quick"],
		"phases": [
			{"below": 0.66, "moves": ["boss_ceremony", "keeper_ash_rain", "boss_flame_domain"],
				"title": "撕灯", "announce": "守灯人撕下灯面——火舌顺着纸纹爬满全身！"},
			{"below": 0.33, "moves": ["keeper_ash_rain", "keeper_wick_snuff", "keeper_finale"],
				"title": "收灯", "announce": "灯焰倒卷入喉——守灯人要亲手掐灭这盏灯！"},
		],
	},
}

## 遗物：局内被动。mods 字段映射到 BattleSimulation.run_mods。
const RELICS := {
	"old_rope": {"name": "旧麻绳", "desc": "每战开始时还愿 +1", "mods": {"start_points": 1}},
	"paper_lantern": {"name": "纸灯笼", "desc": "灯油上限 +12", "mods": {"max_hp_bonus": 12}},
	"chime": {"name": "更铃", "desc": "完美接刀额外还愿 +1", "mods": {"perfect_extra_point": 1}},
	"ink_brush": {"name": "判官笔", "desc": "每战第一张符牌免费", "mods": {"first_card_free": true}},
	"nail": {"name": "镇魂钉", "desc": "凝滞时间 +25%", "mods": {"stagger_mul": 1.25}},
	"well_water": {"name": "井水一壶", "desc": "每战胜利后回复 6 灯油", "mods": {"heal_after_battle": 6}},
	"funeral_bell": {"name": "送葬铃", "desc": "躁动阈值降为 6 还愿", "mods": {"rage_threshold": 6}},
	"red_thread": {"name": "红绳", "desc": "每战首次防范失误不进入冷却", "mods": {"first_miss_free": true}},
	"silver_coin": {"name": "压岁银钱", "desc": "战后纸钱 +8", "mods": {"gold_bonus": 8}},
	"wisp_follower": {"name": "游魂随灯", "desc": "还愿上限 +2", "mods": {"max_points_bonus": 2}},
}

## 难度阶梯（局外解锁，通关后开放下一级）。
const DIFFICULTIES := {
	0: {"name": "一更·风紧", "enemy_hp_mul": 1.0, "enemy_dmg_mul": 1.0, "gold_mul": 1.0, "desc": "标准的夜巡"},
	1: {"name": "二更·雨急", "enemy_hp_mul": 1.15, "enemy_dmg_mul": 1.1, "gold_mul": 1.1, "desc": "怨鬼更耐打，出手更沉"},
	2: {"name": "三更·灯摇", "enemy_hp_mul": 1.3, "enemy_dmg_mul": 1.2, "gold_mul": 1.2, "desc": "灯油 -10，纸钱 +20%"},
	3: {"name": "四更·天未明", "enemy_hp_mul": 1.5, "enemy_dmg_mul": 1.3, "gold_mul": 1.35, "desc": "守灯人的夜晚，不留情面"},
}

## 事件：剧情进入玩法。effects 由 RunFlow 执行；battle_flag 写入 RunState.flags，
## 由 BattleSimulation / RunFlow 在对应战斗中读取，改变敌人规则或奖励。
const EVENTS := {
	"paper_clue": {
		"title": "纸人百号",
		"body": "学徒的第九十九个纸人还缺一张真脸。三张纸胎上的门牌，都指着义庄 13 号。你认得那扇门——今夜你要去的地方。",
		"choices": [
			{"text": "帮他开脸（灯油 +12，纸扎学徒的纸胎甲会被识破）",
				"effects": [{"type": "heal", "amount": 12}], "flags": {"paper_face_done": true}},
			{"text": "婉拒离开（抄一张佑类符牌）",
				"effects": [{"type": "grant_card", "class": "佑"}]},
		],
	},
	"gambler_debt": {
		"title": "赌债",
		"body": "赌鬼把骰子撒在地上：那晚满城都在排队投胎，他押阎王没空管——他输了。「再陪我押一把，」他说，「这回我让你赢。」",
		"choices": [
			{"text": "押一局（五五开：赢 30 纸钱 / 输 12 灯油）",
				"effects": [{"type": "gamble", "win": {"type": "gold", "amount": 30}, "lose": {"type": "damage", "amount": 12}}],
				"flags": {"dice_rigged": true}},
			{"text": "不赌（收下他抵债的 15 纸钱）",
				"effects": [{"type": "gold", "amount": 15}]},
		],
	},
	"well_voice": {
		"title": "井中回声",
		"body": "井口漫出湿冷的水汽。姐弟俩的声音在井壁间打转：「替我们捞一捞井底的灯。」你俯身，水面浮着你自己的脸。",
		"choices": [
			{"text": "俯身听井（记下他们的拍子——井中姐弟出招窗口变宽）",
				"effects": [], "flags": {"well_blessing": true}},
			{"text": "投一枚银钱下去（纸钱 -10，得一张御类符牌）",
				"effects": [{"type": "gold", "amount": -10}, {"type": "grant_card", "class": "御"}]},
		],
	},
	"mourner_song": {
		"title": "哭丧调",
		"body": "巷尾的老妪在替谁哭丧，调子忽快忽慢，和更点咬在一起。她朝你招手：会唱的人，夜里不容易迷路。",
		"choices": [
			{"text": "跟着唱（守灯人第一阶段的拍子会慢半拍）",
				"effects": [], "flags": {"mourner_song": true}},
			{"text": "替她点灯（灯油 +8）",
				"effects": [{"type": "heal", "amount": 8}]},
		],
	},
	"stray_wisp": {
		"title": "迷路游魂",
		"body": "一缕游魂缠上灯罩，不吵不闹，只是跟着你走。它生前大概也是打更的。",
		"choices": [
			{"text": "引它入灯超度（从牌组删一张牌，灯油 +4）",
				"effects": [{"type": "remove_card"}, {"type": "heal", "amount": 4}]},
			{"text": "由它跟着（遗物：游魂随灯）",
				"effects": [{"type": "grant_relic", "id": "wisp_follower"}]},
		],
	},
	"night_market": {
		"title": "鬼市摊",
		"body": "雨棚下亮着一盏气死风灯，摊主的脸隐在斗笠下。摊上什么都有，只收纸钱。",
		"choices": [
			{"text": "买一张符牌（纸钱 -25）",
				"effects": [{"type": "gold", "amount": -25}, {"type": "grant_card"}]},
			{"text": "买一口热汤（纸钱 -15，灯油 +18）",
				"effects": [{"type": "gold", "amount": -15}, {"type": "heal", "amount": 18}]},
			{"text": "什么都不买"},
		],
	},
	"temple_shelter": {
		"title": "破庙歇脚",
		"body": "山门塌了半边，神像的脸被烟熏黑了。供桌倒还能用——有人在这儿留了半截蜡烛和一张没写完的符。",
		"choices": [
			{"text": "把符补完（升级牌组里的一张牌）",
				"effects": [{"type": "upgrade_card"}]},
			{"text": "靠着神像睡一觉（灯油回复 30%）",
				"effects": [{"type": "heal_pct", "pct": 30}]},
		],
	},
}

## 商店库存模板（价格在 RunFlow 依难度/遗物浮动）。
const SHOP_TEMPLATE := {
	"cards": 2,
	"relic": 1,
	"remove_price": 40,
	"heal_price": 30,
	"heal_amount": 20,
}
