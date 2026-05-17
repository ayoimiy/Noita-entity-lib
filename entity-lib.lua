


-------------------------------------------------------------------------------------------
--[[
    日志部分
]]
local Logger = {
}
function Logger:write(msg)
    -- GamePrint(msg)
end
function Logger:error(msg)
    self:write("[Error]" .. msg)
end
function Logger:info(msg)
    self:write("[Info]" .. msg)
end
function Logger:debug(msg)
    self:write("[Debug]" .. msg)
end
function Logger:warn(msg)
    self:write("[Warn]" .. msg)
end

local logger = {}
function logger.setLogger(_Logger)
    setmetatable(logger,{
        __index = _Logger
    })
end
logger.setLogger(Logger)

--[[
    通用函数部分
]]

local function add_capability(self,...)
    for _,cap in ipairs({...}) do 
        --设置属性获取器
        for name,fn in pairs(cap.getter) do 
            self.__getter[name] = fn
        end
        --设置属性设置器
        for name,fn in pairs(cap.setter) do 
            self.__setter[name] = fn
        end
    end
end
local function get_id(entity)
    if type(entity) == 'number' then
        return entity
    elseif type(entity) == 'table' then
        return entity:get_id()
    end
end
---@param _class_name string  类名
---@param base? table
local function class(_class_name,base,...)
    --类的元表方法
    local _class = setmetatable({},{
        __index = base or nil ,   --父类方法和属性只读
        --实现构造函数，创建实例直接用call即可，并且子类只需要写字段的初始化，而无需new 
        __call = function (c,...)
            local obj = setmetatable({},c)
            if obj.init then obj:init(...) end
            return obj
        end
    })    
    --类属性
    _class.__getter = {}
    _class.__setter  = {}
    --类方法，用以控制实例对象
    _class.__index = function (self,key)
        --先查找类自己的字段(self是实例)
        local field = _class[key]
        if field ~=nil  then
            return field
        end
        --查找类的getter访问属性
        local getter = _class.__getter[key]
        if getter~=nil  then
           return getter(self)
        end
        --没有返回nil
        return nil 
    end
    _class.__newindex = function (self,key,value)
        --只查找类的setter访问器
        local setter = _class.__setter[key]
        if setter then
            setter(self,value)
            return 
        end
        error(_class_name ..  "no such field:"..tostring(key) .. "")
    end
    _class._class_name = _class_name

    --继承父类的属性
    if base then
        for name,fn in pairs(base.__getter) do
            _class.__getter[name] = fn 
        end
        for name,fn in pairs(base.__setter) do 
            _class.__setter[name] = fn 
        end 
    end
    
    --自己的属性
    add_capability(_class,...)
    return _class
end



-------------------------------------------------------------------------------------------
--[[
    内部私有类，不暴露构造函数
]]

