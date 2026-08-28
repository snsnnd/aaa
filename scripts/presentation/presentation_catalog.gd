extends RefCounted

## 表现目录：所有纯表现数据（文案/颜色/图标/立绘/音频路径）。
## 铁律：BattleSimulation 不得引用本文件；本文件不含任何玩法数值。
## 换皮肤/换音效/换图标只改这里，战斗结果（content_hash）不受影响。

const CARD_PRESENTATION := {
	"attack": {"title": "斩纸", "color": Color("d3a44b"), "icon": "res://assets/game/cards/card_attack.png"},
	"shatter": {"title": "还刃", "color": Color("bd3d45"), "icon": "res://assets/game/cards/card_shatter.png"},
	"guard": {"title": "镇煞", "color": Color("43a9b2"), "icon": "res://assets/game/cards/card_guard.png"},
	"shift": {"title": "续灯", "color": Color("6d9663"), "icon": "res://assets/game/cards/card_shift.png"},
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
	"zhuying": {"title": "逐影", "color": Color("e09c48"), "icon": "res://assets/game/cards/card_zhuying.png"},
	"liebo": {"title": "裂帛", "color": Color("d85c54"), "icon": "res://assets/game/cards/card_liebo.png"},
	"xuezhang": {"title": "血账", "color": Color("c83832"), "icon": "res://assets/game/cards/card_xuezhang.png"},
	"baiguyin": {"title": "白骨引", "color": Color("c0d5dc"), "icon": "res://assets/game/cards/card_baiguyin.png"},
	"shoulian": {"title": "收殓", "color": Color("bfae95"), "icon": "res://assets/game/cards/card_shoulian.png"},
	"shuangdeng": {"title": "双灯照", "color": Color("e6a850"), "icon": "res://assets/game/cards/card_shuangdeng.png"},
	"yuangui": {"title": "怨归", "color": Color("c43232"), "icon": "res://assets/game/cards/card_yuangui.png"},
	"tianping": {"title": "极·天平倒悬", "color": Color("e54238"), "icon": "res://assets/game/cards/card_tianping.png"},
	"difan": {"title": "低幡", "color": Color("5898aa"), "icon": "res://assets/game/cards/card_difan.png"},
	"fuhunsuo": {"title": "缚魂索", "color": Color("48a8b8"), "icon": "res://assets/game/cards/card_fuhunsuo.png"},
	"jiedao": {"title": "借刀", "color": Color("52b8be"), "icon": "res://assets/game/cards/card_jiedao.png"},
	"tianyou": {"title": "添油", "color": Color("e8a238"), "icon": "res://assets/game/cards/card_tianyou.png"},
	"wenlu": {"title": "问路", "color": Color("82b888"), "icon": "res://assets/game/cards/card_wenlu.png"},
	"zhima": {"title": "纸马", "color": Color("92b884"), "icon": "res://assets/game/cards/card_zhima.png"},
	"changming": {"title": "长明", "color": Color("e8b04a"), "icon": "res://assets/game/cards/card_changming.png"},
	"jieshou": {"title": "借寿", "color": Color("d85248"), "icon": "res://assets/game/cards/card_jieshou.png"},
	"yandeng": {"title": "延灯", "color": Color("8ac0b8"), "icon": "res://assets/game/cards/card_yandeng.png"},
	"jiezou": {"title": "劫奏", "color": Color("6aa8c8"), "icon": "res://assets/game/cards/card_jiezou.png"},
	"huangdeng": {"title": "晃灯", "color": Color("c8c08a"), "icon": "res://assets/game/cards/card_huangdeng.png"},
	"chageng": {"title": "查更", "color": Color("9ec0a8"), "icon": "res://assets/game/cards/card_chageng.png"},
}

const CARD_FRAMES := {
	"斩": "res://assets/game/ui/card_frame_zhan.png",
	"御": "res://assets/game/ui/card_frame_yu.png",
	"佑": "res://assets/game/ui/card_frame_you.png",
}

