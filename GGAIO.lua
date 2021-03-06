if not FileExist(COMMON_PATH .. "GGPrediction.lua") then
    print("GG Twitch - Please download GGPrediction.lua !")
    return
end

require('GGPrediction')

local Menu, Utils, Champion

local GG_Target, GG_Orbwalker, GG_Buff, GG_Damage, GG_Spell, GG_Object, GG_Attack

local HITCHANCE_NORMAL = 2
local HITCHANCE_HIGH = 3
local HITCHANCE_IMMOBILE = 4

local DAMAGE_TYPE_PHYSICAL = 0
local DAMAGE_TYPE_MAGICAL = 1
local DAMAGE_TYPE_TRUE = 2

local ORBWALKER_MODE_NONE = -1
local ORBWALKER_MODE_COMBO = 0
local ORBWALKER_MODE_HARASS = 1
local ORBWALKER_MODE_LANECLEAR = 2
local ORBWALKER_MODE_JUNGLECLEAR = 3
local ORBWALKER_MODE_LASTHIT = 4
local ORBWALKER_MODE_FLEE = 5

local TEAM_JUNGLE = 300
local TEAM_ALLY = myHero.team
local TEAM_ENEMY = 300 - myHero.team

local math_huge = math.huge
local math_pi = math.pi
local math_sqrt = assert(math.sqrt)
local math_abs = assert(math.abs)
local math_ceil = assert(math.ceil)
local math_min = assert(math.min)
local math_max = assert(math.max)
local math_pow = assert(math.pow)
local math_atan = assert(math.atan)
local math_acos = assert(math.acos)
local math_random = assert(math.random)
local table_sort = assert(table.sort)
local table_remove = assert(table.remove)
local table_insert = assert(table.insert)

local myHero = myHero
local os = os
local math = math
local Game = Game
local Vector = Vector
local Control = Control
local Draw = Draw
local table = table
local pairs = pairs
local GetTickCount = GetTickCount

Menu = {}
do
    local m = MenuElement({name = 'GG ' .. myHero.charName, id = 'GG' .. myHero.charName, type = _G.MENU})
    Menu.q = m:MenuElement({name = 'Q', id = 'q', type = _G.MENU})
    Menu.w = m:MenuElement({name = 'W', id = 'w', type = _G.MENU})
    Menu.e = m:MenuElement({name = 'E', id = 'e', type = _G.MENU})
    Menu.r = m:MenuElement({name = 'R', id = 'r', type = _G.MENU})
    Menu.d = m:MenuElement({name = 'Drawings', id = 'd', type = _G.MENU})
end

Utils = {}
do
    -- can use spell
    Utils.CanUseSpell = true
    -- last q
    Utils.LastQ = 0
    -- last w
    Utils.LastW = 0
    -- last e
    Utils.LastE = 0
    -- last r
    Utils.LastR = 0
    -- interruptable spells
    Utils.InterruptableSpells =
    {
        ["CaitlynAceintheHole"] = true,
        ["Crowstorm"] = true,
        ["DrainChannel"] = true,
        ["GalioIdolOfDurand"] = true,
        ["ReapTheWhirlwind"] = true,
        ["KarthusFallenOne"] = true,
        ["KatarinaR"] = true,
        ["LucianR"] = true,
        ["AlZaharNetherGrasp"] = true,
        ["Meditate"] = true,
        ["MissFortuneBulletTime"] = true,
        ["AbsoluteZero"] = true,
        ["PantheonRJump"] = true,
        ["PantheonRFall"] = true,
        ["ShenStandUnited"] = true,
        ["Destiny"] = true,
        ["UrgotSwap2"] = true,
        ["VelkozR"] = true,
        ["InfiniteDuress"] = true,
        ["XerathLocusOfPower2"] = true
    }
    -- on spell cast cb
    Utils.OnSpellCastCb = {}
    -- on spell cast
    function Utils:OnSpellCast(cb)
    	table_insert(self.OnSpellCastCb, cb)
	end
    -- draw text on hero
    function Utils:DrawTextOnHero(hero, text, color)
        local pos2D = hero.pos:To2D()
        local posX = pos2D.x - 50
        local posY = pos2D.y
        Draw.Text(text, 50, posX + 50, posY - 15, color)
    end
    -- cached distance
    Utils.CachedDistance = {}
    -- get enemy heroes
    function Utils:GetEnemyHeroes(range)
        local result = {}
        for i, unit in ipairs(Champion.EnemyHeroes) do
        	if self.CachedDistance[i] == nil then
        		self.CachedDistance[i] = unit.distance
    		end
            if self.CachedDistance[i] < range then
                table_insert(result, unit)
            end
        end
        return result
    end
    -- cast
    function Utils:Cast(spell, target, spellprediction, hitchance)
        if not self.CanUseSpell and (target or spellprediction) then
            return
        end
        if not self:CanCast(spell) then
            return
        end
        if spellprediction == nil then
            if target == nil then
                Control.KeyDown(spell)
                Control.KeyUp(spell)
                self:AddTimer(spell)
                for i, cb in ipairs(self.OnSpellCastCb) do
                	cb(spell, target, spellprediction)
            	end
                return
            end
            if Control.CastSpell(spell, target) then
                self.CanUseSpell = false
                self:AddTimer(spell)
                for i, cb in ipairs(self.OnSpellCastCb) do
                	cb(spell, target, spellprediction)
            	end
            end
            return
        end
        if target == nil then
            return
        end
        spellprediction:GetPrediction(target, myHero)
        if spellprediction:CanHit(hitchance or HITCHANCE_HIGH) then
            if Control.CastSpell(spell, spellprediction.CastPosition) then
                self.CanUseSpell = false
                self:AddTimer(spell)
                for i, cb in ipairs(self.OnSpellCastCb) do
                	cb(spell, target, spellprediction)
            	end
            end
        end
    end
    function Utils:CanCast(spell)
        if spell == HK_Q then
            return GetTickCount() > self.LastQ + 100
        end
        if spell == HK_W then
            return GetTickCount() > self.LastW + 100
        end
        if spell == HK_E then
            return GetTickCount() > self.LastE + 100
        end
        if spell == HK_R then
            return GetTickCount() > self.LastR + 100
        end
        return false
    end
    function Utils:AddTimer(spell)
        if spell == HK_Q then
            self.LastQ = GetTickCount()
            return
        end
        if spell == HK_W then
            self.LastW = GetTickCount()
            return
        end
        if spell == HK_E then
            self.LastE = GetTickCount()
            return
        end
        if spell == HK_R then
            self.LastR = GetTickCount()
            return
        end
    end
end

