# Noita Entity Lib

一个简化Noita实体、组件操作的 Lua 封装库

## 特性

- **面向对象**：创建代理，简化读写操作
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
- **参数**：`eid`(number) - 实体ID
- **返回**: `Entity` 代理对象
#### `entity:get_comp(type_name,include_disabled)`
- **参数**
	- `type_name`(string) - 组件文件名，如`"DamageModelComponent"`
	- `include_disabled`(boolean，可选) - 是否包括被禁用的组件，默认`false`
- **返回**: 查找到的第一个组件的代理表，若查询不到返回nil
#### `entity:get_comps(type_name,include_disabled)`
- **参数**：同上
- **返回**：数组(可能为空表)

#### `entity:damagemodel_comp()`等快捷方法
等价于`Entity:get_comp("DamageModelComponent)`。
已提供：`damgemodel_comp`、`item_comp`、`ability_comp`、`lifetime_comp`、`item_action_comp`
#### `entity:kill()`
杀死实体，等价于`EntityKill(self.id)`

---
### Item类(继承自Entity)
#### `Item:new(eid)`
创建物品代理
#### `item:getUiInfo()`
获取物品的UI信息
- **返回**：表，包含`ui_name`、`ui_desciption`、`ui_sprite`（部分物品可能为nil)

#### `item:setUiInfo(info)`
修改物品的UI信息
- **参数**：`info`(table) - 包含`ui_name`、`ui_desciption`、`ui_sprite`三者的任意组合

---

### Wand类(继承自Item)
#### `wand:add_spell(action_id,dont_add_when_full)`
添加法术到法杖中
- **参数**：
	- `action_id`(string) - 法术ID，如`BOMB`
	- `dont_add_when_full`(boolean) - 启用时候当法杖没有位置时不会添加法术

--- 
### Component类
通过`get_comp`返回的对象支持
- **读写组件**：`comp.hp=100`、`local hp = comp.hp`
- **方法**：
	- `comp:remove()`:删除组件
	- `comp:get_id()`:返回组件ID
	- `comp:get_object(object_name)`：返回该组件的object对象代理，同样可以用属性进行读写
	- `comp:get_value(key_name)`：当该字段有多个返回值时，用其获取