const PARALLAX_LAYERS := [
	{"texture": "res://assets/game/environments/old_street/bg_layer0_sky_moon.png", "z": -30, "drift": 0.3},
	{"texture": "res://assets/game/environments/old_street/bg_layer1_distant_eaves.png", "z": -25, "drift": 0.6},
	{"texture": "res://assets/game/environments/old_street/bg_layer2_mid_buildings.png", "z": -20, "drift": 1.0},
	{"texture": "res://assets/game/environments/old_street/bg_layer3_ground_puddles.png", "z": -15, "drift": 1.8},
	{"texture": "res://assets/game/environments/old_street/bg_layer4_foreground_fog.png", "z": -8, "drift": 2.6},
]

const CHARACTER_SLICES := {
	"keeper_body": "res://assets/game/characters_sliced/keeper_body_clean.png",
	"keeper_lantern": "res://assets/game/characters_sliced/keeper_lantern_prop.png",
}

const MOVE_PRESENTATION := {
	"red": {"color": Color("bd3d45")},
	"blue": {"color": Color("43a9b2")},
	"green": {"color": Color("6d9663")},
	"quick": {"color": Color("d0a45c")},
	"gamble_dice": {"color": Color("e0b45c")},
	"gamble_flip": {"color": Color("bd3d45")},
	"sisters_twin_whip": {"color": Color("43a9b2")},
	"sisters_drag": {"color": Color("3a8a8e")},
	"paper_storm": {"color": Color("d8ceb0")},
	"corpse_gong": {"color": Color("8f7a3f")},
	"boss_ceremony": {"color": Color("f2d487")},
	"boss_flame_domain": {"color": Color("e55238")},
	"paper_funeral_kite": {"color": Color("d8c8a0")},
	"corpse_shroud_slam": {"color": Color("9a8a4a")},
	"razor_waltz": {"color": Color("d0989a")},
	"shear_bind": {"color": Color("b88a9a")},
	"imp_flame_leap": {"color": Color("e0884a")},
	"keeper_ash_rain": {"color": Color("c8b898")},
	"keeper_wick_snuff": {"color": Color("c83a2a")},
	"keeper_finale": {"color": Color("e86a3a")},
}

