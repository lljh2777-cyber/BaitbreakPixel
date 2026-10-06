window.M01_LAYER_PLAN = {
  "schema": "watergen-art-layer-plan-v1",
  "map": "M01/B",
  "status": "planning_only",
  "current_interactions": "none",
  "annotation_geometry_is_authoritative": false,
  "image": "../round3/evidence/FAUNA-world.png",
  "size": [
    1280,
    480
  ],
  "regions": [
    {
      "id": "B01",
      "group": "背景",
      "name": "水色与光照",
      "pin": [
        620,
        65
      ],
      "rect": [
        360,
        0,
        480,
        180
      ],
      "description": "纯背景，不响应钩位，不覆盖鱼线与 UI。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "B02",
      "group": "背景",
      "name": "远坡与大片岩棚",
      "pin": [
        1110,
        248
      ],
      "rect": [
        960,
        154,
        320,
        150
      ],
      "description": "右侧大岩棚属于视觉岸坡，不整块转换为真实碰撞墙；服从最新地图可游区。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "B03",
      "group": "背景",
      "name": "顶部浮叶与垂根",
      "pin": [
        1090,
        49
      ],
      "rect": [
        995,
        0,
        165,
        113
      ],
      "description": "纯装饰，不缠线、不挡网；根须与鱼线保持视觉差异。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "D01",
      "group": "中景",
      "name": "沙泥沟底与碎石",
      "pin": [
        620,
        450
      ],
      "rect": [
        300,
        410,
        410,
        62
      ],
      "description": "不改变真实池底、可游区、减速区或抄网活动范围。",
      "feature_id": null,
      "color": "#a5dca6"
    },
    {
      "id": "D02",
      "group": "中景",
      "name": "坡脚低草与藻类",
      "pin": [
        1002,
        401
      ],
      "rect": [
        953,
        353,
        112,
        87
      ],
      "description": "按公开视觉表面生长，不新增 grass target。",
      "feature_id": null,
      "color": "#a5dca6"
    },
    {
      "id": "C01",
      "group": "待绑定",
      "name": "局部石块外观候选",
      "pin": [
        879,
        434
      ],
      "rect": [
        840,
        417,
        79,
        37
      ],
      "description": "只在匹配既有 stone 时作为皮肤；框内石块尚无目标 ID，大片岩棚不因此成为碰撞体。",
      "feature_id": null,
      "color": "#ffd17b"
    },
    {
      "id": "C02",
      "group": "待绑定",
      "name": "指定高草外观候选",
      "pin": [
        1232,
        118
      ],
      "rect": [
        1180,
        40,
        100,
        117
      ],
      "description": "仅匹配既有 grass 后沿用原能力；没有匹配的高草仍是装饰，不新增减速区。",
      "feature_id": null,
      "color": "#ffd17b"
    },
    {
      "id": "F01",
      "group": "前景",
      "name": "底角深色土石",
      "pin": [
        75,
        443
      ],
      "rect": [
        0,
        407,
        215,
        73
      ],
      "description": "近景框景，无交互。未来需裁让真实巢穴/出生区和重要识别对象。",
      "feature_id": null,
      "color": "#d8b2ff"
    },
    {
      "id": "E01",
      "group": "动物",
      "name": "沟底与坡脚小虾",
      "pin": [
        660,
        422
      ],
      "rect": [
        630,
        414,
        44,
        25
      ],
      "description": "三只小虾本地视觉短移，不可吃、不可钓，不进入 NPC 或快照。",
      "feature_id": null,
      "color": "#ffaaa0"
    },
    {
      "id": "E02",
      "group": "动物",
      "name": "岩面蜗牛与附生物",
      "pin": [
        1109,
        166
      ],
      "rect": [
        1095,
        156,
        32,
        25
      ],
      "description": "蜗牛和苔藻将来跟随公开宿主变换和淡化，自身没有目标能力。",
      "feature_id": null,
      "color": "#ffaaa0"
    },
    {
      "id": "E03",
      "group": "动物",
      "name": "两组远景鱼",
      "pin": [
        212,
        207
      ],
      "rect": [
        160,
        187,
        107,
        52
      ],
      "description": "此框标左侧代表鱼群；另一组在右上。小尺寸低对比，不抢食、不读取暗钩。",
      "feature_id": null,
      "color": "#ffaaa0"
    }
  ]
};
