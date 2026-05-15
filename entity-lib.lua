


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

local function get_id(entity)
    if type(entity) == 'number' then
        return entity
    elseif type(entity) == 'table' then
        return entity:get_id()
    end
end
---@param _class_name string  类名
---@param base? table
local function class(_class_name,base)
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
    --类方法，用以控制实例对象
    _class.__index = _class
    _class._class_name = _class_name
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
        __newindex = function (_,variable_name,...)
            comp:set_value2(variable_name,...)
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
    self.entity_id = entity_id
    self.id = comp_id
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

--[[
    公开类，对外暴露
]]

-- 实体类
---@class Entity
---@field id number|nil 实体ID
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
---@method get_children() Entity[] 获取子实体
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
local Entity = class("Entity")
function Entity:init(eid)
    self.id = eid
    if eid == nil then 
        error("Entity:init: eid is nil")
    end
end


-- 动物类
---@class Animals:Entity
---@method is_living() boolean 重写：判断实体是否存活
---@method get_hp() number|nil 获取当前生命值
---@method set_hp(hp:number) void 设置当前生命值
---@method get_max_hp() number|nil 获取最大生命值
---@method set_max_hp(max_hp:number) void 设置最大生命值
---@method get_damage_muls() table|nil 获取承伤倍率表
---@method set_damage_muls(damage_muls:table) void 设置承伤倍率
---@method get_herd_id() number|nil 获取阵营ID
---@method set_herd_id(herd_id:number) void 设置阵营ID
---@method add_game_effect(effect_name:string,frames:number) Component|nil 添加游戏效果
local Animals = class("Animals",Entity)

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
---@class Wand:Item
---@method add_action(action_id:string,dont_add_when_full:boolean) void 添加法术
---@method add_action_permanent(action_id:string) void 添加永久法术
---@method get_actions() Action_Card[] 获取法术(按照位置排序好)
---@method get_action(index:number) Action_Card 获取当前法术
local Wand = class("Wand",Item)
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
        self.id = nil 
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

---@return Entity[] 子实体列表
function Entity:get_children()
    local childs = {}
    local children =  EntityGetAllChildren(self.id)
    if not children then
        error("Entity:get_children: children is nil")
    end
    for _,child_id in ipairs(children) do
        local child = Entity(child_id)
        table.insert(childs,child)
    end
    return childs
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
--获取血量
function Animals:get_hp()
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    return damagemodel.hp
end
---@param hp number 
function Animals:set_hp(hp)
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    damagemodel.hp = hp 
end
function Animals:get_max_hp()
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    return damagemodel.max_hp
end
function Animals:set_max_hp(max_hp)
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    damagemodel.max_hp = max_hp
end

-- 承伤倍率
function Animals:get_damage_muls()
    local comp = EntityGetFirstComponentIncludingDisabled(self.id,"DamageModelComponent")
    if not comp then return nil end 
    return ComponentObjectGetMembers(comp,"damage_multipliers")
end
function Animals:set_damage_muls(damage_muls)
    local comp = self:damagemodel_comp()
    if not comp then return nil end
    local damage_multipliers = comp:get_object("damage_multipliers")
    if not damage_multipliers  then return nil end 
    for type,mul in pairs(damage_muls) do
        damage_multipliers[type] =mul
    end
end
-- 获取敌人阵营
function Animals:get_herd_id()
    local comp = self:genome_data_comp(true)
    if not comp then return nil end
    return comp.herd_id
end
function Animals:set_herd_id(herd_id)
    local comp = self:genome_data_comp(true)
    if not comp then return nil end
    comp.herd_id = herd_id
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
---@return number,number
function Item:get_slot()
    local item_comp = self:item_comp(true)
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
---@return Action_Card|nil 
function Wand:get_ation(index)
    ---@type Action_Card[]
    local actions = self:get_actions()
    if not actions then return nil end
    return actions[index]
end
return M