if Champion == nil and myHero.charName == 'Twitch' then
    -- constants
    local TIMER_COLOR = Draw.Color(200, 65, 255, 100)
    local INV_CIRCLE_COLOR = Draw.Color(200, 255, 0, 0)
    local NOT_CIRCLE_COLOR = Draw.Color(200, 188, 77, 26)

    -- menu
    Menu.q_combo                                    = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = false})
    Menu.q_harass                                   = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.q:MenuElement({id = "recall", name = "Recall", type = _G.MENU})
        Menu.q_recall_key                           = Menu.q.recall:MenuElement({id = 'key', name = 'Invisible Recall Key', key = string.byte('P'), value = false, toggle = true})
        Menu.q_recall_note                          = Menu.q.recall:MenuElement({id = 'note', name = 'Note: Key should be diffrent than recall key', type = _G.SPACE})
        Menu.q_recall_key:Value(false)

    Menu.w_combo                                    = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.w_harass                                   = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.w_stopq                                    = Menu.w:MenuElement({id = 'stopq', name = 'Stop using W when has Q', value = true})
    Menu.w_stopr                                    = Menu.w:MenuElement({id = 'stopr', name = 'Stop using W when has R', value = false})
    Menu.w_hitchance                                = Menu.w:MenuElement({id = 'hitchance', name = 'Hitchance', value = 2, drop = {'normal', 'high', 'immobile'}})

    Menu.e_combo                                    = Menu.e:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.e_harass                                   = Menu.e:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.e_xstacks                                  = Menu.e:MenuElement({id = 'xstacks', name = 'X Stacks', value = 6, min = 1, max = 6, step = 1})
    Menu.e_xenemies                                 = Menu.e:MenuElement({id = 'xenemies', name = 'X Enemies', value = 1, min = 1, max = 5, step = 1})
    Menu.e:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
        Menu.e_ks_enabled                           = Menu.e.ks:MenuElement({id = 'enabled', name = 'Enabled', value = true})

    Menu.r_combo                                    = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_harass                                   = Menu.r:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.r_xrange                                   = Menu.r:MenuElement({id = 'xrange', name = 'X Distance', value = 750, min = 300, max = 1500, step = 50})
    Menu.r_xenemies                                 = Menu.r:MenuElement({id = 'xenemies', name = 'X Enemies', value = 3, min = 1, max = 5, step = 1})

    Menu.d_qtimer                                   = Menu.d:MenuElement({id = 'qtimer', name = 'Q Timer', value = true})
    Menu.d_qinvisible                               = Menu.d:MenuElement({id = 'qinvisible', name = 'Q Invisible Range', value = true})
    Menu.d_qnotification                            = Menu.d:MenuElement({id = 'qnotification', name = 'Q Notification Range', value = true})

    -- locals
    local EBuffs = {}
    local Recall = true
    local LastPreInvisible = 0
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 50, Range = 950, Speed = 1400, Type = GGPrediction.SPELLTYPE_CIRCLE})

    -- champion
    Champion =
    {
        CanAttackCb = function()
            local preInvisibleDuration = 1.35 - (Game.Timer() - GG_Spell.QkTimer)
            if preInvisibleDuration > -1 and GetTickCount() > LastPreInvisible + 2000 and preInvisibleDuration < GG_Attack:GetAttackCastTime(0.1) and Game.CanUseSpell(_Q) ~= 0 then
                local buffduration = GG_Buff:GetBuffDuration(myHero, "globalcamouflage")
                if buffduration and buffduration > 3 then
                    LastPreInvisible = GetTickCount()
                    return true
                end
                return false
            end
            return GG_Spell:CheckSpellDelays({q = 0, w = 0.33, e = 0.33, r = 0})
        end,
        CanMoveCb = function()
            return GG_Spell:CheckSpellDelays({q = 0, w = 0.2, e = 0.2, r = 0})
        end,
        OnPostAttack = function()
            local preInvisibleDuration = 1.35 - (Game.Timer() - GG_Spell.QkTimer)
            if preInvisibleDuration > -0.5 and Game.CanUseSpell(_Q) ~= 0 then
                local isAttack = false
                for i = 1, Game.MissileCount() do
                    local missile = Game.Missile(i)
                    if missile then
                        local data = missile.missileData
                        if data then
                            if data.owner == myHero.handle and data.name:lower():find("attack") then
                                isAttack = true
                                break
                            end
                        end
                    end
                end
                if not isAttack then
                    GG_Attack.Reset = true
                    --print("RESET")
                end
            end
        end,
    }
    -- tick
    function Champion:Tick()
    	self:RLogic()
    	self:QLogic()
        if self.IsAttacking or self.CanAttackTarget then
        	return
    	end
        self:ELogic()
        self:WLogic()
    end
    -- draw
    function Champion:Draw()
        self:DrawTimer()
        self:DrawInvisibleCircles()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 0.5, w = 0.33, e = 0.33, r = 0.1}) then
            return
        end
        self:QRecall()
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if not GG_Spell:IsReady(_W, {q = 0, w = 1, e = 0.75, r = 0}) then
            return
        end
        self:WCombo()
    end
    -- e logic
    function Champion:ELogic()
        self.ETargets = Utils:GetEnemyHeroes(1200 - 35)
        self:EBuffManager()
        if not GG_Spell:IsReady(_E, {q = 0, w = 0.25, e = 0.5, r = 0}) then
            return
        end
        self:EKS()
        self:ECombo()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 1, w = 0.33, e = 0.33, r = 0.5}) then
            return
        end
        self:RCombo()
    end
    -- q recall
    function Champion:QRecall()
        if Menu.q_recall_key:Value() == Recall then
            Control.KeyDown(HK_Q)
            Control.KeyUp(HK_Q)
            Control.KeyDown(string.byte("B"))
            Control.KeyUp(string.byte("B"))
            Recall = not Recall
        end
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        if self.AttackTarget then
            Utils:Cast(HK_Q)
        end
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        if Menu.w_stopq:Value() and GG_Buff:HasBuff(myHero, "globalcamouflage") then
            return
        end
        if Menu.w_stopr:Value() and Game.Timer() < GG_Spell.RkTimer + 5.45 then
            return
        end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(Utils:GetEnemyHeroes(950), DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
    end
    -- e buffmanager
    function Champion:EBuffManager()
        for _,hero in ipairs(self.ETargets) do
            local id = hero.networkID
            if EBuffs[id] == nil then EBuffs[id] = {count = 0, duration = 0} end
            local ebuff = GG_Buff:GetBuff(hero, 'twitchdeadlyvenom')
            if ebuff and ebuff.Count > 0 and ebuff.Duration > 0 then
                if EBuffs[id].count < 6 and ebuff.Duration > EBuffs[id].duration then
                    EBuffs[id].count = EBuffs[id].count + 1
                end
                EBuffs[id].duration = ebuff.Duration
            else
                EBuffs[id].count = 0
                EBuffs[id].duration = 0
            end
        end
    end
    -- e ks
    function Champion:EKS()
        if not Menu.e_ks_enabled:Value() then
            return
        end
        for _,hero in ipairs(self.ETargets) do
            local ecount = EBuffs[hero.networkID].count
            if ecount > 0 then
                local elvl = myHero:GetSpellData(_E).level
                local basedmg = 10 + (elvl * 10)
                local perstack = (10 + (5 * elvl)) * ecount
                local bonusAD = myHero.bonusDamage * 0.25 * ecount
                local bonusAP = myHero.ap * 0.2 * ecount
                local edmg = basedmg + perstack + bonusAD + bonusAP
                if GG_Damage:CalculateDamage(myHero, hero, DAMAGE_TYPE_PHYSICAL, edmg) >= hero.health + (1.5 * hero.hpRegen) then
                    Utils:Cast(HK_E)
                    break
                end
            end
        end
    end
    -- e combo
    function Champion:ECombo()
        if not((self.IsCombo and Menu.e_combo:Value()) or (self.IsHarass and Menu.e_harass:Value())) then
            return
        end
        local xenemies = 0
        for _,hero in ipairs(self.ETargets) do
            local ecount = EBuffs[hero.networkID].count
            if ecount > 0 and ecount >= Menu.e_xstacks:Value() then
                xenemies = xenemies + 1
            end
        end
        if xenemies >= Menu.e_xenemies:Value() then
            Utils:Cast(HK_E)
        end
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local enemies = Utils:GetEnemyHeroes(Menu.r_xrange:Value())
        if #enemies >= Menu.r_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    -- draw timer
    function Champion:DrawTimer()
        if not Menu.d_qtimer:Value() then
            return
        end
        local preInvisibleDuration = 1.35 - (Game.Timer() - GG_Spell.QkTimer)
        if preInvisibleDuration > 0 then
            Utils:DrawTextOnHero(myHero, tostring(math.floor(preInvisibleDuration * 1000)), TIMER_COLOR)
            return
        end
        local invisibleDuration = GG_Buff:GetBuffDuration(myHero, "globalcamouflage")
        if invisibleDuration > 0 then
            Utils:DrawTextOnHero(myHero, tostring(math.floor(invisibleDuration * 1000)), TIMER_COLOR)
        end
    end
    -- draw invisible circles
    function Champion:DrawInvisibleCircles()
        if not GG_Buff:HasBuff(myHero, "globalcamouflage") then
            return
        end
        if Menu.d_qinvisible:Value() then
            Draw.Circle(myHero.pos, 500, 1, INV_CIRCLE_COLOR)
        end
        if Menu.d_qnotification:Value() then
            Draw.Circle(myHero.pos, 800, 1, NOT_CIRCLE_COLOR)
        end
    end
end

if Champion == nil and myHero.charName == 'Morgana' then
    -- menu
    Menu.q_combo                        = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass                       = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance                    = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q_useon                        = Menu.q:MenuElement({id = "useon", name = "Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
        Menu.q_auto_enabled             = Menu.q.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.q_auto_hitchance           = Menu.q.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
        Menu.q_auto_useon               = Menu.q.auto:MenuElement({id = "useon", name = "Use on", type = _G.MENU})
    Menu.q:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
        Menu.q_ks_enabled               = Menu.q.ks:MenuElement({id = "enabled", name = "Enabled", value = false})
        Menu.q_ks_hitchance             = Menu.q.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"Normal", "High", "Immobile"}})
    Menu.q:MenuElement({id = "interrupter", name = "Interrupter", type = _G.MENU})
        Menu.q_interrupter_enabled      = Menu.q.interrupter:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.q:MenuElement({id = "attack", name = "DisableAttack", type = _G.MENU})
        Menu.q_attack_disable           = Menu.q.attack:MenuElement({id = "disable", name = "Disable attack if ready or almostReady", value = false})

    Menu.w_combo                        = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = false})
    Menu.w_harass                       = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.w_hitchance                    = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 3, drop = {"Normal", "High", "Immobile"}})
    Menu.w:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
        Menu.w_auto_enabled             = Menu.w.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.w_auto_hitchance           = Menu.w.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 3, drop = {"Normal", "High", "Immobile"}})
    Menu.w:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
        Menu.w_lane_enabled             = Menu.w.lane:MenuElement({id = "enabled", name = "Enabled", value = false})
        Menu.w_lane_count               = Menu.w.lane:MenuElement({id = "count", name = "LaneClear Minions", value = 3, min = 1, max = 5, step = 1})
    Menu.w:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
        Menu.w_ks_enabled               = Menu.w.ks:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.w_ks_hitchance             = Menu.w.ks:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"Normal", "High", "Immobile"}})

    Menu.e_enabled                      = Menu.e:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.e_ally                         = Menu.e:MenuElement({id = "ally", name = "Use on ally", value = true})
    Menu.e_selfish                      = Menu.e:MenuElement({id = "selfish", name = "Use on yourself", value = true})

    Menu.r_combo                        = Menu.r:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.r_harass                       = Menu.r:MenuElement({id = 'harass', name = 'Harass', value = false})
    Menu.r_xenemies                     = Menu.r:MenuElement({id = "xenemies", name = "X Enemies", value = 2, min = 1, max = 5, step = 1})
    Menu.r_xrange                       = Menu.r:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
        Menu.r_auto_enabled             = Menu.r.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.r_auto_xenemies            = Menu.r.auto:MenuElement({id = "xenemies", name = "X Enemies", value = 3, min = 1, max = 5, step = 1})
        Menu.r_auto_xrange              = Menu.r.auto:MenuElement({id = "xrange", name = "X Distance", value = 550, min = 300, max = 600, step = 50})
    Menu.r:MenuElement({id = "ks", name = "Killsteal", type = _G.MENU})
        Menu.r_ks_enabled               = Menu.r.ks:MenuElement({id = "enabled", name = "Enabled", value = true})

    -- locals
    local QPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_LINE, Delay = 0.25, Radius = 70, Range = 1175, Speed = 1200, Collision = true, MaxCollision = 0, CollisionTypes = {GGPrediction.COLLISION_MINION}})
    local WPrediction = GGPrediction:SpellPrediction({Type = GGPrediction.SPELLTYPE_CIRCLE, Delay = 0.25, Radius = 100, Range = 900, Speed = math.huge})
    local EPrediction = {Range = 800}
    local RPrediction = {Range = 625}

    -- champion
    Champion =
    {
        CanAttackCb = function()
            if not GG_Spell:CheckSpellDelays({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
                return false
            end
            -- LastHit, LaneClear
            if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
                return true
            end
            -- Q
            local qdata = myHero:GetSpellData(_Q)
            if Menu.q_attack_disable:Value() and qdata.level > 0 and myHero.mana > qdata.mana and (Game.CanUseSpell(_Q) == 0 or qdata.currentCd < 1) then
                return false
            end
            return true
        end,
        CanMoveCb = function()
            return GG_Spell:CheckSpellDelays({q = 0.25, w = 0.25, e = 0.25, r = 0.25})
        end,
    }
    -- load
    function Champion:Load()
        GG_Object:OnEnemyHeroLoad(function(args)
            Menu.q_auto_useon:MenuElement({id = args.charName, name = args.charName, value = true})
            Menu.q_useon:MenuElement({id = args.charName, name = args.charName, value = true})
        end)
    end
    -- tick
    function Champion:Tick()
        self:QLogic()
        self:WLogic()
        self:ELogic()
        self:RLogic()
    end
    -- q logic
    function Champion:QLogic()
        if not GG_Spell:IsReady(_Q, {q = 1, w = 0.3, e = 0.3, r = 0.3}) then
            return
        end
        self.QTargets = Utils:GetEnemyHeroes(QPrediction.Range)
        self:QKS()
        self:QInterrupter()
        self:QAuto()
        self:QCombo()
    end
    -- w logic
    function Champion:WLogic()
        if not GG_Spell:IsReady(_W, {q = 0.3, w = 1, e = 0.3, r = 0.3}) then
            return
        end
        self.WTargets = Utils:GetEnemyHeroes(WPrediction.Range)
        self:WKS()
        self:WAuto()
        self:WCombo()
        self:WLaneClear()
    end
    -- e logic
    function Champion:ELogic()
        if not GG_Spell:IsReady(_E, {q = 0.3, w = 0.3, e = 1, r = 0.3}) then
            return
        end
        if not Menu.e_enabled:Value() then
            return
        end
        if not Menu.e_ally:Value() and not Menu.e_selfish:Value() then
            return
        end
        self.ETargets = Utils:GetEnemyHeroes(2500)
        self.EAllies = GG_Object:GetAllyHeroes(EPrediction.Range)
        self:EAuto()
    end
    -- r logic
    function Champion:RLogic()
        if not GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 1}) then
            return
        end
        self.RTargets = Utils:GetEnemyHeroes(RPrediction.Range)
        self:RKS()
        self:RAuto()
        self:RCombo()
    end
    -- q ks
    function Champion:QKS()
        if not Menu.q_ks_enabled:Value() then
            return
        end
        local baseDmg = 25
        local lvlDmg = 55 * myHero:GetSpellData(_Q).level
        local apDmg = myHero.ap * 0.9
        local qDmg = baseDmg + lvlDmg + apDmg
        if qDmg < 100 then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, qDmg) then
                Utils:Cast(HK_Q, unit, QPrediction, Menu.q_ks_hitchance:Value() + 1)
            end
        end
    end
    -- q interrupter
    function Champion:QInterrupter()
        if not Menu.q_interrupter_enabled:Value() then
            return
        end
        for i, unit in ipairs(self.QTargets) do
            local spell = unit.activeSpell
            if spell and spell.valid and Utils.InterruptableSpells[spell.name] and spell.castEndTime - Game.Timer() > 0.33 then
                Utils:Cast(HK_Q, enemy, QPrediction, HITCHANCE_NORMAL)
            end
        end
    end
    -- q auto
    function Champion:QAuto()
        if not Menu.q_auto_enabled:Value() then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_auto_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_auto_hitchance:Value() + 1)
    end
    -- q combo
    function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
            return
        end
        local enemies = {}
        for i, unit in ipairs(self.QTargets) do
            local canuse = Menu.q_useon[unit.charName]
            if canuse and canuse:Value() then
                table_insert(enemies, unit)
            end
        end
        Utils:Cast(HK_Q, GG_Target:GetTarget(enemies, DAMAGE_TYPE_MAGICAL), QPrediction, Menu.q_hitchance:Value() + 1)
    end
    -- w ks
    function Champion:WKS()
        if not Menu.w_ks_enabled:Value() then
            return
        end
        local basedmg = 10
        local lvldmg = 14 * myHero:GetSpellData(_W).level
        local apdmg = myHero.ap * 0.22
        local dmg = basedmg + lvldmg + apdmg
        if dmg < 100 then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, dmg) then
                Utils:Cast(HK_W, unit, WPrediction, Menu.w_ks_hitchance:Value() + 1)
            end
        end
    end
    -- w auto
    function Champion:WAuto()
        if not Menu.w_auto_enabled:Value() then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            Utils:Cast(HK_W, unit, WPrediction, Menu.w_auto_hitchance:Value() + 1)
        end
    end
    -- w combo
    function Champion:WCombo()
        if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
            return
        end
        for i, unit in ipairs(self.WTargets) do
            Utils:Cast(HK_W, unit, WPrediction, Menu.w_hitchance:Value() + 1)
        end
    end
    -- w laneclear
    function Champion:WLaneClear()
        if not(self.IsLaneClear and Menu.w_lane_enabled:Value()) then
            return
        end
        local target = nil
        local BestHit = 0
        local CurrentCount = 0
        self.WEnemyMinions = GG_Object:GetEnemyMinions(WPrediction.Range + 250)
        for i, unit in ipairs(self.WEnemyMinions) do
            if unit.distance < WPrediction.Range then
                CurrentCount = 0
                local minionPos = unit.pos
                for j, unit2 in ipairs(self.WEnemyMinions) do
                    if minionPos:DistanceTo(unit2.pos) < 250 then
                        CurrentCount = CurrentCount + 1
                    end
                end
                if CurrentCount > BestHit then
                    BestHit = CurrentCount
                    target = unit
                end
            end
        end
        if target and BestHit >= Menu.w_lane_count:Value() then
            Utils:Cast(HK_W, target)
        end
    end
    -- e auto
    function Champion:EAuto()
        for i, unit in ipairs(self.ETargets) do
            local heroPos = unit.pos
            local s = unit.activeSpell
            if s and s.valid and unit.isChanneling then
                for j, ally in ipairs(self.EAllies) do
                    if (Menu.e_selfish:Value() and ally.isMe) or (Menu.e_ally:Value() and not ally.isMe) then
                        local canUse = false
                        if s.target == ally.handle then
                            canUse = true
                        else
                            local allyPos = ally.pos
                            local spellPos = s.placementPos
                            local width = ally.boundingRadius + 100
                            if s.width > 0 then width = width + s.width end
                            local point, isOnSegment = GGPrediction:ClosestPointOnLineSegment(allyPos, spellPos, heroPos)
                            if isOnSegment and GGPrediction:IsInRange(point, allyPos, width) then
                                canUse = true
                            end
                        end
                        if canUse then
                            Utils:Cast(HK_E, ally)
                        end
                    end
                end
            end
        end
    end
    -- r ks
    function Champion:RKS()
        if not Menu.r_ks_enabled:Value() then
            return
        end
        local basedmg = 75
        local lvldmg = 75 * myHero:GetSpellData(_R).level
        local apdmg = myHero.ap * 0.7
        local rdmg = basedmg + lvldmg + apdmg
        if rdmg < 100 then
            return
        end
        for i, unit in ipairs(self.RTargets) do
            local health = unit.health
            if health > 100 and health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, rdmg) then
                Utils:Cast(HK_R)
            end
        end
    end
    -- r auto
    function Champion:RAuto()
        if not Menu.r_auto_enabled:Value() then
            return
        end
        local count = 0
        for i, unit in ipairs(self.RTargets) do
            if unit.distance < Menu.r_auto_xrange:Value() then
                count = count + 1
            end
        end
        if count >= Menu.r_auto_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
    -- r combo
    function Champion:RCombo()
        if not((self.IsCombo and Menu.r_combo:Value()) or (self.IsHarass and Menu.r_harass:Value())) then
            return
        end
        local count = 0
        for i, unit in ipairs(self.RTargets) do
            if unit.distance < Menu.r_xrange:Value() then
                count = count + 1
            end
        end
        if count >= Menu.r_xenemies:Value() then
            Utils:Cast(HK_R)
        end
    end
