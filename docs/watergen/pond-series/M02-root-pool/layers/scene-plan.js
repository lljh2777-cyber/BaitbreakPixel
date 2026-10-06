window.M02_LAYER_PLAN = {
  "schema": "watergen-art-layer-plan-v1",
  "map": "M02/A",
  "status": "planning_only",
  "current_interactions": "none",
  "annotation_geometry_is_authoritative": false,
  "size": [
    1280,
    480
  ],
  "regions": [
    {
      "id": "B01",
      "group": "背景",
      "name": "水色与柔光",
      "pin": [
        740,
        65
      ],
      "rect": [
        450,
        20,
        600,
        170
      ],
      "description": "最远背景，不读取钩信息；光照不能盖住鱼线和 HUD。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "B02",
      "group": "背景",
      "name": "远处树桩与植物剪影",
      "pin": [
        1190,
        250
      ],
      "rect": [
        1050,
        165,
        220,
        170
      ],
      "description": "低对比远景装饰，不形成障碍物。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "B03",
      "group": "背景",
      "name": "顶部浮叶与垂根",
      "pin": [
        265,
        35
      ],
      "rect": [
        200,
        0,
        140,
        120
      ],
      "description": "浮叶和根须无缠线或挡网能力，与鱼线保持视觉差异。",
      "feature_id": null,
      "color": "#81c5ee"
    },
    {
      "id": "D01",
      "group": "中景",
      "name": "老树基部与大根盘",
      "pin": [
        145,
        145
      ],
      "rect": [
        0,
        0,
        430,
        350
      ],
      "description": "整体是视觉岸景，不能把巨大根网转换为碰撞体；接入时服从真实可游空间。",
      "feature_id": null,
      "color": "#a5dca6"
    },
    {
      "id": "D02",
      "group": "中景",
      "name": "根脚泥沙与低草藻丛",
      "pin": [
        415,
        372
      ],
      "rect": [
        320,
        330,
        300,
        100
      ],
      "description": "纯装饰；沿公开表面布置，不生成草 target 或减速区。",
      "feature_id": null,
      "color": "#a5dca6"
    },
    {
      "id": "C01",
      "group": "待绑定",
      "name": "局部木头皮肤候选",
      "pin": [
        310,
        230
      ],
      "rect": [
        210,
        170,
        170,
        110
      ],
      "description": "仅匹配既有 wood 的局部外观；当前没有绑定 ID，整棵树不因此可交互。",
      "feature_id": null,
      "color": "#ffd17b"
    },
    {
      "id": "C02",
      "group": "待绑定",
      "name": "右侧石块皮肤候选",
      "pin": [
        1124,
        385
      ],
      "rect": [
        1080,
        340,
        120,
        75
      ],
      "description": "仅匹配既有 stone 后沿用真实轮廓、能力和淡化；没有匹配则退远或重做。",
      "feature_id": null,
      "color": "#ffd17b"
    },
    {
      "id": "C03",
      "group": "待绑定",
      "name": "右缘高草皮肤候选",
      "pin": [
        1240,
        300
      ],
      "rect": [
        1205,
        210,
        75,
        200
      ],
      "description": "只对既有 grass 适配根点、范围和束草；其他高草仍为装饰。",
      "feature_id": null,
      "color": "#ffd17b"
    },
    {
      "id": "F01",
      "group": "前景",
      "name": "左下深色框景",
      "pin": [
        70,
        438
      ],
      "rect": [
        0,
        380,
        250,
        100
      ],
      "description": "近景不等于可交互；特别裁让真实巢穴、出生点，避免左下遮挡。",
      "feature_id": null,
      "color": "#d8b2ff"
    },
    {
      "id": "E01",
      "group": "动物",
      "name": "泥沙表面小虾",
      "pin": [
        660,
        412
      ],
      "rect": [
        625,
        395,
        70,
        35
      ],
      "description": "代表中央一只；另两只位于根脚及右下。独立视觉短移，不可吃不可钓。",
      "feature_id": null,
      "color": "#ffaaa0"
    },
    {
      "id": "E02",
      "group": "动物",
      "name": "根肩蜗牛与附生物",
      "pin": [
        278,
        169
      ],
      "rect": [
        250,
        145,
        65,
        50
      ],
      "description": "代表根肩蜗牛，另一只在右石。未来跟随公开宿主变换和淡化，自身无能力。",
      "feature_id": null,
      "color": "#ffaaa0"
    },
    {
      "id": "E03",
      "group": "动物",
      "name": "根外与远桩小鱼群",
      "pin": [
        480,
        339
      ],
      "rect": [
        435,
        315,
        100,
        45
      ],
      "description": "代表根外鱼群，另一组在远桩外侧。独立低对比背景动物，不参与 NPC 或快照。",
      "feature_id": null,
      "color": "#ffaaa0"
    }
  ]
};