---@class Component 组件代表表类
---@field entity_id number 组件所在实体的ID
---@field id  number 组件ID
---@method remove() void 移除组件
---@method get_id() number 获取组件ID
---@method get_entity_id number 获取实体ID
---@method get_value(key_name:string) string  获取组件值
---@method get_value2(variable_name:string) any 获取组件值，但是更快(7.5x
---@method set_value(variable_name:string,value:string) void 设置组件值
---@method set_value2(variable_name:string,value:any) void 设置组件值
---@method get_object(object_name:string) Component 获取组件对象
---@method get_object_value(object_name:string,variable_name:string) string 获取结构体字段值
local Component = class("Component")

---@class ComponentFactory
---@method new(entity_id:number,comp_id:number) Component
local ComponentFactory = {
}

-- 组件工厂
--[[

]]
--- 操作普通属性
---@param entity_id number 
---@param comp_id number 
---@return table 代理表proxy
function ComponentFactory:new(entity_id,comp_id)
    local comp = Component(entity_id,comp_id)
    local proxy = {}
    setmetatable(proxy,{
        __index = function (_,variable_name)
            if comp[variable_name] ~= nil  then
               return comp[variable_name] 
            else
                return comp:get_value2(variable_name)
            end           
        end,
        __newindex = function (_,variable_name,value)
            comp:set_value2(variable_name,value)
        end
    })
    return proxy
end

--- 代理object对象类型
---@param object_name string
---@return table 代理表proxy
function Component:get_object(object_name)
    local M = {}
    M.__index = function (_,variable_name)
        
        return self:get_object_value2(object_name,variable_name)
    end
    M.__newindex = function (_,variable_name,...)
        return self:set_object_value2(object_name,variable_name,...)
    end
    return setmetatable(M,M)
end

function Component:init(entity_id,comp_id)
    rawset(self,"entity_id",entity_id)
    rawset(self,"id",comp_id)
end

---@return number 组件ID
function Component:get_id()
    return self.id 
end
---@return number 实体ID
function Component:get_entity_id()
    return self.entity_id
end
---移除组件，不处理组件不存在的问题
function Component:remove()
    EntityRemoveComponent(self.entity_id,self.id)
end
---@param variable_name string 
---@return string|nil 
function Component:get_value(variable_name)
    return ComponentGetValue(self.id,variable_name)
end
--- 更快(7.5x)
---@param variable_name string
---@return ...  一个或多个值 
function Component:get_value2(variable_name)
    return ComponentGetValue2(self.id,variable_name)
end
---@param variable_name string 
---@param value string  全部都是string 
function Component:set_value(variable_name,value)
    ComponentSetValue(self.id,variable_name,value)
end
--- 更快(20x)
---@param variable_name string 
---@param ... any  需要具体字段的类型具体分析
function Component:set_value2(variable_name,...)
    ComponentSetValue2(self.id,variable_name,...)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@return string|nil 
function Component:get_object_value(object_name,variable_name)
    return ComponentObjectGetValue(self.id,object_name,variable_name)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@return ...  一个或多个值 
function Component:get_object_value2(object_name,variable_name)
    return ComponentObjectGetValue2(self.id,object_name,variable_name)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@param value string
function Component:set_object_value(object_name,variable_name,value)
    ComponentObjectSetValue(self.id,object_name,variable_name,value)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@param ... any 
function Component:set_object_value2(object_name,variable_name,...)
    ComponentObjectSetValue2(self.id,object_name,variable_name,...)
end

-------------------------------------------------------------------------------------------
--能力
local Capability = {
}
---@class Capability.damage_model
---@field hp number|nil
---@field max_hp number|nil
---@field damage_muls table|nil
Capability.damage_model ={
    getter ={
        hp = function (self)
            local damagemodel = self:damagemodel_comp(true)
            return damagemodel and  damagemodel.hp
        end,
        max_hp = function (self)
            local damagemodel = self:damagemodel_comp(true)
            return damagemodel and  damagemodel.max_hp
        end,
        damage_muls = function (self)
            local comp = self:damagemodel_comp(true)
            return comp and ComponentObjectGetMembers(comp:get_id(),"damage_multipliers")
        end
    },
    setter = {
        hp = function (self,hp)
            local damagemodel = self:damagemodel_comp(true)
            if not damagemodel then return nil end
            damagemodel.hp = hp 
        end,
        max_hp = function (self,max_hp)
            local damagemodel = self:damagemodel_comp(true)
            if not damagemodel then 
                return nil 
            end
            damagemodel.max_hp = max_hp
        end,
        damage_muls = function (self,damage_muls)
            local comp = self:damagemodel_comp(true)
            if not comp then return nil end
            local damage_multipliers = comp:get_object("damage_multipliers")
            if not damage_multipliers  then return nil end 
            for type,mul in pairs(damage_muls) do
                damage_multipliers[type] =mul
            end
        end
    }
}
---@class Capability.tags
---@field tags string[]
Capability.tags ={
    getter = {
        tags = function (self)
            local tags = {}
            local s_tags =EntityGetTags(self.id)
            if not s_tags then return nil end
            for  tag in string.gmatch(s_tags,"([^,]+)") do
                table.insert(tags,tag)
            end
            return tags
        end
    },
    setter = {}
}
---@class Capability.herd_id
---@field herd_id number|nil
Capability.herd_id={
    getter = {
        herd_id = function (self)
            local comp = self:genome_data_comp(true)
            return comp and  comp.herd_id
        end
    },
    setter= {
        herd_id = function (self,herd_id)
            local comp = self:genome_data_comp(true)
            if not comp then
                error("查找herd_id时无法查找到组件")
                return nil
            end
            comp.herd_id = herd_id
        end
    }
}
---@class Capability.wand_ability
---@field deck_capacity number|nil  法杖容量
---@field actions_per_round number|nil 施法数
---@field fire_rate_wait number|nil 延迟(按帧)
---@field reload_time number|nil 充能时间(按帧)
---@field spread_degrees number|nil 散射角度
---@field speed_mul number|nil 速度倍率
---@field shuffle_deck_when_empty boolean|nil ?
---@field mana_max number|nil 最大法力
---@field mana_charge_speed number|nil 回蓝速度
---@field click_to_use boolean|nil 是否能够点击使用

local function _gun_config(self)
    local comp = self:ability_comp(true)
    return comp and  comp:get_object("gun_config")
end

local function _gunaction_config(self)
    local comp = self:ability_comp(true)
    return comp and  comp:get_object("gunaction_config")
end
Capability.wand_ability = { 
    getter = {
        deck_capacity = function (self)
            local obj = _gun_config(self)
            return obj and obj.deck_capacity
        end,
        actions_per_round = function (self)
            local obj = _gun_config(self)
            return obj and obj.actions_per_round
        end,
        fire_rate_wait = function (self)        
            local obj = _gunaction_config(self)
            return obj and obj.fire_rate_wait
        end,
        reload_time = function (self)
            local obj = _gun_config(self)
            return obj and obj.reload_time
        end,
        spread_degrees = function (self)
            local obj = _gunaction_config(self)
            return obj and obj.spread_degrees
        end,
        speed_mul = function (self)
            local obj = _gunaction_config(self)
            return obj and obj.speed_multiplier
        end,
        shuffle_deck_when_empty = function (self)
            local obj = _gun_config(self)
            return obj and obj.shuffle_deck_when_empty
        end,
        mana_max = function (self)
            local obj = self:ability_comp(true)
            return obj and obj.mana_max
        end,
        mana_charge_speed = function (self)
            local obj = self:ability_comp(true)
            return obj and obj.mana_charge_speed
        end,
        click_to_use = function (self)
            local obj = self:ability_comp(true)
            return obj and obj.click_to_use
        end
    },
    setter  = {
        deck_capacity = function (self, value)
            local obj = _gun_config(self)
            if not obj then
                error("wand_ability: 无法获取 gun_config 对象")
            end
            obj.deck_capacity = value
        end,
        actions_per_round = function (self, value)
            local obj = _gun_config(self)
            if not obj then
                error("wand_ability: 无法获取 gun_config 对象")
            end
            obj.actions_per_round = value
        end,
        fire_rate_wait = function (self, value)
            local obj = _gunaction_config(self)
            if not obj then
                error("wand_ability: 无法获取 gunaction_config 对象")
            end
            obj.fire_rate_wait = value
        end,
        reload_time = function (self, value)
            local obj = _gun_config(self)
            if not obj then
                error("wand_ability: 无法获取 gun_config 对象")
            end
            obj.reload_time = value
        end,
        spread_degrees = function (self, value)
            local obj = _gunaction_config(self)
            if not obj then
                error("wand_ability: 无法获取 gunaction_config 对象")
            end
            obj.spread_degrees = value
        end,
        speed_mul = function (self, value)
            local obj = _gunaction_config(self)
            if not obj then
                error("wand_ability: 无法获取 gunaction_config 对象")
            end
            obj.speed_multiplier = value
        end,
        shuffle_deck_when_empty = function (self, value)
            local obj = _gun_config(self)
            if not obj then
                error("wand_ability: 无法获取 gun_config 对象")
            end
            obj.shuffle_deck_when_empty = value
        end,
        mana_max = function (self, value)
            local obj = self:ability_comp(true)
            if not obj then
                error("wand_ability: 无法获取 ability_component")
            end
            obj.mana_max = value
        end,
        mana_charge_speed = function (self, value)
            local obj = self:ability_comp(true)
            if not obj then
                error("wand_ability: 无法获取 ability_component")
            end
            obj.mana_charge_speed = value
        end,
        click_to_use = function (self, value)
            local obj = self:ability_comp(true)
            if not obj then
                error("wand_ability: 无法获取 ability_component")
            end
            obj.click_to_use = value
        end
    }
}

--[[
    下次完成
]]
---@class Capability.item
---@field item_name string|nil 
---@field always_use_item_name_in_ui boolean|nil 
---@field inventory_slot table{x:number,y:number} 布局坐标
---@field ui_name string|nil
---@field ui_description string|nil
---@field ui_sprite string|nil
Capability.item ={
    getter = {
        item_name = function (self)
            local item  = self:item_comp(true)
            return item and  item.item_name
        end,
        always_use_item_name_in_ui = function (self)
            local item  = self:item_comp(true)
            return item and  item.always_use_item_name_in_ui
        end,      
        inventory_slot = function (self)
            local item_comp = self:item_comp(true)
            if not item_comp then return nil end
            local x,y = item_comp:get_value2("inventory_slot")
            local pos = {x=x,y=y}
            return pos
        end,
        ui_name = function (self)
            local comp = self:ability_comp(true)
            return comp and comp.ui_name
        end,
        ui_description = function (self)
            local comp = self:item_comp(true)
            return comp and comp.ui_description
        end,
        ui_sprite = function (self)
            local comp = self:item_comp(true)
            return comp and comp.ui_sprite
        end
    },
    setter = {
        item_name = function (self,value)
            local item = self:item_comp(true)
            if not item then
                error("item: 获取 item_comp 对象失败")
            end
            item.item_name = value
        end,
        always_use_item_name_in_ui = function (self,value)
            local item = self:item_comp(true)
            if not item then
                error("item: 获取 item_comp 对象失败")
            end
            item.always_use_item_name_in_ui = value
        end,
        inventory_slot = function (self,pos)
            local item_comp = self:item_comp(true)
            if not item_comp then
                error("item: 获取 item_comp 对象失败")
            end
            item_comp:set_value2("inventory_slot",pos.x,pos.y)
        end,
        ui_name = function (self,name)
            local comp = self:ability_comp(true)
            if not comp then
                error("item: 获取 ability_component 对象失败")
            end
            comp.ui_name = name
        end,
        ui_description = function (self,description)
            local comp = self:item_comp(true)
            if not comp then
                error("item: 获取 ability_component 对象失败")
            end
            comp.ui_description = description
        end,
        ui_sprite = function (self,sprite)
            local comp = self:item_comp(true)
            if not comp then
                error("item: 获取 ability_component 对象失败")
            end
            comp.ui_sprite = sprite
        end
    }
}
---@class Capability.action
Capability.action = {
    getter = {
    },
    setter = {
    }
}

---------------------------------------------------------------------------------------------
--[[
    公开类，对外暴露
]]

-- 实体类
---@class Entity : Capability.tags
---@field id number|nil 实体ID，只读属性
---@field _class_name string 实体类名，只读属性
---@field __getter table 属性获取器
---@field __setter table 属性设置器
---@method get_id() number 获取实体ID
---@method get_name() string 获取实体名称
---@method get_file_name() string 获取实体文件名称
---@method kill() void 杀死实体
---@method is_living() boolean 实体是否存活
---@method get_pos() number,number 获取实体坐标
---@method set_pos(x:number,y:number) void 设置实体坐标
---@method has_tag(tag:string) boolean 实体是否有标签
---@method add_tag(tag:string) void 添加实体标签
---@method remove_tag(tag:string) void 移除实体标签
---@method add_child(child:Entity|number) void 添加子实体
---@method remove_child(child:Entity|number) void 移除子实体
---@method add_comp(type_name:string,table_of_comp_values:table,tags:string,enabled:boolean) number 添加组件
---@method add_variable_comp(table_of_comp_values:table,tags:string,enabled:boolean) number 添加变量存储组件
---@method add_lua_comp(table_of_comp_values:table,tags:string,enabled:boolean) number 添加Lua组件
---@method get_comp(type_name:string,including_disabled:boolean) Component|nil 获取单个组件
---@method get_comps(type_name:string,including_disabled:boolean) Component[]|nil 获取所有组件
---@method get_comp_object(type_name:string,object_name:string) Component|nil 获取组件对象
---@method item_comp(including_disabled:boolean) Component|nil 获取物品组件
---@method ability_comp(including_disabled:boolean) Component|nil 获取能力组件
---@method item_ation_comp(including_disabled:boolean) Component|nil 获取物品动作组件
---@method damagemodel_comp(including_disabled:boolean) Component|nil 获取伤害模型组件
---@method lifetime_comp(including_disabled:boolean) Component|nil 获取生命周期组件
---@method controls_comp(including_disabled:boolean) Component|nil 获取控制组件
---@method genome_data_comp(including_disabled:boolean) Component|nil 获取基因组数据组件
---@method inventory2_comp(including_disabled:boolean) Component|nil 获取背包组件
local Entity = class("Entity",nil,Capability.tags)
function Entity:init(eid)
    if eid == nil then 
        error("Entity:init: eid is nil")
    end
    rawset(self,"id",eid)
end
-- 动物类
---@class Animals : Entity, Capability.damage_model, Capability.herd_id
---@method is_living() boolean 重写：判断实体是否存活
---@method add_game_effect(effect_name:string,frames:number) Component|nil 添加游戏效果
local Animals = class("Animals",Entity,
    Capability.damage_model,
    Capability.herd_id
)

-- 玩家类
---@class Player:Animals
---@method get_mouse_pos() number,number 获取鼠标世界坐标
---@method get_mouse_pos_in_screen(gui:userdata) number,number 获取鼠标屏幕坐标
---@method pick_up_item(item:Entity|number) void 拾取物品
---@method get_wand_held() Wand 获取手持法杖
local Player = class("Player",Animals)

-- 物品类
---@class Item:Entity
---@method get_ui_info() table 获取物品UI信息
---@method set_ui_info(info:table) void 设置物品UI信息
---@method get_slot() number,number 获取物品容器位置
local Item = class("Item",Entity)

-- 法术类
---@class Action_Card:Item
---@method get_action_id() number|nil 获取法术ID
local Action_Card=class("Action_Card",Item)
-- 法杖类
---@class Wand : Item, Capability.wand_ability
---@method add_action(action_id:string,dont_add_when_full:boolean) void 添加法术
---@method add_action_permanent(action_id:string) void 添加永久法术
---@method get_actions() Action_Card[] 获取法术(按照位置排序好)
local Wand = class("Wand",Item,Capability.wand_ability)
--天赋类
---@class Perk:Entity
local Perk = class("Perk",Entity)

-- 暴露的函数
local M = {
    Entity = Entity,
    Item = Item,
    Animals = Animals,
    Player = Player,
    Wand = Wand,
    Perk = Perk,
    Action_Card = Action_Card,
    Logger = Logger,
}

-- 获取id 
--- @return number 
function Entity:get_id()
    return self.id
end
-- 获取名字
function Entity:get_name()
    local name = EntityGetName(self.id)
    if name == nil then
        logger:warn(tostring(self.id) .. "不存在名字")
        name = ""
    end
    return GameTextGetTranslatedOrNot(name)
end
function Entity:get_file_name()
    return EntityGetFilename(self.id)
end
function Entity:kill()
    if self:is_living() then
        EntityKill(self.id)
        rawset(self,"id",nil)
    end
end
-- 是否存活
function Entity:is_living()
    if self.id == nil then
        logger:warn("实体不存在")
        return false
    end
    -- if EntityGetIsAlive(self.id) then
    --     return false
    -- end
    return true
end
-- 坐标
function Entity:get_pos()
    local x,y = EntityGetTransform(self.id)
    return x,y
end
function Entity:set_pos(x,y)
    EntitySetTransform(self.id,x,y)
end

function Entity:has_tag(tag)
    return EntityHasTag(self.id,tag)
end
function Entity:add_tag(tag)
    return EntityAddTag(self.id,tag)
end
function  Entity:remove_tag(tag)
    return EntityRemoveTag(self.id,tag)
end

-- 子实体
function Entity:add_child(child)
    local child_id = get_id(child)    
    if child_id and child_id~=0 then
        EntityAddChild(self.id,child_id)
    end
end
function Entity:remove_child(child)
    local child_id = get_id(child)
    if child_id and child_id~=0 then
        EntityRemoveFromParent(child_id)
    end
end


---给实体添加组件
---@param type_name string 组件类型名
---@param table_of_comp_values table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_comp(type_name,table_of_comp_values,tags,enabled)
    local t = {}
    for k,v in pairs(table_of_comp_values) do
        t[k] = v
    end
    if tags ~= nil then t.tags = tags end
    if enabled ~= nil then t._enabled = enabled end
    return EntityAddComponent2(self.id,type_name,t)
end
---@param table_of_comp_values table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_variable_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("VariableStorageComponent",table_of_comp_values,tags,enabled)
end
---@param table_of_comp_values table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_lua_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("LuaComponent",table_of_comp_values,tags,enabled)
end


--- 获取组件
---@param type_name string
---@param including_disabled boolean|nil
---@return any|nil   返回任何组件代理表或nil
function Entity:get_comp(type_name,including_disabled)
    if not self:is_living() then return nil end
    local comp 
    if including_disabled == true then
        comp = EntityGetFirstComponentIncludingDisabled(self.id,type_name)
    else
        comp = EntityGetFirstComponent(self.id,type_name)
    end
    if not comp then 
        logger:warn("未查找到组件" .. type_name)
        return nil
    end
    -- 提供一个可以读写的代理表
    return ComponentFactory:new(self.id,comp)
end


---@return  ItemComponent
function Entity:item_comp(including_disabled)
    return self:get_comp("ItemComponent",including_disabled)
end
---@return AbilityComponent
function Entity:ability_comp(including_disabled)
    return self:get_comp("AbilityComponent",including_disabled)
end
---@return ItemActionComponent
function Entity:item_ation_comp(including_disabled)
    return self:get_comp("ItemActionComponent",including_disabled)
end
---@return DamageModelComponent
function Entity:damagemodel_comp(including_disabled)
    return self:get_comp("DamageModelComponent",including_disabled)
end
---@return LifetimeComponent
function Entity:lifetime_comp(including_disabled)
    return self:get_comp("LifetimeComponent",including_disabled)
end
---@return ControlsComponent
function Entity:controls_comp(including_disabled)
    return self:get_comp("ControlsComponent",including_disabled)
end
---@return GenomeDataComponent
function Entity:genome_data_comp(including_disabled)
    return self:get_comp("GenomeDataComponent",including_disabled)
end
---@return Inventory2Component
function Entity:inventory2_comp(including_disabled)
    return self:get_comp("Inventory2Component",including_disabled)
end

--- 获取组件s
---@param type_name string
---@param including_disabled boolean|nil
---@return any|nil
function Entity:get_comps(type_name,including_disabled)
    if not self:is_living() then return nil end
    local comps 
    if including_disabled == true then
        comps = EntityGetComponentIncludingDisabled(self.id,type_name)
    else    
        comps = EntityGetComponent(self.id,type_name)
    end
    if not comps then 
        logger:warn("未查找到组件" .. type_name)
        return nil 
    end
    local proxies = {}
    for _,comp_id in ipairs(comps) do 
        table.insert(proxies,ComponentFactory:new(self.id,comp_id))
    end
    return proxies
end
---@return LuaComponent[] with proxy
function Entity:lua_comps(including_disabled)
    return self:get_comps("LuaComponent",including_disabled)
end
---@return VariableStorageComponent[] with proxy
function Entity:variable_comps(including_disabled)
    return self:get_comps("VariableStorageComponent",including_disabled)
end
function Animals:is_living()
    if self.id == nil then
        logger:warn("实体不存在")
        return false
    elseif not EntityGetIsAlive(self.id) then
        logger:warn("实体未存活")
        return false
    end
    return true
end
--- 设置效果
---@param effect_name string
function Animals:add_game_effect(effect_name,frames)
    local comp_id = GetGameEffectLoadTo(self.id,effect_name,true)
    local comp = ComponentFactory:new(self.id,comp_id) 
    if comp ~= nil then
        comp.frames = frames or -1
    else
        logger:warn("获取" .. effect_name .. "失败")
    end
    return comp
end
---获取鼠标位置
function Player:get_mouse_pos()
    return DEBUG_GetMouseWorld()
end
function Player:get_mouse_pos_in_screen(gui)
    local mx,my = self:get_mouse_pos()
    local _, _, cw, ch = GameGetCameraBounds()
    local cx, cy = GameGetCameraPos()
    cw = cw - 4
    local cx = cx-cw/2
    local cy = cy-ch/2
    local  gw, gh = GuiGetScreenDimensions(gui)
    return (mx-cx)*gw/cw+1.0, (my-cy)*gh/ch -3
end

function Player:pick_up_item(item)
    local item_id = get_id(item)
    if item_id then
        GamePickUpInventoryItem(self.id,item_id)
    end
end
---@return Wand|nil 手持法杖对象
function Player:get_wand_held()
    local children = EntityGetAllChildren(self.id)
	if ( children == nil ) then return nil end
	-- Inventory2Component
	-- mActiveItem
	local inventory2_comp = self:inventory2_comp(true)
	if ( inventory2_comp ~= nil ) then
		local active_item =inventory2_comp.mActiveItem 
		if ( EntityHasTag( active_item, "wand" ) ) then
			return Wand(active_item)
		end
	end
	return nil
end

-- 获取ui
function Item:get_ui_info()
    local info = {}
    local ItemComp = self:item_comp(true)
    if ItemComp then
        -- 在物品栏的ui
        info.ui_description = ItemComp.ui_description
        -- 在物品栏的ui
        info.ui_sprite  = ItemComp.ui_sprite
    end
    local Ability_comp = self:ability_comp(true)
    if Ability_comp then
        info.ui_name =Ability_comp.ui_name
    end
    return info
end
-- 修改ui 
function Item:set_ui_info(info)
    -- GamePrint(tostring(self.id))
    if info.ui_description or info.ui_sprite then
        local ItemComp = self:item_comp(true)
        if ItemComp then
            if info.ui_description then
                ItemComp.ui_description = info.ui_description
            end
            if info.ui_sprite then
                ItemComp.ui_sprite = info.ui_sprite
            end
        end
    --  GamePrint("ItemComp:"..ItemComp)
    end
    if info.ui_name then
        local Ability_comp = self:ability_comp(true)
        if Ability_comp then
            Ability_comp.ui_name = info.ui_name
        end
    end
end
---@return number|nil,number|nil
function Item:get_slot()
    local item_comp = self:item_comp(true)
    if not item_comp then return nil end 
    local x,y = item_comp:get_value2("inventory_slot")
    return x,y
end

-- 获取法术id
---@return string|nil  法术id  
function Action_Card:get_action_id()
    local comp = self:item_ation_comp(true)
    if comp then
        local action_id = comp.action_id
        return action_id
    end
    return nil 
end
---@param action_id string 法术的大写ID
---@param dont_add_when_full boolean 是否在满时不添加
function Wand:add_action(action_id,dont_add_when_full)
    if( action_id == "" ) then return nil end
    if (dont_add_when_full) then
        local ability_comp = self:ability_comp(true) 
        if( ability_comp ~= nil ) then
            local deck_capacity = ability_comp:get_object("gun_config")
            local n = #(EntityGetAllChildren(self.id,"card_action") or {})
            if n+1> deck_capacity.deck_capacity then
                return  nil 
            end
        end
    end
	local action_entity = Action_Card(CreateItemActionEntity( action_id ))
    self:add_child(action_entity)
	if action_entity ~= 0 then
		EntitySetComponentsWithTagEnabled( action_entity:get_id(), "enabled_in_world", false )
	end
end
function Wand:add_action_permanent(action_id)
    if( action_id == "" ) then return 0 end
	local action_entity = Action_Card(CreateItemActionEntity( action_id ))
    self:add_child(action_entity)
	-- we need to add a slot to the ability_comp
    
	local ability_comp = self:ability_comp(true) 
	if( ability_comp ~= nil ) then
        local deck_capacity = ability_comp:get_object("gun_config")
        if deck_capacity then
            deck_capacity.deck_capacity = deck_capacity.deck_capacity +1
        end        
	end
	local item_component = action_entity:item_comp(false) 
	if( item_component ~= nil ) then
        item_component.permanently_attached = true
	end

	if action_entity ~= nil then
		EntitySetComponentsWithTagEnabled( action_entity:get_id(), "enabled_in_world", false )
	end
end
---@return Action_Card[]
function Wand:get_actions()
    local actions = EntityGetAllChildren(self.id)
    local cards = {}
    for i,v in ipairs(actions or {}) do
        table.insert(cards, Action_Card(v)) 
    end
    --将actions排序
    table.sort(cards,function(a,b)
        local a_x = a:get_slot() or -1
        local b_x = b:get_slot() or -1
        return a_x < b_x
    end)
    return cards
end

return M