end

if Champion == nil and myHero.charName == 'Ezreal' then
    -- menu
    Menu.q_combo = Menu.q:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.q_harass = Menu.q:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.q_hitchance = Menu.q:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q:MenuElement({id = "auto", name = "Auto", type = _G.MENU})
    Menu.q_auto_enabled = Menu.q.auto:MenuElement({id = "enabled", name = "Enabled", value = true, key = string.byte("T"), toggle = true})
    Menu.q_auto_hitchance = Menu.q.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high", "immobile"}})
    Menu.q_auto_mana = Menu.q.auto:MenuElement({id = "mana", name = "Minimum Mana Percent", value = 50, min = 0, max = 100, step = 1})
    Menu.q:MenuElement({id = "lane", name = "LaneClear", type = _G.MENU})
    Menu.q_lh_enabled = Menu.q.lane:MenuElement({id = "lhenabled", name = "LastHit Enabled", value = true})
    Menu.q_lh_mana = Menu.q.lane:MenuElement({id = "lhmana", name = "LastHit Min. Mana %", value = 50, min = 0, max = 100, step = 5})
    Menu.q_lc_enabled = Menu.q.lane:MenuElement({id = "lcenabled", name = "LaneClear Enabled", value = false})
    Menu.q_lc_mana = Menu.q.lane:MenuElement({id = "lcmana", name = "LaneClear Min. Mana %", value = 75, min = 0, max = 100, step = 5})

    Menu.w_combo = Menu.w:MenuElement({id = 'combo', name = 'Combo', value = true})
    Menu.w_harass = Menu.w:MenuElement({id = 'harass', name = 'Harass', value = true})
    Menu.w_hitchance = Menu.w:MenuElement({id = "hitchance", name = "Hitchance", value = 1, drop = {"normal", "high", "immobile"}})
    Menu.w_mana = Menu.w:MenuElement({id = "mana", name = "Min. Mana %", value = 5, min = 0, max = 100, step = 1})

    Menu.e_fake = Menu.e:MenuElement({id = "efake", name = "E Fake Key", value = false, key = string.byte("E")})
    Menu.e_lol = Menu.e:MenuElement({id = "elol", name = "E LoL Key", value = false, key = string.byte("L")})

    Menu.d:MenuElement({name = "Auto Q", id = "autoq", type = _G.MENU})
    Menu.d_autoq_enabled = Menu.d.autoq:MenuElement({id = "enabled", name = "Enabled", value = true})
    Menu.d_autoq_size = Menu.d.autoq:MenuElement({id = "size", name = "Text Size", value = 25, min = 1, max = 64, step = 1})
    Menu.d_autoq_custom = Menu.d.autoq:MenuElement({id = "custom", name = "Custom Position", value = false})
    Menu.d_autoq_width = Menu.d.autoq:MenuElement({id = "posX", name = "Text Position Width", value = Game.Resolution().x * 0.5 - 150, min = 1, max = Game.Resolution().x, step = 1})
    Menu.d_autoq_height = Menu.d.autoq:MenuElement({id = "posY", name = "Text Position Height", value = Game.Resolution().y * 0.5, min = 1, max = Game.Resolution().y, step = 1})

    -- locals
    local LastEFake = 0
    local CanUseQCombo = true
    local QPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 60, Range = 1150, Speed = 2000, Collision = true, Type = GGPrediction.SPELLTYPE_LINE})
    local WPrediction = GGPrediction:SpellPrediction({Delay = 0.25, Radius = 60, Range = 1150, Speed = 1200, Collision = false, Type = GGPrediction.SPELLTYPE_LINE})

    -- on spell cast
    Utils:OnSpellCast(function(spell, target, pred)
    	if spell == HK_W then
    		CanUseQCombo = false
		end
	end)

    -- champion
    Champion =
    {
        CanAttackCb = function()
            return GG_Spell:CheckSpellDelays({q = 0.23, w = 0.23, e = 0.33, r = 1.13})
        end,
        CanMoveCb = function()
            return GG_Spell:CheckSpellDelays({q = 0.1, w = 0.1, e = 0.2, r = 1})
        end,
        OnAttack = function()
        	CanUseQCombo = true
    	end,
    }
    -- load
    function Champion:Load()
        local getDamage = function()
            return ((25 * myHero:GetSpellData(_Q).level) - 10) + (1.1 * myHero.totalDamage) + (0.4 * myHero.ap)
        end
        
        local canLastHit = function()
            return Menu.q_lh_enabled:Value() and self.ManaPercent >= Menu.q_lh_mana:Value()
        end
        
        local canLaneClear = function()
            return Menu.q_lc_enabled:Value() and self.ManaPercent >= Menu.q_lc_mana:Value()
        end
        
        local isQReady = function()
            return GG_Spell:IsReady(_Q, {q = 0.33, w = 0.33, e = 0.2, r = 0.77})
        end
        
        GG_Spell:SpellClear(_Q, QPrediction, isQReady, canLastHit, canLaneClear, getDamage)
    end
    -- wnd msg
    function Champion:WndMsg(msg, wParam)
        if wParam == Menu.e_fake:Key() then
            LastEFake = os.clock()
        end
    end
    -- tick
    function Champion:Tick()
        self:ELogic()
        if self.IsAttacking or self.CanAttackTarget then
        	return
    	end
    	self.QWTargets = Utils:GetEnemyHeroes(QPrediction.Range)
    	self:WLogic()
    	self:QLogic()
    	--self:RLogic()
	end
    -- q logic
    function Champion:QLogic()
    	if not GG_Spell:IsReady(_Q, {q = 0.5, w = 0.33, e = 0.33, r = 1.13}) then
    		return
		end
        if (self.IsCombo or self.IsHarass) and GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 1.13}) and self.ManaPercent >= Menu.w_mana:Value() then
            return
        end
        self:QAuto()
        self:QCombo()
    end
	-- w logic
	function Champion:WLogic()
		if not GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 1.13}) then
			return
		end
		self:WCombo()
    end
	-- e logic
	function Champion:ELogic()
		if not(os.clock() < LastEFake + 0.5 and Game.CanUseSpell(_E) == 0) then
			return
		end
		local key = Menu.e_lol:Key()
		Control.KeyDown(key)
		Control.KeyUp(key)
	end
    -- q auto
    function Champion:QAuto()
		if not Menu.q_auto_enabled:Value() then
			return
		end
		if self.ManaPercent < Menu.q_auto_mana:Value() then
			return
		end
        for i, unit in ipairs(self.QWTargets) do
            Utils:Cast(HK_Q, unit, QPrediction, Menu.q_auto_hitchance:Value() + 1)
        end
	end
	-- q combo
	function Champion:QCombo()
        if not((self.IsCombo and Menu.q_combo:Value()) or (self.IsHarass and Menu.q_harass:Value())) then
        	return
    	end
    	if not CanUseQCombo and self.AttackTarget then
    		return
		end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(self.QWTargets, DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_Q, target, QPrediction, Menu.q_hitchance:Value() + 1)
	end 
    -- w combo
    function Champion:WCombo()
    	if not((self.IsCombo and Menu.w_combo:Value()) or (self.IsHarass and Menu.w_harass:Value())) then
    		return
		end
    	if self.ManaPercent < Menu.w_mana:Value() then
    		return
		end
        local target = self.AttackTarget ~= nil and self.AttackTarget or GG_Target:GetTarget(self.QWTargets, DAMAGE_TYPE_PHYSICAL)
        Utils:Cast(HK_W, target, WPrediction, Menu.w_hitchance:Value() + 1)
	end
	-- draw
    function Champion:Draw()
        if Menu.d_autoq_enabled:Value() then
            local posX, posY
            if Menu.d_autoq_custom:Value() then
                posX = Menu.d_autoq_width:Value()
                posY = Menu.d_autoq_height:Value()
            else
            	local mePos = myHero.pos:To2D()
                posX = mePos.x - 50
                posY = mePos.y
            end
            if Menu.q_auto_enabled:Value() then
                Draw.Text("Auto Q Enabled", Menu.d_autoq_size:Value(), posX, posY, Draw.Color(255, 000, 255, 000))
            else
                Draw.Text("Auto Q Disabled", Menu.d_autoq_size:Value(), posX, posY, Draw.Color(255, 255, 000, 000))
            end
        end
    end
end

