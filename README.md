# Noita Entity Lib

一个简化Noita实体、组件操作的 Lua 封装库

## 特性

- 面向对象：创建代理，简化读写操作
- 属性风格：使用`comp.hp=100`直接读写组件的字段
- 自动判空：组件不存在时自动返回nil

## 安装
1. 将`entity_lib.lua`放到你的Mod文件夹，例如`mods/mod_name/lib/`
2. 在需要的脚本中导入
```lua
local Lib = dofile_once("mods/mod_name/lib/entity_lib.lua")
```

## 快速开始
```lua
--获取玩家实体
local player = Lib.Entity:new(EntityGetWithTag("player_unit"))
--修改血量
local dmg = player:damagemodel_comp()
if dmg then
	dmg.hp = dmg.hp + 2
end
--清除实体
player:kill()
```

## API参考
###  Entity类
#### `Entity:new(eid)`
创建代理对象
- 参数：`eid`(number) - 实体ID
- 返回: `Entity` 代理对象
#### `entity:get_comp(type_name,include_disabled)`
- 参数
	- `type_name`(string) - 组件文件名，如`"DamageModelComponent"`
	- `include_disabled`(boolean，可选) - 是否包括被禁用的组件，默认`false`
- 返回: 查找到的第一个组件的代理表，若查询不到返回nil
#### `entity:get_comps(type_name,include_disabled)`
- 参数：同上
- 返回：数组(可能为空表)

#### `entity:damagemodel_comp()`等快捷方法
等价于`Entity:get_comp("DamageModelComponent)`。
已提供：
- `damgemodel_comp`
- `item_comp`
- `ability_comp`
- `lifetime_comp`
- `item_action_comp`
- `controls_comp`
- `genome_data_comp`
- `inventor2_comp`
#### `entity:kill()`
杀死实体，等价于`EntityKill(self.id)`

--- 
### Animals类(继承自Entity)
#### `Animals:new(eid)`
获取生物代理
#### `animals:get_hp()`
获取生物血量
- 返回：`hp`(number) - 该血量是真实血量的 1/25
#### `animals:set(hp)`
设置生物血量
- 参数：`hp`(number) - 同上
#### `animals:get_max_hp()`
获取生物的最大血量
- 返回：同上
#### `animals:set_max_hp()`
设置生物的最大血量
同上
#### `animals:get_damagemuls()`
获取生物的承伤倍率
- 返回：(table) - key与value均为string，需要类型转化
#### `animals:set_damage_muls(damage_muls)`
设置生物的承伤倍率
- 参数：`damage_muls`(table) key为string，value为number

#### `animals:get_herd_id()`
获取生物的阵营id，失败返回nil
- 返回：`herd_id`(number|nil)，失败返回nil
#### `animals:set_herd_id(herd_id)`
设置生物的阵营id，
- 参数：同上
#### `animals:add_game_effect(effect_name,frames)`
给生物添加效果，如神佑等
- 参数：
	- `effect_name`(string) - 效果名字，大写
	- `frames`(number)  - 持续时间，-1表示永久
---
### Player类
#### `Player:new(eid)`
获取玩家代理表
#### `player:get_mouse_pos()`
获取玩家鼠标位置
- 返回：`x,y`(number)  - 为世界坐标系
#### `player:get_mouse_pos_in_screen(gui)`
获取玩家鼠标位置(屏幕上的坐标)
- 参数；`gui`(number)  - 通过GuiCreate()获取的gui
- 返回：`x,y`(number) - 为屏幕坐标系
#### `player:pick_up_item(item)`
捡起物品
- 参数：`item`(table|number)，支持代理表和实体ID，将指向的物品加入到玩家背包里
#### `player:get_wand_held()`
获取玩家手持的魔杖
- 返回：`wand`(table) -魔杖实体，Wand类对象


---
### Item类(继承自Entity)
#### `Item:new(eid)`
创建物品代理
#### `item:getUiInfo()`
获取物品的UI信息
- 返回：表，包含`ui_name`、`ui_desciption`、`ui_sprite`（部分物品可能为nil)

#### `item:setUiInfo(info)`
修改物品的UI信息
- 参数：`info`(table) - 包含`ui_name`、`ui_desciption`、`ui_sprite`三者的任意组合

---

### Wand类(继承自Item)
#### `wand:add_spell(action_id,dont_add_when_full)`
添加法术到法杖中
- 参数：
	- `action_id`(string) - 法术ID，如`BOMB`
	- `dont_add_when_full`(boolean) - 启用时候当法杖没有位置时不会添加法术

--- 
### Component类
通过`get_comp`返回的对象支持
- 读写组件：`comp.hp=100`、`local hp = comp.hp`
- 方法：
	- `comp:remove()`:删除组件
	- `comp:get_id()`:返回组件ID
	- `comp:get_object(object_name)`：返回该组件的object对象代理，同样可以用属性进行读写
	- `comp:get_value(key_name)`：当该字段有多个返回值时，用其获取

---
## 计划加入的类：
- Perk：天赋类？
- 未完待续

## 注意事项
- 若实体被销毁，大部分方法会返回nil，组件读写等可能会报错

## 许可证

MIT[LICENSE](LICENSE)