const MOVE_ANIMATIONS := {
	"red": {
		"type": "delayed_strike",
		"raise_end": 0.36, "hold_end": 0.82,
		"weapon_rot": [-0.45, -2.25, 1.40],
		"body_x": [1006.0, 1020.0, 580.0],
		"body_rot": [0.0, 0.04, -0.16]
	},
	"blue": {
		"type": "combo_strikes",
		"raise_end": 0.58,
		"weapon_rot": [-0.45, -1.75, 1.25],
		"body_x": [1006.0, 1015.0, 560.0],
		"body_rot": [0.0, 0.02, -0.12]
	},
	"quick": {
		"type": "combo_strikes",
		"raise_end": 0.65,
		"weapon_rot": [-0.45, -1.60, 1.20],
		"body_x": [1006.0, 1010.0, 580.0],
		"body_rot": [0.0, 0.02, -0.10]
	},
	"green": {
		"type": "grab_reach",
		"cancel_point": 0.60,
		"weapon_rot": [-0.45, -2.02, -0.20],
		"body_x": [1006.0, 760.0],
		"hand_reach": Vector2(-540, -18)
	},
	"gamble_dice": {
		"type": "combo_strikes",
		"raise_end": 0.50,
		"weapon_rot": [-0.45, -1.50, 1.10],
		"body_x": [1006.0, 1012.0, 640.0],
		"body_rot": [0.0, 0.04, -0.08]
	},
	"gamble_flip": {
		"type": "grab_reach",
		"cancel_point": 0.60,
		"weapon_rot": [-0.45, -2.20, 0.40],
		"body_x": [1006.0, 720.0],
		"hand_reach": Vector2(-500, -20)
	},
	"sisters_twin_whip": {
		"type": "combo_strikes",
		"raise_end": 0.60,
		"weapon_rot": [-0.45, -1.80, 1.30],
		"body_x": [1006.0, 1015.0, 570.0],
		"body_rot": [0.0, 0.03, -0.10]
	},
	"sisters_drag": {
		"type": "grab_reach",
		"cancel_point": 0.55,
		"weapon_rot": [-0.45, -1.80, -0.10],
		"body_x": [1006.0, 750.0],
		"hand_reach": Vector2(-550, -10)
	},
	"paper_storm": {
		"type": "combo_strikes",
		"raise_end": 0.50,
		"weapon_rot": [-0.45, -1.40, 1.00],
		"body_x": [1006.0, 1008.0, 600.0],
		"body_rot": [0.0, 0.02, -0.06]
	},
	"corpse_gong": {
		"type": "combo_strikes",
		"raise_end": 0.55,
		"weapon_rot": [-0.45, -1.60, 1.35],
		"body_x": [1006.0, 1018.0, 580.0],
		"body_rot": [0.0, 0.02, -0.14]
	},
	"boss_ceremony": {
		"type": "combo_strikes",
		"raise_end": 0.60,
		"weapon_rot": [-0.45, -2.10, 1.45],
		"body_x": [1006.0, 1025.0, 550.0],
		"body_rot": [0.0, 0.04, -0.16]
	},
	"boss_flame_domain": {
		"type": "grab_reach",
		"cancel_point": 0.60,
		"weapon_rot": [-0.45, -2.40, 0.0],
		"body_x": [1006.0, 700.0],
		"hand_reach": Vector2(-560, -30)
	},
	"paper_funeral_kite": {
		"type": "delayed_strike",
		"raise_end": 0.34, "hold_end": 0.68,
		"weapon_rot": [-0.45, -2.10, 1.30],
		"body_x": [1006.0, 1015.0, 590.0],
		"body_rot": [0.0, 0.03, -0.12]
	},
	"corpse_shroud_slam": {
		"type": "delayed_strike",
		"raise_end": 0.40, "hold_end": 0.76,
		"weapon_rot": [-0.45, -2.30, 1.45],
		"body_x": [1006.0, 1022.0, 570.0],
		"body_rot": [0.0, 0.05, -0.15]
	},
	"razor_waltz": {
		"type": "combo_strikes",
		"raise_end": 0.48,
		"weapon_rot": [-0.45, -1.55, 1.15],
		"body_x": [1006.0, 1009.0, 610.0],
		"body_rot": [0.0, 0.02, -0.07]
	},
	"shear_bind": {
		"type": "delayed_strike",
		"raise_end": 0.38, "hold_end": 0.72,
		"weapon_rot": [-0.45, -2.05, 1.25],
		"body_x": [1006.0, 1014.0, 600.0],
		"body_rot": [0.0, 0.03, -0.11]
	},
	"imp_flame_leap": {
		"type": "delayed_strike",
		"raise_end": 0.32, "hold_end": 0.60,
		"weapon_rot": [-0.45, -1.95, 1.20],
		"body_x": [1006.0, 1012.0, 575.0],
		"body_rot": [0.0, 0.03, -0.10]
	},
	"keeper_ash_rain": {
		"type": "combo_strikes",
		"raise_end": 0.42,
		"weapon_rot": [-0.45, -1.50, 1.05],
		"body_x": [1006.0, 1008.0, 620.0],
		"body_rot": [0.0, 0.02, -0.06]
	},
	"keeper_wick_snuff": {
		"type": "grab_reach",
		"cancel_point": 0.62,
		"weapon_rot": [-0.45, -2.45, 0.05],
		"body_x": [1006.0, 690.0],
		"hand_reach": Vector2(-570, -26)
	},
	"keeper_finale": {
		"type": "combo_strikes",
		"raise_end": 0.55,
		"weapon_rot": [-0.45, -2.15, 1.40],
		"body_x": [1006.0, 1020.0, 560.0],
		"body_rot": [0.0, 0.04, -0.15]
	}
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