--[[
if Champion == nil and myHero.charName == 'Karthus' then
    class "Karthus"

    function Karthus:__init()
        self.QData = {Delay = 1, Radius = 200, Range = 875, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE}
        self.WData = {Delay = 0.25, Radius = 1, Range = 1000, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE}
    end

    function Karthus:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Karthus", id = "Gamsteron_Karthus", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        -- Disable Attack
        Menu.qset:MenuElement({id = "disaa", name = "Disable attack", value = true})
        -- KS
        Menu.qset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.qset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.qset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
        Menu.qset.killsteal:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Auto
        Menu.qset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.qset.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.qset.auto:MenuElement({name = "Use on:", id = "useon", type = _G.MENU})
        GG_Object:OnEnemyHeroLoad(function(args) Menu.qset.auto.useon:MenuElement({id = args.charName, name = args.charName, value = true}) end)
        Menu.qset.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Combo / Harass
        Menu.qset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.qset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.qset.comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- W
        Menu:MenuElement({name = "W settings", id = "wset", type = _G.MENU})
        Menu.wset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.wset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "auto", name = "Auto", value = true})
        Menu.eset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.eset:MenuElement({id = "minmp", name = "minimum mana percent", value = 25, min = 1, max = 100, step = 1})
        --R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        Menu.rset:MenuElement({id = "killsteal", name = "Auto KS X enemies in passive form", value = true})
        Menu.rset:MenuElement({id = "kscount", name = "^^^ X enemies ^^^", value = 2, min = 1, max = 5, step = 1})
        -- Drawings
        Menu:MenuElement({name = "Drawings", id = "draws", type = _G.MENU})
        Menu.draws:MenuElement({name = "Draw Kill Count", id = "ksdraw", type = _G.MENU})
        Menu.draws.ksdraw:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.draws.ksdraw:MenuElement({id = "size", name = "Text Size", value = 25, min = 1, max = 64, step = 1})
    end

    function Karthus:Tick()
        -- Is Attacking
        if GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Has Passive Buff
        local hasPassive = SDKBuff:HasBuff(myHero, "karthusdeathdefiedbuff")
        -- W
        if GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 3.23}) then
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(1000)
                AIO:Cast(HK_W, GG_Target:GetTarget(enemyList, 1), self.WData, Menu.wset.hitchance:Value() + 1)
            end
        end
        -- E
        if GG_Spell:IsReady(_E, {q = 0.33, w = 0.33, e = 0.5, r = 3.23}) and not hasPassive then
            if Menu.eset.auto:Value() or (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(425)
                local eBuff = SDKBuff:HasBuff(myHero, "karthusdefile")
                if eBuff and #enemyList == 0 and AIO:Cast(HK_E) then
                    return
                end
                local manaPercent = 100 * myHero.mana / myHero.maxMana
                if not eBuff and #enemyList > 0 and manaPercent > Menu.eset.minmp:Value() and AIO:Cast(HK_E) then
                    return
                end
            end
        end
        -- Q
        local qdata = myHero:GetSpellData(_Q);
        if (GG_Spell:IsReady(_Q, {q = 0.5, w = 0.33, e = 0.33, r = 3.23}) and qdata.ammoCd == 0 and qdata.ammoCurrentCd == 0 and qdata.ammo == 2 and qdata.ammoTime - Game.Timer() < 0) then
            -- KS
            if Menu.qset.killsteal.enabled:Value() then
                local qDmg = self:GetQDmg()
                local minHP = Menu.qset.killsteal.minhp:Value()
                if qDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(875)
                    for i = 1, #enemyList do
                        local qTarget = enemyList[i]
                        if qTarget.health > minHP and qTarget.health < GG_Damage:CalculateDamage(myHero, qTarget, DAMAGE_TYPE_MAGICAL, self:GetQDmg()) then
                            AIO:Cast(HK_Q, qTarget, self.QData, Menu.qset.killsteal.hitchance:Value() + 1)
                        end
                    end
                end
            end
            -- Combo Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.comhar.harass:Value()) then
                for i = 1, 3 do
                    local enemyList = AIO:GetEnemyHeroes(1000 - (i * 100))
                    AIO:Cast(HK_Q, GG_Target:GetTarget(enemyList, 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1)
                end
                -- Auto
            elseif Menu.qset.auto.enabled:Value() then
                for i = 1, 3 do
                    local qList = {}
                    local enemyList = AIO:GetEnemyHeroes(1000 - (i * 100))
                    for i = 1, #enemyList do
                        local hero = enemyList[i]
                        local heroName = hero.charName
                        if Menu.qset.auto.useon[heroName] and Menu.qset.auto.useon[heroName]:Value() then
                            qList[#qList + 1] = hero
                        end
                    end
                    AIO:Cast(HK_Q, GG_Target:GetTarget(qList, 1), self.QData, Menu.qset.auto.hitchance:Value() + 1)
                end
            end
        end
        -- R
        if GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 0.5}) and Menu.rset.killsteal:Value() and hasPassive then
            local rCount = 0
            local enemyList = AIO:GetEnemyHeroes()
            for i = 1, #enemyList do
                local rTarget = enemyList[i]
                if rTarget.health < GG_Damage:CalculateDamage(myHero, rTarget, DAMAGE_TYPE_MAGICAL, self:GetRDmg()) then
                    rCount = rCount + 1
                end
            end
            if rCount > Menu.rset.kscount:Value() and AIO:Cast(HK_R) then
                return
            end
        end
    end

    function Karthus:Draw()
        if Menu.draws.ksdraw.enabled:Value() and Game.CanUseSpell(_R) == 0 then
            local rCount = 0
            local enemyList = AIO:GetEnemyHeroes()
            for i = 1, #enemyList do
                local rTarget = enemyList[i]
                if rTarget.health < GG_Damage:CalculateDamage(myHero, rTarget, DAMAGE_TYPE_MAGICAL, self:GetRDmg()) then
                    rCount = rCount + 1
                end
            end
            local mePos = myHero.pos:To2D()
            local posX = mePos.x - 50
            local posY = mePos.y
            if rCount > 0 then
                Draw.Text("Kill Count: "..rCount, Menu.draws.ksdraw.size:Value(), posX, posY, Draw.Color(255, 000, 255, 000))
            else
                Draw.Text("Kill Count: "..rCount, Menu.draws.ksdraw.size:Value(), posX, posY, Draw.Color(150, 255, 000, 000))
            end
        end
    end

    function Karthus:CanAttack()
        if not GG_Spell:CheckSpellDelays({q = 0.33, w = 0.33, e = 0.33, r = 3.23}) then
            return false
        end
        if not Menu.qset.disaa:Value() then
            return true
        end
        if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
            return true
        end
        if myHero.mana > myHero:GetSpellData(_Q).mana then
            return false
        end
        return true
    end

    function Karthus:CanMove()
        if not GG_Spell:CheckSpellDelays({q = 0.2, w = 0.2, e = 0.2, r = 3.13}) then
            return false
        end
        return true
    end

    function Karthus:GetQDmg()
        local qLvl = myHero:GetSpellData(_Q).level
        if qLvl == 0 then return 0 end
        local baseDmg = 30
        local lvlDmg = 20 * qLvl
        local apDmg = myHero.ap * 0.3
        return baseDmg + lvlDmg + apDmg
    end

    function Karthus:GetRDmg()
        local rLvl = myHero:GetSpellData(_R).level
        if rLvl == 0 then return 0 end
        local baseDmg = 100
        local lvlDmg = 150 * rLvl
        local apDmg = myHero.ap * 0.75
        return baseDmg + lvlDmg + apDmg
    end
end

