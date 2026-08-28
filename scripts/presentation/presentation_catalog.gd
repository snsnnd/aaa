extends RefCounted

## 表现目录：所有纯表现数据（文案/颜色/图标/立绘/音频路径）。
## 铁律：BattleSimulation 不得引用本文件；本文件不含任何玩法数值。
## 换皮肤/换音效/换图标只改这里，战斗结果（content_hash）不受影响。

const CARD_PRESENTATION := {
	"attack": {"title": "斩纸", "color": Color("d3a44b"), "icon": "res://assets/demo/card_attack.png"},
	"shatter": {"title": "还刃", "color": Color("bd3d45"), "icon": "res://assets/demo/card_shatter.png"},
	"guard": {"title": "镇煞", "color": Color("43a9b2"), "icon": "res://assets/demo/card_guard.png"},
	"shift": {"title": "续灯", "color": Color("6d9663"), "icon": "res://assets/demo/card_shift.png"},
	"duannian": {"title": "断念", "color": Color("c98862"), "icon": "res://assets/game/cards/card_duannian.png"},
	"dengxin": {"title": "灯芯", "color": Color("8fae72"), "icon": "res://assets/game/cards/card_dengxin.png"},
	"zhuangzhong": {"title": "撞钟", "color": Color("b0925c"), "icon": "res://assets/game/cards/card_zhuangzhong.png"},
	"anhun": {"title": "安魂", "color": Color("9ab0a2"), "icon": "res://assets/game/cards/card_anhun.png"},
	"duanxiang": {"title": "断香", "color": Color("7fa89a"), "icon": "res://assets/game/cards/card_duanxiang.png"},
	"tinggeng": {"title": "听更", "color": Color("8fae9e"), "icon": "res://assets/game/cards/card_tinggeng.png"},
	"jieshi": {"title": "借势", "color": Color("c9b96a"), "icon": "res://assets/game/cards/card_jieshi.png"},
	"tongjing": {"title": "铜镜", "color": Color("a8c0c8"), "icon": "res://assets/game/cards/card_tongjing.png"},
	"podan": {"title": "破胆", "color": Color("9a7ab8"), "icon": "res://assets/game/cards/card_podan.png"},
	"jinshen": {"title": "金身", "color": Color("c8b88a"), "icon": "res://assets/game/cards/card_jinshen.png"},
}

const MOVE_PRESENTATION := {
	"red": {"color": Color("bd3d45")},
	"blue": {"color": Color("43a9b2")},
	"green": {"color": Color("6d9663")},
	"quick": {"color": Color("d0a45c")},
}

const ENEMY_PRESENTATION := {
	"watchman": {"texture": "res://assets/demo/enemy_watchman.png"},
	"lantern_imp": {"texture": "res://assets/game/enemies/lantern_imp.png"},
	"patrol_corpse": {"texture": "res://assets/game/enemies/patrol_corpse.png"},
	"barber_ghost": {"texture": "res://assets/game/enemies/barber_ghost.png"},
	"paper_apprentice": {"texture": "res://assets/game/enemies/paper_apprentice.png"},
	"well_sisters": {"texture": "res://assets/game/enemies/well_sisters.png"},
	"gambler_ghost": {"texture": "res://assets/game/enemies/gambler_ghost.png"},
	"mortuary_warden": {"texture": "res://assets/game/enemies/mortuary_warden.png"},
	"lantern_keeper": {"texture": "res://assets/game/enemies/lantern_keeper.png"},
}

const AUDIO := {
	"parry": "res://assets/demo/audio/parry.wav",
	"hurt": "res://assets/demo/audio/hurt.wav",
	"card": "res://assets/demo/audio/card.wav",
	"warning": "res://assets/demo/audio/warning.wav",
}