if Champion == nil and myHero.charName == 'KogMaw' then
    class "KogMaw"

    function KogMaw:__init()
        self.QData = {Delay = 0.25, Radius = 70, Range = 1175, Speed = 1650, Collision = true, Type = _G.SPELLTYPE_LINE}
        self.EData = {Delay = 0.25, Radius = 120, Range = 1280, Speed = 1350, Collision = false, Type = _G.SPELLTYPE_LINE}
        self.RData = {Delay = 1.2, Radius = 225, Range = 0, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE}
        self.HasWBuff = false
    end

    function KogMaw:CreateMenu()
        Menu = MenuElement({name = "Gamsteron KogMaw", id = "Gamsteron_KogMaw", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        Menu.qset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.qset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- W
        Menu:MenuElement({name = "W settings", id = "wset", type = _G.MENU})
        Menu.wset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.wset:MenuElement({id = "stopq", name = "Stop Q if has W buff", value = false})
        Menu.wset:MenuElement({id = "stope", name = "Stop E if has W buff", value = false})
        Menu.wset:MenuElement({id = "stopr", name = "Stop R if has W buff", value = false})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.eset:MenuElement({id = "emana", name = "Minimum Mana %", value = 20, min = 1, max = 100, step = 1})
        Menu.eset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        Menu.rset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.rset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.rset:MenuElement({id = "onlylow", name = "Only 0-40 % HP enemies", value = true})
        Menu.rset:MenuElement({id = "stack", name = "Stop at x stacks", value = 3, min = 1, max = 9, step = 1})
        Menu.rset:MenuElement({id = "rmana", name = "Minimum Mana %", value = 20, min = 1, max = 100, step = 1})
        Menu.rset:MenuElement({name = "KS", id = "ksmenu", type = _G.MENU})
        Menu.rset.ksmenu:MenuElement({id = "ksr", name = "KS - Enabled", value = true})
        Menu.rset.ksmenu:MenuElement({id = "csksr", name = "KS -> Check R stacks", value = false})
        Menu.rset:MenuElement({name = "Semi Manual", id = "semirkog", type = _G.MENU})
        Menu.rset.semirkog:MenuElement({name = "Semi-Manual Key", id = "semir", key = string.byte("T")})
        Menu.rset.semirkog:MenuElement({name = "Check R stacks", id = "semistacks", value = false})
        Menu.rset.semirkog:MenuElement({name = "Only 0-40 % HP enemies", id = "semilow", value = false})
        Menu.rset.semirkog:MenuElement({name = "Use on:", id = "useon", type = _G.MENU})
        GG_Object:OnEnemyHeroLoad(function(args) Menu.rset.semirkog.useon:MenuElement({id = args.charName, name = args.charName, value = true}) end)
        Menu.rset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    end

    function KogMaw:Tick()
        -- Is Attacking
        if GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Can Attack
        local AATarget = GG_Target:GetComboTarget()
        if AATarget and not GG_Orbwalker.IsNone and GG_Orbwalker:CanAttack() then
            return
        end
        -- W
        if ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.harass:Value())) and SDKAttack:IsBefore(0.55) and GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 0.33}) then
            local enemyList = AIO:GetEnemyHeroesAA(610 + (20 * myHero:GetSpellData(_W).level) + myHero.boundingRadius - 35, true)
            if #enemyList > 0 and AIO:Cast(HK_W) then
                return
            end
        end
        -- Check W Buff
        local HasWBuff = false
        for i = 0, myHero.buffCount do
            local buff = myHero:GetBuff(i)
            if buff and buff.count > 0 and buff.duration > 0 and buff.name == "KogMawBioArcaneBarrage" then
                HasWBuff = true
                break
            end
        end
        self.HasWBuff = HasWBuff
        -- Get Mana Percent
        local manaPercent = 100 * myHero.mana / myHero.maxMana
        -- Save Mana
        local wMana = 40 - (myHero:GetSpellData(_W).currentCd * myHero.mpRegen)
        local meMana = myHero.mana - wMana
        if not(AATarget) and (Game.Timer() < GG_Spell.WTimer + 0.3 or Game.Timer() < GG_Spell.WkTimer + 0.3) then
            return
        end
        -- R
        local result = false
        if meMana > myHero:GetSpellData(_R).mana and GG_Spell:IsReady(_R, {q = 0.33, w = 0.15, e = 0.33, r = 0.5}) then
            self.RData.Range = 900 + 300 * myHero:GetSpellData(_R).level
            local enemyList = AIO:GetEnemyHeroes(self.RData.Range)
            local rStacks = SDKBuff:GetBuffCount(myHero, "kogmawlivingartillerycost") < Menu.rset.stack:Value()
            local checkRStacksKS = Menu.rset.ksmenu.csksr:Value()
            -- KS
            if Menu.rset.ksmenu.ksr:Value() and (not checkRStacksKS or rStacks) then
                local rTargets = {}
                for i = 1, #enemyList do
                    local hero = enemyList[i]
                    local baseRDmg = 60 + (40 * myHero:GetSpellData(_R).level) + (myHero.bonusDamage * 0.65) + (myHero.ap * 0.25)
                    local rMultipier = math.floor(100 - (((hero.health + (hero.hpRegen * 3)) * 100) / hero.maxHealth))
                    local rDmg
                    if rMultipier > 60 then
                        rDmg = baseRDmg * 2
                    else
                        rDmg = baseRDmg * (1 + (rMultipier * 0.00833))
                    end
                    rDmg = GG_Damage:CalculateDamage(myHero, hero, DAMAGE_TYPE_MAGICAL, rDmg)
                    local unitKillable = rDmg > hero.health + (hero.hpRegen * 2)
                    if unitKillable then
                        rTargets[#rTargets + 1] = hero
                    end
                end
                result = AIO:Cast(HK_R, GG_Target:GetTarget(rTargets, 1), self.RData, Menu.rset.hitchance:Value() + 1)
            end if result then return end
            -- SEMI MANUAL
            local checkRStacksSemi = Menu.rset.semirkog.semistacks:Value()
            if Menu.rset.semirkog.semir:Value() and (not checkRStacksSemi or rStacks) then
                local onlyLowR = Menu.rset.semirkog.semilow:Value()
                local rTargets = {}
                if onlyLowR then
                    for i = 1, #enemyList do
                        local hero = enemyList[i]
                        if hero and ((hero.health + (hero.hpRegen * 3)) * 100) / hero.maxHealth < 40 then
                            rTargets[#rTargets + 1] = hero
                        end
                    end
                else
                    rTargets = enemyList
                end
                result = AIO:Cast(HK_R, GG_Target:GetTarget(rTargets, 1), self.RData, Menu.rset.hitchance:Value() + 1)
            end if result then return end
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.rset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.rset.harass:Value()) then
                local stopRIfW = Menu.wset.stopr:Value() and self.HasWBuff
                if not stopRIfW and rStacks and manaPercent > Menu.rset.rmana:Value() then
                    local onlyLowR = Menu.rset.onlylow:Value()
                    local AATarget2
                    if onlyLowR and AATarget and (AATarget.health * 100) / AATarget.maxHealth > 39 then
                        AATarget2 = nil
                    else
                        AATarget2 = AATarget
                    end
                    local t
                    if AATarget2 then
                        t = AATarget2
                    else
                        local rTargets = {}
                        if onlyLowR then
                            for i = 1, #enemyList do
                                local hero = enemyList[i]
                                if hero and ((hero.health + (hero.hpRegen * 3)) * 100) / hero.maxHealth < 40 then
                                    rTargets[#rTargets + 1] = hero
                                end
                            end
                        else
                            rTargets = enemyList
                        end
                        t = GG_Target:GetTarget(rTargets, 1)
                    end
                    result = AIO:Cast(HK_R, t, self.RData, Menu.rset.hitchance:Value() + 1)
                end
            end if result then return end
        end
        -- Q
        local stopQIfW = Menu.wset.stopq:Value() and self.HasWBuff
        if not stopQIfW and meMana > myHero:GetSpellData(_Q).mana and GG_Spell:IsReady(_Q, {q = 0.5, w = 0.15, e = 0.33, r = 0.33}) then
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.harass:Value()) then
                local t
                if AATarget then
                    t = AATarget
                else
                    t = GG_Target:GetTarget(AIO:GetEnemyHeroes(1175), 1)
                end
                result = AIO:Cast(HK_Q, t, self.QData, Menu.qset.hitchance:Value() + 1)
            end
        end if result then return end
        -- E
        local stopEifW = Menu.wset.stope:Value() and self.HasWBuff
        if not stopEifW and manaPercent > Menu.eset.emana:Value() and meMana > myHero:GetSpellData(_E).mana and GG_Spell:IsReady(_E, {q = 0.33, w = 0.15, e = 0.5, r = 0.33}) then
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.harass:Value()) then
                local t
                if AATarget then
                    t = AATarget
                else
                    t = GG_Target:GetTarget(AIO:GetEnemyHeroes(1280), 1)
                end
                result = AIO:Cast(HK_E, t, self.EData, Menu.eset.hitchance:Value() + 1)
            end
        end if result then return end
    end

    function KogMaw:PreAttack(args)
        if ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.harass:Value())) and GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 0.33}) then
            local enemyList = AIO:GetEnemyHeroesAA(610 + (20 * myHero:GetSpellData(_W).level) + myHero.boundingRadius - 35, true)
            if #enemyList > 0 and AIO:Cast(HK_W) then
                args.Process = false
            end
        end
    end

    function KogMaw:CanMove()
        if not GG_Spell:CheckSpellDelays({q = 0.2, w = 0, e = 0.2, r = 0.2}) then
            return false
        end
        return true
    end

    function KogMaw:CanAttack()
        if not GG_Spell:CheckSpellDelays({q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return false
        end
        return true
    end
end

if Champion == nil and myHero.charName == 'Vayne' then
    class "Vayne"

    function Vayne:__init()
        require "MapPositionGOS"
        self.LastReset = 0
        self.EData = {Delay = 0.5, Radius = 0, Range = 550 - 35, Speed = 2000, Collision = false, Type = _G.SPELLTYPE_LINE}
    end

    function Vayne:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Vayne", id = "Gamsteron_Vayne", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        Menu.qset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset:MenuElement({id = "harass", name = "Harass", value = false})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "melee", name = "AntiMelee", value = true})
        Menu.eset:MenuElement({name = "Use on (AntiMelee):", id = "useonmelee", type = _G.MENU})
        GG_Object:OnEnemyHeroLoad(function(args)
            local notMelee = {
                ["Thresh"] = true,
                ["Azir"] = true,
                ["Velkoz"] = true
            }
            local x = SDKData.HEROES[args.charName:lower()]
            if x and x[2] and not notMelee[args.charName] then
                Menu.eset.useonmelee:MenuElement({id = args.charName, name = args.charName, value = true})
            end
        end)
        Menu.eset:MenuElement({id = "dash", name = "AntiDash - kha e, rangar r", value = true})
        Menu.eset:MenuElement({id = "interrupt", name = "Interrupt dangerous spells", value = true})
        Menu.eset:MenuElement({id = "combo", name = "Combo (Stun)", value = true})
        Menu.eset:MenuElement({id = "harass", name = "Harass (Stun)", value = false})
        Menu.eset:MenuElement({name = "Use on (Stun):", id = "useonstun", type = _G.MENU})
        GG_Object:OnEnemyHeroLoad(function(args) Menu.eset.useonstun:MenuElement({id = args.charName, name = args.charName, value = true}) end)
        --R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        Menu.rset:MenuElement({id = "qready", name = "Only if Q ready or almost ready", value = true})
        Menu.rset:MenuElement({id = "combo", name = "Combo - if X enemies near vayne", value = true})
        Menu.rset:MenuElement({id = "xcount", name = "  ^^^ X enemies ^^^", value = 3, min = 1, max = 5, step = 1})
        Menu.rset:MenuElement({id = "xdistance", name = "^^^ max. distance ^^^", value = 500, min = 250, max = 750, step = 50})
    end

    function Vayne:Tick()
        
        -- reset attack after Q
        if Game.CanUseSpell(_Q) ~= 0 and Game.Timer() > self.LastReset + 1 and SDKBuff:HasBuff(myHero, "vaynetumblebonus") then
            GG_Orbwalker:__OnAutoAttackReset()
            self.LastReset = Game.Timer()
        end
        -- reset attack after Q
        
        local result = false
        
        -- r
        if GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.rset.combo:Value() and GG_Spell:IsReady(_R, {q = 0.5, w = 0, e = 0.5, r = 0.5}) then
            local canR = true
            if Menu.rset.qready:Value() then
                canR = false
                if Game.CanUseSpell(_Q) == 0 then canR = true end
                if Game.CanUseSpell(_Q) == 32 and myHero.mana > myHero:GetSpellData(_Q).mana and myHero:GetSpellData(_Q).currentCd < 0.75 then canR = true end
            end
            if canR then
                local countEnemies = 0
                for i = 1, Game.HeroCount() do
                    local hero = Game.Hero(i)
                    if AIO:IsValidHero(hero, Menu.rset.xdistance:Value()) and hero.team == TEAM_ENEMY then
                        countEnemies = countEnemies + 1
                    end
                end
                if countEnemies >= Menu.rset.xcount:Value() then
                    result = AIO:Cast(HK_R)
                end
            end
        end
        -- r

        -- e
        if not result and GG_Spell:IsReady(_E, {q = 0.75, w = 0, e = 0.75, r = 0}) then
            
            -- e antiMelee
            if Menu.eset.melee:Value() then
                local meleeHeroes = {}
                for i = 1, Game.HeroCount() do
                    local hero = Game.Hero(i)
                    if AIO:IsValidHero(hero) and hero.team == TEAM_ENEMY and hero.range < 400 and Menu.eset.useonmelee[hero.charName] and Menu.eset.useonmelee[hero.charName]:Value() and hero.distance < hero.range + myHero.boundingRadius + hero.boundingRadius then
                        _G.table.insert(meleeHeroes, hero)
                    end
                end
                if #meleeHeroes > 0 then
                    _G.table.sort(meleeHeroes, function(a, b) return a.health + (a.totalDamage * 2) + (a.attackSpeed * 100) > b.health + (b.totalDamage * 2) + (b.attackSpeed * 100) end)
                    local meleeTarget = meleeHeroes[1]
                    if SDKMath:IsFacing(meleeTarget, myHero, 60) then
                        AIO:Cast(HK_E, meleeTarget)
                        result = true
                    end
                end
            end
            -- e antiMelee
            
            -- e antiDash
            if not result and Menu.eset.dash:Value() then
                for i = 1, Game.HeroCount() do
                    local hero = Game.Hero(i)
                    if AIO:IsValidHero(hero) and hero.team == TEAM_ENEMY then
                        local path = hero.pathing
                        if path and path.isDashing and hero.posTo and myHero.pos:DistanceTo(hero.posTo) < 500 and SDKMath:IsFacing(hero, myHero, 75) then
                            local extpos = hero.pos:Extended(hero.posTo, path.dashSpeed * (0.07 + _G.LATENCY))
                            if myHero.pos:DistanceTo(extpos) < 550 + myHero.boundingRadius + hero.boundingRadius then
                                AIO:Cast(HK_E, hero)
                                result = true
                                break
                            end
                        end
                    end
                end
            end
            -- e antiDash

            -- e stun
            if not result and ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.harass:Value())) then
                local eRange = self.EData.Range + myHero.boundingRadius
                for i = 1, Game.HeroCount() do
                    local hero = Game.Hero(i)
                    if AIO:IsValidHero(hero, eRange + hero.boundingRadius, true) and hero.team == TEAM_ENEMY then
                        if Menu.eset.useonstun[hero.charName] and Menu.eset.useonstun[hero.charName]:Value() and AIO:CheckWall(myHero.pos, __Path:GetPrediction(hero, myHero, self.EData.Delay + _G.LATENCY, self.EData.Speed), 475) and AIO:CheckWall(myHero.pos, hero.pos, 475) then

                            result = AIO:Cast(HK_E, hero)
                            break
                        end
                    end
                end
            end
            -- e stun
        end
        -- e
        
        -- q
        if not result and GG_Spell:IsReady(_Q, {q = 0.5, w = 0, e = 0.5, r = 0}) then
            
            -- Is Attacking
            local isAttacking = false
            if GG_Orbwalker:IsAutoAttacking() then
                isAttacking = true
            end
            -- Can Attack
            local AATarget = GG_Target:GetComboTarget()
            if AATarget and not GG_Orbwalker.IsNone and GG_Orbwalker:CanAttack() then
                isAttacking = true
            end
            --Q
            if not isAttacking and ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.harass:Value())) then
                local mePos = myHero.pos
                local extended = myHero.pos:Extended(_G.mousePos, 300)
                local meRange = myHero.range + myHero.boundingRadius
                for i = 1, Game.HeroCount() do
                    local hero = Game.Hero(i)
                    if AIO:IsValidHeroAA(hero) and hero.team == TEAM_ENEMY and extended:DistanceTo(hero.pos) < meRange + hero.boundingRadius - 35 then
                        result = AIO:Cast(HK_Q)
                        break
                    end
                end
            end
            
        end
        -- q
        
        return result
    end

    function Vayne:Interrupter()
        SDKInterrupter = AIO:Interrupter()
        SDKInterrupter:OnInterrupt(function(enemy)
            if Menu.eset.interrupt:Value() and GG_Spell:IsReady(_E, {q = 0.75, w = 0, e = 0.5, r = 0}) and enemy.pos:ToScreen().onScreen and enemy.distance < 550 + myHero.boundingRadius + enemy.boundingRadius - 35 then
                AIO:Cast(HK_E, enemy)
            end
        end)
    end

    function Vayne:CanAttack()
        if not GG_Spell:CheckSpellDelays({q = 0.3, w = 0, e = 0.5, r = 0}) then
            return false
        end
        return true
    end

    function Vayne:CanMove()
        if not GG_Spell:CheckSpellDelays({q = 0.2, w = 0, e = 0.4, r = 0}) then
            return false
        end
        return true
    end
end

if Champion == nil and myHero.charName == 'Brand' then
    class "Brand"

    function Brand:__init()
        self.ETarget = nil
        self.QData = {Delay = 0.25, Radius = 60, Range = 1085, Speed = 1600, Collision = true, Type = _G.SPELLTYPE_LINE}
        self.WData = {Delay = 0.9, Radius = 260, Range = 880, Speed = math.huge, Collision = false, Type = _G.SPELLTYPE_CIRCLE}
    end

    function Brand:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Brand", id = "Gamsteron_Brand", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        -- KS
        Menu.qset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.qset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.qset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
        Menu.qset.killsteal:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Auto
        Menu.qset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.qset.auto:MenuElement({id = "stun", name = "Auto Stun", value = true})
        Menu.qset.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Combo / Harass
        Menu.qset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.qset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.qset.comhar:MenuElement({id = "stun", name = "Only if will stun", value = true})
        Menu.qset.comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- W
        Menu:MenuElement({name = "W settings", id = "wset", type = _G.MENU})
        Menu.wset:MenuElement({id = "disaa", name = "Disable attack if ready or almostReady", value = true})
        -- KS
        Menu.wset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.wset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.wset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 200, min = 1, max = 300, step = 1})
        Menu.wset.killsteal:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Auto
        Menu.wset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.wset.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.wset.auto:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- Combo / Harass
        Menu.wset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.wset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.wset.comhar:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "disaa", name = "Disable attack if ready or almostReady", value = true})
        -- KS
        Menu.eset:MenuElement({name = "KS", id = "killsteal", type = _G.MENU})
        Menu.eset.killsteal:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.eset.killsteal:MenuElement({id = "minhp", name = "minimum enemy hp", value = 100, min = 1, max = 300, step = 1})
        -- Auto
        Menu.eset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.eset.auto:MenuElement({id = "stun", name = "If Q ready | no collision & W not ready $ mana for Q + E", value = true})
        Menu.eset.auto:MenuElement({id = "passive", name = "If Q not ready & W not ready $ enemy has passive buff", value = true})
        -- Combo / Harass
        Menu.eset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.eset.comhar:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset.comhar:MenuElement({id = "harass", name = "Harass", value = false})
        --R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        -- Auto
        Menu.rset:MenuElement({name = "Auto", id = "auto", type = _G.MENU})
        Menu.rset.auto:MenuElement({id = "enabled", name = "Enabled", value = true})
        Menu.rset.auto:MenuElement({id = "xenemies", name = ">= X enemies near target", value = 2, min = 1, max = 4, step = 1})
        Menu.rset.auto:MenuElement({id = "xrange", name = "< X distance enemies to target", value = 300, min = 100, max = 600, step = 50})
        -- Combo / Harass
        Menu.rset:MenuElement({name = "Combo / Harass", id = "comhar", type = _G.MENU})
        Menu.rset.comhar:MenuElement({id = "combo", name = "Use R Combo", value = true})
        Menu.rset.comhar:MenuElement({id = "harass", name = "Use R Harass", value = false})
        Menu.rset.comhar:MenuElement({id = "xenemies", name = ">= X enemies near target", value = 1, min = 1, max = 4, step = 1})
        Menu.rset.comhar:MenuElement({id = "xrange", name = "< X distance enemies to target", value = 300, min = 100, max = 600, step = 50})
    end

    function Brand:Tick()
        -- Is Attacking
        if GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Q
        if GG_Spell:IsReady(_Q, {q = 0.5, w = 0.53, e = 0.53, r = 0.33}) then
            -- KS
            if Menu.qset.killsteal.enabled:Value() then
                local baseDmg = 50
                local lvlDmg = 30 * myHero:GetSpellData(_Q).level
                local apDmg = myHero.ap * 0.55
                local qDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.qset.killsteal.minhp:Value()
                if qDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(1050)
                    for i = 1, #enemyList do
                        local qTarget = enemyList[i]
                        if qTarget.health > minHP and qTarget.health < GG_Damage:CalculateDamage(myHero, qTarget, DAMAGE_TYPE_MAGICAL, qDmg) then
                            if AIO:Cast(HK_Q, qTarget, self.QData, Menu.qset.killsteal.hitchance:Value() + 1) then
                                return
                            end
                        end
                    end
                end
            end
            -- Combo Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.comhar.harass:Value()) then
                if Game.Timer() < GG_Spell.EkTimer + 1 and Game.Timer() > GG_Spell.ETimer + 0.33 and AIO:IsValidHero(self.ETarget) and self.ETarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                    if AIO:Cast(HK_Q, self.ETarget, self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(1050)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if SDKBuff:GetBuffDuration(unit, "brandablaze") > 0.5 and unit:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                if AIO:Cast(HK_Q, GG_Target:GetTarget(blazeList, 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                    return
                end
                if not Menu.qset.comhar.stun:Value() and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    if AIO:Cast(HK_Q, GG_Target:GetTarget(AIO:GetEnemyHeroes(1050), 1), self.QData, Menu.qset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                -- Auto
            elseif Menu.qset.auto.stun:Value() then
                if Game.Timer() < GG_Spell.EkTimer + 1 and Game.Timer() < GG_Spell.ETimer + 1 and AIO:IsValidHero(self.ETarget) and self.ETarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                    if AIO:Cast(HK_Q, self.ETarget, self.QData, Menu.qset.auto.hitchance:Value() + 1) then
                        return
                    end
                end
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(1050)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if unit and SDKBuff:GetBuffDuration(unit, "brandablaze") > 0.5 and unit:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                if AIO:Cast(HK_Q, GG_Target:GetTarget(blazeList, 1), self.QData, Menu.qset.auto.hitchance:Value() + 1) then
                    return
                end
            end
        end
        -- E
        if GG_Spell:IsReady(_E, {q = 0.33, w = 0.53, e = 0.5, r = 0.33}) then
            -- antigap
            local enemyList = AIO:GetEnemyHeroes(635)
            for i = 1, #enemyList do
                local unit = enemyList[i]
                if unit and unit.distance < 300 and AIO:Cast(HK_E, unit) then
                    return
                end
            end
            -- KS
            if Menu.eset.killsteal.enabled:Value() then
                local baseDmg = 50
                local lvlDmg = 20 * myHero:GetSpellData(_E).level
                local apDmg = myHero.ap * 0.35
                local eDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.eset.killsteal.minhp:Value()
                if eDmg > minHP then
                    for i = 1, #enemyList do
                        local unit = enemyList[i]
                        if unit and unit.health > minHP and unit.health < GG_Damage:CalculateDamage(myHero, unit, DAMAGE_TYPE_MAGICAL, eDmg) and AIO:Cast(HK_E, unit) then
                            return
                        end
                    end
                end
            end
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.comhar.harass:Value()) then
                local blazeList = {}
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if unit and SDKBuff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                local eTarget = GG_Target:GetTarget(blazeList, 1)
                if eTarget and AIO:Cast(HK_E, eTarget) then
                    self.ETarget = eTarget
                    return
                end
                if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    eTarget = GG_Target:GetTarget(enemyList, 1)
                    if eTarget and AIO:Cast(HK_E, eTarget) then
                        self.ETarget = eTarget
                        return
                    end
                end
                -- Auto
            elseif myHero:GetSpellData(_Q).level > 0 and myHero:GetSpellData(_W).level > 0 then
                -- EQ -> if Q ready | no collision & W not ready $ mana for Q + E
                if Menu.eset.auto.stun:Value() and myHero.mana > myHero:GetSpellData(_Q).mana + myHero:GetSpellData(_E).mana then
                    if (Game.CanUseSpell(_Q) == 0 or myHero:GetSpellData(_Q).currentCd < 0.75) and not(Game.CanUseSpell(_W) == 0 or myHero:GetSpellData(_W).currentCd < 0.75) then
                        local blazeList = {}
                        local enemyList = AIO:GetEnemyHeroes(635)
                        for i = 1, #enemyList do
                            local unit = enemyList[i]
                            if unit and SDKBuff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                                blazeList[#blazeList + 1] = unit
                            end
                        end
                        local eTarget = GG_Target:GetTarget(blazeList, 1)
                        if eTarget and eTarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 and AIO:Cast(HK_E, eTarget) then
                            return
                        end
                        if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.WkTimer + 1.33 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                            eTarget = GG_Target:GetTarget(enemyList, 1)
                            if eTarget and eTarget:GetCollision(self.QData.Radius, self.QData.Speed, self.QData.Delay) == 0 and AIO:Cast(HK_E, eTarget) then
                                self.ETarget = eTarget
                                return
                            end
                        end
                    end
                end
                -- Passive -> If Q not ready & W not ready $ enemy has passive buff
                if Menu.eset.auto.passive:Value() and not(Game.CanUseSpell(_Q) == 0 or myHero:GetSpellData(_Q).currentCd < 0.75) and not(Game.CanUseSpell(_W) == 0 or myHero:GetSpellData(_W).currentCd < 0.75) then
                    local blazeList = {}
                    local enemyList = AIO:GetEnemyHeroes(670)
                    for i = 1, #enemyList do
                        local unit = enemyList[i]
                        if unit and SDKBuff:GetBuffDuration(unit, "brandablaze") > 0.33 then
                            blazeList[#blazeList + 1] = unit
                        end
                    end
                    local eTarget = GG_Target:GetTarget(blazeList, 1)
                    if eTarget and AIO:Cast(HK_E, eTarget) then
                        self.ETarget = eTarget
                        return
                    end
                end
            end
        end
        -- W
        if GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.33, r = 0.33}) then
            -- KS
            if Menu.wset.killsteal.enabled:Value() then
                local baseDmg = 30
                local lvlDmg = 45 * myHero:GetSpellData(_W).level
                local apDmg = myHero.ap * 0.6
                local wDmg = baseDmg + lvlDmg + apDmg
                local minHP = Menu.wset.killsteal.minhp:Value()
                if wDmg > minHP then
                    local enemyList = AIO:GetEnemyHeroes(950)
                    for i = 1, #enemyList do
                        local wTarget = enemyList[i]
                        if wTarget and wTarget.health > minHP and wTarget.health < GG_Damage:CalculateDamage(myHero, wTarget, DAMAGE_TYPE_MAGICAL, wDmg) and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.killsteal.hitchance:Value() + 1) then
                            return;
                        end
                    end
                end
            end
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.comhar.harass:Value()) then
                local blazeList = {}
                local enemyList = AIO:GetEnemyHeroes(950)
                for i = 1, #enemyList do
                    local unit = enemyList[i]
                    if SDKBuff:GetBuffDuration(unit, "brandablaze") > 1.33 then
                        blazeList[#blazeList + 1] = unit
                    end
                end
                local wTarget = GG_Target:GetTarget(blazeList, 1)
                if wTarget and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.comhar.hitchance:Value() + 1) then
                    return
                end
                if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                    wTarget = GG_Target:GetTarget(enemyList, 1)
                    if wTarget and AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.comhar.hitchance:Value() + 1) then
                        return
                    end
                end
                -- Auto
            elseif Menu.wset.auto.enabled:Value() then
                for i = 1, 3 do
                    local blazeList = {}
                    local enemyList = AIO:GetEnemyHeroes(1200 - (i * 100))
                    for j = 1, #enemyList do
                        local unit = enemyList[j]
                        if unit and SDKBuff:GetBuffDuration(unit, "brandablaze") > 1.33 then
                            blazeList[#blazeList + 1] = unit
                        end
                    end
                    local wTarget = GG_Target:GetTarget(blazeList, 1);
                    if wTarget then
                        if AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.auto.hitchance:Value() + 1) then
                            return
                        end
                    end
                    if Game.Timer() > GG_Spell.QkTimer + 0.77 and Game.Timer() > GG_Spell.EkTimer + 0.77 and Game.Timer() > GG_Spell.RkTimer + 0.77 then
                        wTarget = GG_Target:GetTarget(enemyList, 1)
                        if wTarget then
                            if AIO:Cast(HK_W, wTarget, self.WData, Menu.wset.auto.hitchance:Value() + 1) then
                                return
                            end
                        end
                    end
                end
            end
        end
        -- R
        if GG_Spell:IsReady(_R, {q = 0.33, w = 0.33, e = 0.33, r = 0.5}) then
            -- Combo / Harass
            if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.rset.comhar.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.rset.comhar.harass:Value()) then
                local enemyList = AIO:GetEnemyHeroes(750)
                local xRange = Menu.rset.comhar.xrange:Value()
                local xEnemies = Menu.rset.comhar.xenemies:Value()
                for i = 1, #enemyList do
                    local count = 0
                    local rTarget = enemyList[i]
                    if rTarget then
                        for j = 1, #enemyList do
                            if i ~= j then
                                local unit = enemyList[j]
                                if unit and rTarget.pos:DistanceTo(unit.pos) < xRange then
                                    count = count + 1
                                end
                            end
                        end
                        if count >= xEnemies and AIO:Cast(HK_R, rTarget) then
                            return
                        end
                    end
                end
                -- Auto
            elseif Menu.rset.auto.enabled:Value() then
                local enemyList = AIO:GetEnemyHeroes(750)
                local xRange = Menu.rset.auto.xrange:Value()
                local xEnemies = Menu.rset.auto.xenemies:Value()
                for i = 1, #enemyList do
                    local count = 0
                    local rTarget = enemyList[i]
                    if rTarget then
                        for j = 1, #enemyList do
                            if i ~= j then
                                local unit = enemyList[j]
                                if unit and rTarget.pos:DistanceTo(unit.pos) < xRange then
                                    count = count + 1
                                end
                            end
                        end
                        if count >= xEnemies and AIO:Cast(HK_R, rTarget) then
                            return
                        end
                    end
                end
            end
        end
    end

    function Brand:CanMove()
        if not GG_Spell:CheckSpellDelays({q = 0.2, w = 0.2, e = 0.2, r = 0.2}) then
            return false
        end
        return true
    end

    function Brand:CanAttack()
        if not GG_Spell:CheckSpellDelays({q = 0.33, w = 0.33, e = 0.33, r = 0.33}) then
            return false
        end
        -- LastHit, LaneClear
        if not GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and not GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] then
            return true
        end
        -- W
        local wData = myHero:GetSpellData(_W);
        if Menu.wset.disaa:Value() and wData.level > 0 and myHero.mana > wData.mana and (Game.CanUseSpell(_W) == 0 or wData.currentCd < 1) then
            return false
        end
        -- E
        local eData = myHero:GetSpellData(_E);
        if Menu.eset.disaa:Value() and eData.level > 0 and myHero.mana > eData.mana and (Game.CanUseSpell(_E) == 0 or eData.currentCd < 1) then
            return false
        end
        return true
    end
end

if Champion == nil and myHero.charName == 'Varus' then
    class "Varus"

    function Varus:__init()
        self.HasQBuff = false;
        self.QStartTime = 0;
        self.QData = {Delay = 0.1, Radius = 70, Range = 1650, Speed = 1900, Collision = false, Type = _G.SPELLTYPE_LINE};
        self.EData = {Delay = 0.5, Radius = 235, Range = 925, Speed = 1500, Collision = false, Type = _G.SPELLTYPE_CIRCLE};
        self.RData = {Delay = 0.25, Radius = 120, Range = 1075, Speed = 1950, Collision = false, Type = _G.SPELLTYPE_LINE};
    end

    function Varus:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Varus", id = "Gamsteron_Varus", type = _G.MENU})
        -- Q
        Menu:MenuElement({name = "Q settings", id = "qset", type = _G.MENU})
        Menu.qset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.qset:MenuElement({id = "stacks", name = "If enemy has 3 W stacks [ W passive ]", value = true})
        Menu.qset:MenuElement({id = "active", name = "If varus has W buff [ W active ]", value = true})
        Menu.qset:MenuElement({id = "range", name = "No enemies in AA range", value = true})
        Menu.qset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- W
        Menu:MenuElement({name = "W settings", id = "wset", type = _G.MENU})
        Menu.wset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.wset:MenuElement({id = "whp", name = "min. hp %", value = 50, min = 1, max = 100, step = 1})
        -- E
        Menu:MenuElement({name = "E settings", id = "eset", type = _G.MENU})
        Menu.eset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu.eset:MenuElement({id = "range", name = "No enemies in AA range", value = true})
        Menu.eset:MenuElement({id = "stacks", name = "If enemy has 3 W stacks [ W passive ]", value = false})
        Menu.eset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
        -- R
        Menu:MenuElement({name = "R settings", id = "rset", type = _G.MENU})
        Menu.rset:MenuElement({id = "combo", name = "Use R Combo", value = true})
        Menu.rset:MenuElement({id = "harass", name = "Use R Harass", value = false})
        Menu.rset:MenuElement({id = "rci", name = "Use R if enemy isImmobile", value = true})
        Menu.rset:MenuElement({id = "rcd", name = "Use R if enemy distance < X", value = true})
        Menu.rset:MenuElement({id = "rdist", name = "use R if enemy distance < X", value = 500, min = 250, max = 1000, step = 50})
        Menu.rset:MenuElement({id = "hitchance", name = "Hitchance", value = 2, drop = {"normal", "high"}})
    end

    function Varus:WndMsg(msg, wParam)
        if wParam == HK_Q then
            self.QStartTime = os.clock()
        end
    end

    function Varus:Tick()
        -- Check Q Buff
        self.HasQBuff = SDKBuff:HasBuff(myHero, "varusq")
        -- Is Attacking
        if not self.HasQBuff and GG_Orbwalker:IsAutoAttacking() then
            return
        end
        -- Can Attack
        local AATarget = GG_Target:GetComboTarget()
        if not self.HasQBuff and AATarget and not GG_Orbwalker.IsNone and GG_Orbwalker:CanAttack() then
            return
        end
        local result = false
        -- Get Enemies
        local enemyList = AIO:GetEnemyHeroes()
        --R
        if ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.rset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.rset.harass:Value())) and GG_Spell:IsReady(_R, {q = 0.33, w = 0, e = 0.63, r = 0.5}) then
            if Menu.rset.rcd:Value() then
                local enemy = AIO:GetClosestEnemy(enemyList, Menu.rset.rdist:Value())
                if enemy then
                    result = AIO:Cast(HK_R, enemy, self.RData, Menu.rset.hitchance:Value() + 1)
                end
            end
            if not result and Menu.rset.rci:Value() then
                local t = AIO:GetImmobileEnemy(enemyList, 900, 0.25)
                if t and t.distance < self.RData.Range then
                    result = AIO:Cast(HK_R, t)
                end
            end
        end if result then return end
        --E
        if ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.eset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.eset.harass:Value())) and GG_Spell:IsReady(_E, {q = 0.33, w = 0, e = 0.63, r = 0.33}) then
            local aaRange = Menu.eset.range:Value() and not AATarget
            local onlyStacksE = Menu.eset.stacks:Value()
            local eTargets = {}
            for i = 1, #enemyList do
                local hero = enemyList[i]
                if hero.distance < 925 and (SDKBuff:GetBuffCount(hero, "varuswdebuff") == 3 or not onlyStacksE or myHero:GetSpellData(_W).level == 0 or aaRange) then
                    eTargets[#eTargets + 1] = hero
                end
            end
            result = AIO:Cast(HK_E, GG_Target:GetTarget(eTargets, 0), self.EData, Menu.eset.hitchance:Value() + 1)
        end if result then return end
        -- Q
        if (GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.qset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.qset.harass:Value()) then
            local aaRange = Menu.qset.range:Value() and not AATarget
            local wActive = Menu.qset.active:Value() and Game.Timer() < GG_Spell.WkTimer + 3
            -- Q1
            if not self.HasQBuff and GG_Spell:IsReady(_Q, {q = 0.5, w = 0.1, e = 1, r = 0.33}) then
                if Control.IsKeyDown(HK_Q) then
                    Control.KeyUp(HK_Q)
                end
                -- W
                if ((GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO] and Menu.wset.combo:Value()) or (GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS] and Menu.wset.harass:Value())) and GG_Spell:IsReady(_W, {q = 0.33, w = 0.5, e = 0.63, r = 0.33}) then
                    local whp = Menu.wset.whp:Value()
                    for i = 1, #enemyList do
                        local hero = enemyList[i]
                        local hp = 100 * (hero.health / hero.maxHealth)
                        if hp < whp and hero.distance < 1500 then
                            result = AIO:Cast(HK_W)
                            if result then break end
                        end
                    end
                end if result then return end
                local onlyStacksQ = Menu.qset.stacks:Value()
                for i = 1, #enemyList do
                    local hero = enemyList[i]
                    if hero.distance < 1500 and (SDKBuff:GetBuffCount(hero, "varuswdebuff") == 3 or not onlyStacksQ or myHero:GetSpellData(_W).level == 0 or wActive or aaRange) then
                        Control.KeyDown(HK_Q)
                        GG_Spell.QTimer = Game.Timer()
                        result = true
                        break
                    end
                end
                -- Q2
            elseif self.HasQBuff and GG_Spell:IsReady(_Q, {q = 0.2, w = 0, e = 0.63, r = 0.33}) then
                local qTargets = {}
                local onlyStacksQ = Menu.qset.stacks:Value()
                local qTimer = os.clock() - self.QStartTime
                local qExtraRange
                if qTimer < 2 then
                    qExtraRange = qTimer * 0.5 * 700
                else
                    qExtraRange = 700
                end
                for i = 1, #enemyList do
                    local hero = enemyList[i]
                    if hero.distance < 925 + qExtraRange and (SDKBuff:GetBuffCount(hero, "varuswdebuff") == 3 or not onlyStacksQ or myHero:GetSpellData(_W).level == 0 or wActive or aaRange) then
                        table.insert(qTargets, hero)
                    end
                end
                local qt = GG_Target:GetTarget(qTargets, 0)
                if qt then
                    local Pred = GetGamsteronPrediction(qt, self.QData, myHero)
                    if Pred.Hitchance >= Menu.qset.hitchance:Value() + 1 and SDKMath:IsInRange(Pred.CastPosition, myHero.pos, 925 + qExtraRange) and SDKMath:IsInRange(Pred.UnitPosition, myHero.pos, 925 + qExtraRange) then
                        AIO:Cast(HK_Q, Pred.CastPosition)
                    end
                end
            end
        end
    end

    function Varus:CanAttack()
        self.HasQBuff = SDKBuff:HasBuff(myHero, "varusq")
        if not GG_Spell:CheckSpellDelays({q = 0.33, w = 0, e = 0.33, r = 0.33}) then
            return false
        end
        if self.HasQBuff == true then
            return false
        end
        return true
    end

    function Varus:CanMove()
        if not GG_Spell:CheckSpellDelays({q = 0.2, w = 0, e = 0.2, r = 0.2}) then
            return false
        end
        return true
    end
end

if Champion == nil and myHero.charName == 'Jhin' then
    class "Jhin"

    function Jhin:__init()
        
        self.HasPBuff = false
        self.HasRBuff = false
        
        self.R_Polygon = nil
        self.R_CanDraw = false
        self.R_StartPos = nil
        self.R_Pos1 = nil
        self.R_Middle = nil
        self.R_Pos2 = nil
        
        self.QData = {Delay = 0.25, Range = 550, }
        self.WData = {Delay = 0.75, Range = 3000, Radius = 45, Speed = math.huge, Type = 0, Collision = false, }
        self.EData = {Delay = 0.25, Range = 750, Radius = 120, Speed = 1600, Type = 1, Collision = false, }
        self.RData = {Delay = 0.25, Range = 3500, Radius = 80, Speed = 5000, Type = 0, Collision = false, }
    end

    function Jhin:CreateMenu()
        Menu = MenuElement({name = "Gamsteron Jhin", id = "gsojhin", type = MENU})
        Menu:MenuElement({id = "autor", name = "Auto R -> if jhin has R Buff", value = true})
        Menu:MenuElement({name = "Q settings", id = "qset", type = MENU})
        Menu.qset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.qset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu:MenuElement({name = "W settings", id = "wset", type = MENU})
        Menu.wset:MenuElement({id = "stun", name = "Only if stun (marked targets)", value = true})
        Menu.wset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.wset:MenuElement({id = "harass", name = "Harass", value = false})
        Menu:MenuElement({name = "E settings", id = "eset", type = MENU})
        Menu.eset:MenuElement({id = "onlyimmo", name = "Only Immobile", value = true})
        Menu.eset:MenuElement({id = "combo", name = "Combo", value = true})
        Menu.eset:MenuElement({id = "harass", name = "Harass", value = false})
    end

    function Jhin:Tick
        ()
        
        self.HasPBuff = SDKBuff:HasBuff(myHero, "jhinpassivereload")
        
        self:RLogic()
        
        if (self.HasRBuff) then
            return
        end
        
        if (self.HasPBuff or GG_Orbwalker:CanMove()) and SDKCursor.Step == 0 then
            
            if (AIO:IsReadyCombo(_Q, Menu.qset.combo:Value(), Menu.qset.harass:Value(), {q = 1, w = 0.75, e = 0.35, r = 0.5, })) then
                if AIO:CastTarget(HK_Q, self.QData, DAMAGE_TYPE_PHYSICAL, true) then
                    return
                end
            end
            
            if AIO:IsReadyCombo(_W, Menu.wset.combo:Value(), Menu.wset.harass:Value(), {q = 0.35, w = 1, e = 0.35, r = 0.5, }) then
                if AIO:CastSkillShot(HK_W, self.WData, DAMAGE_TYPE_PHYSICAL, false, HITCHANCE_HIGH, function(unit)
                    if (Menu.wset.stun:Value()) then
                        if (SDKBuff:HasBuff(unit, "jhinespotteddebuff")) then
                            return true
                        end
                        return false
                    end
                    return true
                end) then return end
            end
        end
        
        if (AIO:IsReadyCombo(_E, Menu.eset.combo:Value(), Menu.eset.harass:Value(), {q = 0.35, w = 0.75, e = 1, r = 0.5, })) then
            local target = AIO:GetImmobileEnemy(AIO:GetEnemyHeroes(), self.EData.Range, 0.5)
            if target and AIO:Cast(HK_E, target.pos) then
                return
            end
            if not Menu.eset.onlyimmo:Value() and AIO:CastSkillShot(HK_E, self.EData, DAMAGE_TYPE_PHYSICAL, false, HITCHANCE_HIGH) then
                return
            end
        end
    end

    function Jhin:Draw
        ()
        
        if self.R_CanDraw then
            local p1 = self.R_StartPos:To2D()
            local p2 = self.R_Pos1:To2D()
            local p3 = self.R_Pos2:To2D()
            Draw.Line(p1.x, p1.y, p2.x, p2.y, 1, Draw.Color(255, 255, 255, 255))
            Draw.Line(p1.x, p1.y, p3.x, p3.y, 1, Draw.Color(255, 255, 255, 255))
        end
    end

    function Jhin:RLogic
        ()
        
        local spell = myHero.activeSpell
        if (spell and spell.valid and spell.name:lower() == "jhinr") then
            self.HasRBuff = true
            if (self.R_CanDraw == false and Game.Timer() > GG_Spell.RkTimer + 0.250) then
                self.R_CanDraw = true
                local middlePos = Vector(spell.placementPos)
                local startPos = Vector(spell.startPos)
                local pos1 = startPos + (middlePos - startPos):Rotated(0, 30.6 * math.pi / 180, 0):Normalized() * 3500
                local pos2 = startPos + (middlePos - startPos):Rotated(0, -30.6 * math.pi / 180, 0):Normalized() * 3500
                self.R_Polygon =
                {
                    pos1 + (pos1 - startPos):Normalized() * 3500,
                    pos2 + (pos2 - startPos):Normalized() * 3500,
                    startPos,
                }
                self.R_Middle = middlePos
                self.R_Pos1 = pos1
                self.R_Pos2 = pos2
                self.R_StartPos = startPos
            end
            if (self.R_CanDraw == true and Menu.autor:Value() and GG_Spell:IsReady(_R, {q = 0, w = 0, e = 0, r = 0.75})) then
                local rTargets = {}
                local enemyList = AIO:GetEnemyHeroes(3500)
                for i, unit in pairs(enemyList) do
                    if (SDKMath:InsidePolygon(self.R_Polygon, unit) == true) then
                        table.insert(rTargets, unit)
                    end
                end
                local rTarget = GG_Target:GetTarget(rTargets, 0)
                if (rTarget) then
                    local HitChance = 3
                    local Pred = GetGamsteronPrediction(rTarget, self.RData, myHero)
                    if (Pred.Hitchance >= HitChance and SDKMath:InsidePolygon(self.R_Polygon, Pred.CastPosition) == true) then
                        Control.CastSpell(HK_R, Pred.CastPosition)
                    end
                end
            end
        elseif (self.HasRBuff == true and self.R_CanDraw == true and Game.Timer() > GG_Spell.RkTimer + 0.500) then
            self.HasRBuff = false
            self.R_CanDraw = false
        elseif (Game.Timer() < GG_Spell.RkTimer + 0.35) then
            self.HasRBuff = true
        elseif self.HasRBuff then
            self.HasRBuff = false
        end
    end

    function Jhin:CanAttack
        ()
        
        if GG_Spell:CheckSpellDelays({q = 0.25, w = 0.75, e = 0.25, r = 0.5}) and not self.HasPBuff and not self.HasRBuff then
            return true
        end
        return false
    end

    function Jhin:CanMove
        ()
        
        if GG_Spell:CheckSpellDelays({q = 0.15, w = 0.6, e = 0.15, r = 0.5}) and not self.HasRBuff then
            return true
        end
        return false
    end
end]]

if Champion ~= nil then
    function Champion:PreTick()
        self.IsCombo = GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO]
        self.IsHarass = GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS]
        self.IsLaneClear = GG_Orbwalker.Modes[ORBWALKER_MODE_LANECLEAR]
        self.IsLastHit = GG_Orbwalker.Modes[ORBWALKER_MODE_LASTHIT]
        self.AttackTarget = nil
        self.CanAttackTarget = false
        self.IsAttacking = GG_Orbwalker:IsAutoAttacking()
        if not self.IsAttacking and (self.IsCombo or self.IsHarass) then
            self.AttackTarget = GG_Target:GetComboTarget()
            self.CanAttack = GG_Orbwalker:CanAttack()
            if self.AttackTarget and self.CanAttack then
                self.CanAttackTarget = true
            else
                self.CanAttackTarget = false
            end
        end
        self.ManaPercent = 100 * myHero.mana / myHero.maxMana
        self.EnemyHeroes = GG_Object:GetEnemyHeroes(false, false, true, true)
        Utils.CachedDistance = {}
    end
    Callback.Add('Load', function()
        GG_Target = _G.SDK.TargetSelector
        GG_Orbwalker = _G.SDK.Orbwalker
        GG_Buff = _G.SDK.BuffManager
        GG_Damage = _G.SDK.Damage
        GG_Spell = _G.SDK.Spell
        GG_Object = _G.SDK.ObjectManager
        GG_Attack = _G.SDK.Attack
        GG_Orbwalker:CanAttackEvent(Champion.CanAttackCb)
        GG_Orbwalker:CanMoveEvent(Champion.CanMoveCb)
        if Champion.Load then
            Champion:Load()
        end
        if Champion.OnAttack then
        	GG_Orbwalker:OnAttack(Champion.OnAttack)
    	end
        if Champion.OnPostAttack then
            GG_Orbwalker:OnPostAttack(Champion.OnPostAttack)
        end
        if Champion.Tick then
            table.insert(_G.SDK.FastTick, function()
                Champion:PreTick()
                Champion:Tick()
                Utils.CanUseSpell = true
            end)
        end
        if Champion.Draw then
            table.insert(_G.SDK.Draw, function()
                Champion:Draw()
            end)
        end
        if Champion.WndMsg then
            table.insert(_G.SDK.WndMsg, function(msg, wParam)
                Champion:WndMsg(msg, wParam)
            end)
        end
    end)
    return
end
print(myHero.charName .. " not supported !")










































--[[


AIO =
{
}

function AIO:Init()
end

function AIO:CheckWall
    (from, to, distance)

    local pos1 = to + (to - from):Normalized() * 50
    local pos2 = pos1 + (to - from):Normalized() * (distance - 50)
    local point1 = {x=pos1.x, z=pos1.z}
    local point2 = {x=pos2.x, z=pos2.z}
    if MapPosition:intersectsWall(point1, point2) or (MapPosition:inWall(point1) and MapPosition:inWall(point2)) then
        return true
    end
    return false
end

function AIO:Cast
    (spell, unit, spelldata, hitchance)
    
    if unit ~= nil then
        if unit.pos then
            if spelldata == nil then
                return Control.CastSpell(spell, unit)
            end
            local pred = GetGamsteronPrediction(unit, spelldata, myHero)
            if pred.Hitchance >= (hitchance or HITCHANCE_HIGH) then
                return Control.CastSpell(spell, pred.CastPosition)
            end
            return false
        end
        if unit.x then
            return Control.CastSpell(spell, unit)
        end
        return false
    end
    
    if spelldata == nil then
        return Control.CastSpell(spell)
    end
    
    return false
end

function AIO:CastTarget
    (spell, data, damage, bbox, func)
    
    local range = data.Range + (bbox and myHero.boundingRadius or 0) - 35
    local target = GG_Target:GetComboTarget()
    if target == nil or (func and not func(target)) then
        target = GG_Target:GetTarget(AIO:GetEnemyHeroes(range, bbox, func), damage)
    end
    
    if target and target.distance < range + (bbox and target.boundingRadius or 0) then
        return AIO:Cast(spell, target)
    end
    
    return false
end

function AIO:CastSkillShot
    (spell, data, damage, bbox, hitchance, func)
    
    local range = data.Range + (bbox and myHero.boundingRadius or 0) - 35
    local target = GG_Target:GetComboTarget()
    if target == nil or (func and not func(target)) then
        target = GG_Target:GetTarget(AIO:GetEnemyHeroes(range, bbox, func), damage)
    end
    
    if target and target.distance < range + (bbox and target.boundingRadius or 0) then
        return AIO:Cast(spell, target, data, hitchance)
    end
    
    return false
end

function AIO:IsReadyCombo
    (spell, menuCombo, menuHarass, delays)
    
    local isCombo = GG_Orbwalker.Modes[ORBWALKER_MODE_COMBO]
    local isHarass = GG_Orbwalker.Modes[ORBWALKER_MODE_HARASS]
    if ((isCombo and menuCombo) or (isHarass and menuHarass)) and GG_Spell:IsReady(spell, delays) then
        return true
    end
    return false
end

function AIO:GetEnemyHeroes
    (range, bbox, func)
    
    return GG_Object:GetEnemyHeroes(range or 999999, bbox, true, true, false, func)
end

function AIO:GetEnemyHeroesAA
    (range, bbox, func)
    
    return GG_Object:GetEnemyHeroes(range or 999999, bbox, true, true, true, func)
end

function AIO:IsValidHero
    (unit, range, bbox)
    
    if GG_Object:IsValid(unit, Obj_AI_Hero, true, true) and (range == nil or unit.distance < range + (bbox and unit.boundingRadius or 0)) then
        return true
    end
    
    return false
end

function AIO:IsValidHeroAA
    (unit, range, bbox)
    
    if GG_Object:IsValid(unit, Obj_AI_Hero, true, true, true) and (range == nil or unit.distance < range + (bbox and unit.boundingRadius or 0)) then
        return true
    end
    
    return false
end

function AIO:GetClosestEnemy
    (enemyList, maxDistance)
    
    local result = nil
    for i = 1, #enemyList do
        local hero = enemyList[i]
        local distance = hero.distance
        if distance < maxDistance then
            maxDistance = distance
            result = hero
        end
    end
    return result
end

function AIO:ImmobileTime
    (unit)
    
    local iT = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local bType = buff.type
            if bType == 5 or bType == 11 or bType == 21 or bType == 22 or bType == 24 or bType == 29 or buff.name == "recall" then
                local bDuration = buff.duration
                if bDuration > iT then
                    iT = bDuration
                end
            end
        end
    end
    return iT
end

function AIO:GetImmobileEnemy
    (enemyList, maxDistance, minDuration)
    
    minDuration = minDuration or 0
    local result = nil
    local num = 0
    for i = 1, #enemyList do
        local hero = enemyList[i]
        local iT = self:ImmobileTime(hero)
        if hero.distance < maxDistance and iT >= minDuration and iT > num then
            num = iT
            result = hero
        end
    end
    return result
end



]]
