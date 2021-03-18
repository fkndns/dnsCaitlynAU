require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

do
    
    local Version = 1.0
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsCaitlyn.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlyn/main/dnsCaitlyn.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsCaitlyn.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlyn/main/dnsCaitlyn.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
        }
    }
    
    local function AutoUpdate()
        
        local function DownloadFile(url, path, fileName)
            DownloadFileAsync(url, path .. fileName, function() end)
            while not FileExist(path .. fileName) do end
        end
        
        local function ReadFile(path, fileName)
            local file = io.open(path .. fileName, "r")
            local result = file:read()
            file:close()
            return result
        end
        
        DownloadFile(Files.Version.Url, Files.Version.Path, Files.Version.Name)
        local textPos = myHero.pos:To2D()
        local NewVersion = tonumber(ReadFile(Files.Version.Path, Files.Version.Name))
        if NewVersion > Version then
            DownloadFile(Files.Lua.Url, Files.Lua.Path, Files.Lua.Name)
            print("New dnsCaitlyn Version. Press 2x F6")     -- <-- you can change the massage for users here !!!!
        else
            print(Files.Version.Name .. ": No Updates Found")   --  <-- here too
        end
    
    end
    
    AutoUpdate()

end

local ItemHotKey = {[ITEM_1] = HK_ITEM_1, [ITEM_2] = HK_ITEM_2,[ITEM_3] = HK_ITEM_3, [ITEM_4] = HK_ITEM_4, [ITEM_5] = HK_ITEM_5, [ITEM_6] = HK_ITEM_6,}

local function GetInventorySlotItem(itemID)
    assert(type(itemID) == "number", "GetInventorySlotItem: wrong argument types (<number> expected)")
    for _, j in pairs({ITEM_1, ITEM_2, ITEM_3, ITEM_4, ITEM_5, ITEM_6}) do
        if myHero:GetItemData(j).itemID == itemID and myHero:GetSpellData(j).currentCd == 0 then return j end
    end
    return nil
end

local function IsNearEnemyTurret(pos, distance)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= distance+915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

local function IsUnderEnemyTurret(pos)
    --PrintChat("Checking Turrets")
    local turrets = _G.SDK.ObjectManager:GetTurrets(GetDistance(pos) + 1000)
    for i = 1, #turrets do
        local turret = turrets[i]
        if turret and GetDistance(turret.pos, pos) <= 915 and turret.team == 300-myHero.team then
            --PrintChat("turret")
            return turret
        end
    end
end

function GetDifference(a,b)
    local Sa = a^2
    local Sb = b^2
    local Sdif = (a-b)^2
    return math.sqrt(Sdif)
end

function GetDistanceSqr(Pos1, Pos2)
    local Pos2 = Pos2 or myHero.pos
    local dx = Pos1.x - Pos2.x
    local dz = (Pos1.z or Pos1.y) - (Pos2.z or Pos2.y)
    return dx^2 + dz^2
end

function GetDistance(Pos1, Pos2)
    return math.sqrt(GetDistanceSqr(Pos1, Pos2))
end

function IsImmobile(unit)
    local MaxDuration = 0
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and buff.count > 0 then
            local BuffType = buff.type
            if BuffType == 5 or BuffType == 11 or BuffType == 21 or BuffType == 22 or BuffType == 24 or BuffType == 29 or buff.name == "recall" then
                local BuffDuration = buff.duration
                if BuffDuration > MaxDuration then
                    MaxDuration = BuffDuration
                end
            end
        end
    end
    return MaxDuration
end

function GetEnemyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isEnemy then
            table.insert(EnemyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetEnemyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if not object.isAlly and object.type == Obj_AI_SpawnPoint then 
            EnemySpawnPos = object
            break
        end
    end
end

function GetAllyBase()
    for i = 1, Game.ObjectCount() do
        local object = Game.Object(i)
        
        if object.isAlly and object.type == Obj_AI_SpawnPoint then 
            AllySpawnPos = object
            break
        end
    end
end

function GetAllyHeroes()
    for i = 1, Game.HeroCount() do
        local Hero = Game.Hero(i)
        if Hero.isAlly then
            table.insert(AllyHeroes, Hero)
            PrintChat(Hero.name)
        end
    end
    --PrintChat("Got Enemy Heroes")
end

function GetBuffStart(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.startTime
        end
    end
    return nil
end

function GetBuffExpire(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.expireTime
        end
    end
    return nil
end

function GetBuffStacks(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

local function GetWaypoints(unit) -- get unit's waypoints
    local waypoints = {}
    local pathData = unit.pathing
    table.insert(waypoints, unit.pos)
    local PathStart = pathData.pathIndex
    local PathEnd = pathData.pathCount
    if PathStart and PathEnd and PathStart >= 0 and PathEnd <= 20 and pathData.hasMovePath then
        for i = pathData.pathIndex, pathData.pathCount do
            table.insert(waypoints, unit:GetPath(i))
        end
    end
    return waypoints
end

local function GetUnitPositionNext(unit)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return nil -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    return waypoints[2] -- all segments have been checked, so the final result is the last waypoint
end

local function GetUnitPositionAfterTime(unit, time)
    local waypoints = GetWaypoints(unit)
    if #waypoints == 1 then
        return unit.pos -- we have only 1 waypoint which means that unit is not moving, return his position
    end
    local max = unit.ms * time -- calculate arrival distance
    for i = 1, #waypoints - 1 do
        local a, b = waypoints[i], waypoints[i + 1]
        local dist = GetDistance(a, b)
        if dist >= max then
            return Vector(a):Extended(b, dist) -- distance of segment is bigger or equal to maximum distance, so the result is point A extended by point B over calculated distance
        end
        max = max - dist -- reduce maximum distance and check next segments
    end
    return waypoints[#waypoints] -- all segments have been checked, so the final result is the last waypoint
end

function GetTarget(range)
    if _G.SDK then
        return _G.SDK.TargetSelector:GetTarget(range, _G.SDK.DAMAGE_TYPE_MAGICAL);
    else
        return _G.GOS:GetTarget(range,"AD")
    end
end

function GotBuff(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        --PrintChat(buff.name)
        if buff.name == buffname and buff.count > 0 then 
            return buff.count
        end
    end
    return 0
end

function BuffActive(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then 
            return true
        end
    end
    return false
end

function IsReady(spell)
    return myHero:GetSpellData(spell).currentCd == 0 and myHero:GetSpellData(spell).level > 0 and myHero:GetSpellData(spell).mana <= myHero.mana and Game.CanUseSpell(spell) == 0
end

function Mode()
    if _G.SDK then
        if _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_COMBO] then
            return "Combo"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_HARASS] or Orbwalker.Key.Harass:Value() then
            return "Harass"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LANECLEAR] or Orbwalker.Key.Clear:Value() then
            return "LaneClear"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_LASTHIT] or Orbwalker.Key.LastHit:Value() then
            return "LastHit"
        elseif _G.SDK.Orbwalker.Modes[_G.SDK.ORBWALKER_MODE_FLEE] then
            return "Flee"
        end
    else
        return GOS.GetMode()
    end
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function IsFacing(unit)
    local V = Vector((unit.pos - myHero.pos))
    local D = Vector(unit.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function IsMyHeroFacing(unit)
    local V = Vector((myHero.pos - unit.pos))
    local D = Vector(myHero.dir)
    local Angle = 180 - math.deg(math.acos(V*D/(V:Len()*D:Len())))
    if math.abs(Angle) < 80 then 
        return true  
    end
    return false
end

function SetMovement(bool)
    if _G.PremiumOrbwalker then
        _G.PremiumOrbwalker:SetAttack(bool)
        _G.PremiumOrbwalker:SetMovement(bool)       
    elseif _G.SDK then
        _G.SDK.Orbwalker:SetMovement(bool)
        _G.SDK.Orbwalker:SetAttack(bool)
    end
end


local function CheckHPPred(unit, SpellSpeed)
     local speed = SpellSpeed
     local range = myHero.pos:DistanceTo(unit.pos)
     local time = range / speed
     if _G.SDK and _G.SDK.Orbwalker then
         return _G.SDK.HealthPrediction:GetPrediction(unit, time)
     elseif _G.PremiumOrbwalker then
         return _G.PremiumOrbwalker:GetHealthPrediction(unit, time)
    end
end

function EnableMovement()
    SetMovement(true)
end

local function IsValid(unit)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        return true;
    end
    return false;
end


local function ValidTarget(unit, range)
    if (unit and unit.valid and unit.isTargetable and unit.alive and unit.visible and unit.networkID and unit.pathing and unit.health > 0) then
        if range then
            if GetDistance(unit.pos) <= range then
                return true;
            end
        else
            return true
        end
    end
    return false;
end

class "Manager"

function Manager:__init()
    if myHero.charName == "Caitlyn" then
        DelayAction(function() self:LoadCaitlyn() end, 1.05)
    end
end


function Manager:LoadCaitlyn()
    Caitlyn:Spells()
    Caitlyn:Menu()
    --
    --GetEnemyHeroes()
    Callback.Add("Tick", function() Caitlyn:Tick() end)
    Callback.Add("Draw", function() Caitlyn:Draw() end)
    if _G.SDK then
        _G.SDK.Orbwalker:OnPreAttack(function(...) Caitlyn:OnPreAttack(...) end)
        _G.SDK.Orbwalker:OnPostAttackTick(function(...) Caitlyn:OnPostAttackTick(...) end)
        _G.SDK.Orbwalker:OnPostAttack(function(...) Caitlyn:OnPostAttack(...) end)
    end
end

class "Caitlyn"

local EnemyLoaded = false
local attackedfirst = 0
local WasInRange = false
local casted = 0
local EnemiesAround = count

function Caitlyn:Menu()
    self.Menu = MenuElement({type = MENU, id = "Caitlyn", name = "dnsCaitlyn"})
    self.Menu:MenuElement({id = "QSpell", name = "Q", type = MENU})
	self.Menu.QSpell:MenuElement({id = "QCombo", name = "Combo", value = true})
	self.Menu.QSpell:MenuElement({id = "QComboHitChance", name = "HitChance", value = 0.7, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.QSpell:MenuElement({id = "QHarass", name = "Harass", value = false})
	self.Menu.QSpell:MenuElement({id = "QHarassHitChance", name = "HitChance", value = 0.7, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.QSpell:MenuElement({id = "QHarassMana", name = "Mana %", value = 40, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QLaneClear", name = "LaneClear", value = false})
	self.Menu.QSpell:MenuElement({id = "QLaneClearMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%"})
	self.Menu.QSpell:MenuElement({id = "QLastHit", name = "LastHit Cannon when out of AA Range", value = true})
	self.Menu.QSpell:MenuElement({id = "QKS", name = "KS", value = true})
	self.Menu:MenuElement({id = "WSpell", name = "W", type = MENU})
	self.Menu.WSpell:MenuElement({id = "WImmo", name = "Auto W immobile Targets", value = true})
	self.Menu:MenuElement({id = "ESpell", name = "E", type = MENU})
	self.Menu.ESpell:MenuElement({id = "ECombo", name = "Combo", value = true})
	self.Menu.ESpell:MenuElement({id = "EComboHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.ESpell:MenuElement({id = "EHarass", name = "Harass", value = false})
	self.Menu.ESpell:MenuElement({id = "EHarassHitChance", name = "HitChance", value = 1, min = 0.1, max = 1.0, step = 0.1})
	self.Menu.ESpell:MenuElement({id = "EHarassMana", name = "Mana %", value = 60, min = 0, max = 100, identifier = "%"})
	self.Menu.ESpell:MenuElement({id = "EGap", name = "Peel Meele Champs", value = true})
	self.Menu:MenuElement({id = "RSpell", name = "R", type = MENU})
	self.Menu.RSpell:MenuElement({id = "RKS", name = "KS", value = true})
	self.Menu:MenuElement({id = "MakeDraw", name = "Nubody nees dravvs", type = MENU})
	self.Menu.MakeDraw:MenuElement({id = "UseDraws", name = "U wanna hav dravvs?", value = false})
	self.Menu.MakeDraw:MenuElement({id = "QDraws", name = "U wanna Q-Range dravvs?", value = false})
	self.Menu.MakeDraw:MenuElement({id = "RDraws", name = "U wanna R-Range dravvs?", value = false})
	self.Menu:MenuElement({id = "Misc", name = "Items/Summs", type = MENU})
	self.Menu.Misc:MenuElement({id = "Pots", name = "Auto Use Potions/Refill/Cookies", value = true})
	self.Menu.Misc:MenuElement({id = "HeaBar", name = "Auto Use Heal / Barrier", value = true})

end

function Caitlyn:Spells()
    QSpellData = {speed = 2200, range = 1300, delay = 0.625, radius = 120, collision = {}, type = "linear"}
	WSpellData = {speed = math.huge, range = 800, delay = 0.25, radius = 60, collision = {}, type = "circular"}
	ESpellData = {speed = math.huge, range = 750, delay = 0.15, radius = 100, collision = {minion}, type = "linear"}
end

function Caitlyn:CastingChecks()
	if not CastingQ or CastingW or CastingE or CastingR then
		return true
	else 
		return false
	end
end

function Caitlyn:Draw()
    if self.Menu.MakeDraw.UseDraws:Value() then
        if self.Menu.MakeDraw.QDraws:Value() then
            Draw.Circle(myHero.pos, 1300, 1, Draw.Color(237, 255, 255, 255))
        end
		if self.Menu.MakeDraw.RDraws:Value() then
			Draw.Circle(myHero.pos, 3500, 1, Draw.Color(237, 255, 255, 255))
		end
    end
end



function Caitlyn:Tick()
    if _G.JustEvade and _G.JustEvade:Evading() or (_G.ExtLibEvade and _G.ExtLibEvade.Evading) or Game.IsChatOpen() or myHero.dead then return end
    target = GetTarget(1400)
	--PrintChat(myHero.activeSpell.name)
    AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
	CastingQ = myHero.activeSpell.name == "CaitlynPiltoverPeacemaker"
	CastingW = myHero.activeSpell.name == "CaitlynYordleTrap"
	CastingE = myHero.activeSpell.name == "CaitlynEntrapment"
	CastingR = myHero.activeSpell.name == "CaitlynAceintheHole"
    self:Logic()
	self:KS()
	self:LastHit()
	self:LaneClear()
	self:Healing()
    if EnemyLoaded == false then
        local CountEnemy = 0
        for i, enemy in pairs(EnemyHeroes) do
            CountEnemy = CountEnemy + 1
        end
        if CountEnemy < 1 then
            GetEnemyHeroes()
        else
            EnemyLoaded = true
            PrintChat("Enemy Loaded")
        end
	end
end

function Caitlyn:KS()
	local count = 0
	for i, enemy in pairs(EnemyHeroes) do
	
	
	if GetDistance(enemy.pos) < 800 then
		count = count + 1
		--PrintChat(EnemiesAround)
	end
		local RRange = 3500 + myHero.boundingRadius + enemy.boundingRadius
		if enemy and not enemy.dead and ValidTarget(enemy, RRange) and self:CanUse(_R, "KS") then
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level)
			if GetDistance(enemy.pos) < RRange and GetDistance(enemy.pos) > 1300 and enemy.health < RDamage and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
				if EnemiesAround == 0 and not IsUnderEnemyTurret(myHero.pos) then
					if enemy.pos:ToScreen().onScreen then
						Control.CastSpell(HK_R, enemy)
					else
						local MMSpot = Vector(enemy.pos):ToMM() 
						local MouseSpotBefore = mousePos
						Control.SetCursorPos(MMSpot.x, MMSpot.y)
						Control.KeyDown(HK_R); Control.KeyUp(HK_R)
						DelayAction(function() Control.SetCursorPos(MouseSpotBefore) end, 0.20)
					end
				end
			end
		end
		local QRange = 1300 + myHero.boundingRadius + enemy.boundingRadius
		if enemy and not enemy.dead and ValidTarget(enemy, QRange) and self:CanUse(_Q, "KS") then
			local QDamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level) * 0.6
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, QSpellData)
			if pred.CastPos and _G.PremiumPrediction.HitChance.High(pred.HitChance) and enemy.health < QDamage and GetDistance(pred.CastPos) > 650 + myHero.boundingRadius + enemy.boundingRadius  and GetDistance(pred.CastPos) < QRange and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
		end
		local WRange = 800 + myHero.boundingRadius + enemy.boundingRadius
		if enemy and not enemy.dead and ValidTarget(enemy, WRange) and self:CanUse(_W, "TrapImmo") then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, enemy, WSpellData)
			if pred.CastPos and _G.PremiumPrediction.HitChance.Immobile(pred.HitChance) and GetDistance(pred.CastPos) < WRange and self:CastingChecks() and not _G.SDK.Attack:IsActive()then
				if (IsImmobile(enemy) > 0.5 or enemy.ms <= 250) and not BuffActive(enemy, "caitlynyordletrapdebuff") then
					Control.CastSpell(HK_W, pred.CastPos)
				end
			end
		end
		local EPeelRange = 250 + myHero.boundingRadius + enemy.boundingRadius
		if enemy and not enemy.dead and ValidTarget(enemy,EPeelRange) and self:CanUse(_E, "NetGap") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			if GetDistance(enemy.pos) <= EPeelRange and IsFacing(enemy) and (enemy.ms * 1.0 > myHero.ms or enemy.pathing.isDashing) then
				Control.CastSpell(HK_E, enemy)
			end
		end
		if self.Menu.Misc.HeaBar:Value() and myHero.health / myHero.maxHealth <= 0.3 and enemy.activeSpell.target == myHero.handle then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" then
				Control.CastSpell(HK_SUMMONER_2)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
				Control.CastSpell(HK_SUMMONER_1)
			end
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" then
				Control.CastSpell(HK_SUMMONER_2)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
				Control.CastSpell(HK_SUMMONER_1)
			end
		end
	end
	EnemiesAround = count
end

function Caitlyn:CanUse(spell, mode)
	local ManaPercent = myHero.mana / myHero.maxMana * 100
	--PrintChat("Can use Runs")
	if mode == nil then
		mode = Mode()
	end
	
	if spell == _Q then
		--PrintChat("Q spell asked for")
		if mode == "Combo" and IsReady(spell) and self.Menu.QSpell.QCombo:Value() then
			--PrintChat("CanUse Q and Combo mode")
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.QSpell.QHarass:Value() and ManaPercent > self.Menu.QSpell.QHarassMana:Value() then
			return true
		end
		if mode == "LaneClear" and IsReady(spell) and self.Menu.QSpell.QLaneClear:Value() and ManaPercent > self.Menu.QSpell.QLaneClearMana:Value() then
			--PrintChat("Checking for Laneclear")
			return true
		end
		if mode == "KS" and IsReady(spell) and self.Menu.QSpell.QKS:Value() then
			return true
		end
		if mode == "LastHit" and IsReady(spell) and self.Menu.QSpell.QLastHit:Value() then
			return true
		end
	elseif spell == _W then
		if mode == "TrapImmo" and IsReady(spell) and self.Menu.WSpell.WImmo:Value() then
			return true
		end
	elseif spell == _E then
		if mode == "Combo" and IsReady(spell) and self.Menu.ESpell.ECombo:Value() then
			return true
		end
		if mode == "Harass" and IsReady(spell) and self.Menu.ESpell.EHarass:Value()and ManaPercent > self.Menu.ESpell.EHarassMana:Value() then
			return true
		end
		if mode == "NetGap" and IsReady(spell) and self.Menu.ESpell.EGap:Value() then
			return true
		end
	elseif spell == _R then
		if mode == "KS" and IsReady(spell) and self.Menu.RSpell.RKS:Value() then
			return true
		end
	end
	return false
end


function Caitlyn:Logic()
    if target == nil then 
        return 
    end
	local maxQRange = 1300 + myHero.boundingRadius + target.boundingRadius
	local minQRange = 650 + myHero.boundingRadius + target.boundingRadius
	local ERange = 750 + myHero.boundingRadius + target.boundingRadius
	
    if Mode() == "Combo" and target then
	--PrintChat("Combo Mode and Target")
	
	
        if self:CanUse(_Q, "Combo") and ValidTarget(target, maxQRange) and Caitlyn:CastingChecks() and not _G.SDK.Attack:IsActive() then
		--PrintChat("ValidTarget can Use q")
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QComboHitChance:Value() and GetDistance(pred.CastPos) > minQRange and GetDistance(pred.CastPos) < maxQRange then
			--PrintChat("Prediction cheks, ready to cast q")
				Control.CastSpell(HK_Q, pred.CastPos)

				end
        end
		if self:CanUse(_E, "Combo") and ValidTarget(target, 750 + target.boundingRadius) then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EComboHitChance:Value() and GetDistance(pred.CastPos)	< ERange and self:CastingChecks() and not _G.SDK.Attack:IsActive()then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	end 
	if Mode() == "Harass" and target then
		if self:CanUse(_Q, "Harass") and ValidTarget(target, maxQRange) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
            local pred = _G.PremiumPrediction:GetPrediction(myHero, target, QSpellData)
			if pred.CastPos and pred.HitChance > self.Menu.QSpell.QHarassHitChance:Value() and GetDistance(pred.CastPos) > minQRange and GetDistance(pred.CastPos) < maxQRange then
				Control.CastSpell(HK_Q, pred.CastPos)
			end
        end
		if self:CanUse(_E, "Harass") and ValidTarget(target, ERange + target.boundingRadius) and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			local pred = _G.PremiumPrediction:GetPrediction(myHero, target, ESpellData)
			if pred.CastPos and pred.HitChance > self.Menu.ESpell.EHarassHitChanceHitChance:Value() and GetDistance < ERange then 
				Control.CastSpell(HK_E, pred.CastPos)
			end
		end
	end
end

function Caitlyn:LaneClear()
	if self:CanUse(_Q, "LaneClear") and Mode() == "LaneClear" then
		local CloseCheckDistance = 60
		local SurroundedMinion = nil
		local MinionsAround = 0
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			local CloseMinions = 0
			for j = 1, #minions do
				local minion2 = minions[j]
				if GetDistance(minion2.pos, minion.pos) < CloseCheckDistance then
					CloseMinions = CloseMinions + 1
				end
			end
			if SurroundedMinion == nil or CloseMinions > MinionsAround then
				SurroundedMinion = minion
				MinionsAround = CloseMinions
			end
		end
		if SurroundedMinion ~= nil and GetDistance(SurroundedMinion.pos) < 1300 + myHero.boundingRadius and self:CastingChecks() and not _G.SDK.Attack:IsActive()then
			Control.CastSpell(HK_Q, SurroundedMinion)
		end
	end
end

function Caitlyn:LastHit()
	if self:CanUse(_Q, "LastHit") and (Mode() == "LastHit" or Mode() == "LaneClear" or Mode() == "Harass") then
		local minions = _G.SDK.ObjectManager:GetEnemyMinions(1300)
		for i = 1, #minions do
			local minion = minions[i]
			if GetDistance(minion.pos) > 650 and GetDistance(minion.pos) < 1300 and (minion.charName == "SRU_ChaosMinionSiege" or minion.charName == "SRU_OrderMinionSiege") then
				local QDam = getdmg("Q", minion, myHero, myHero:GetSpellData(_Q).level)
				if minion and not minion.dead and QDam >= minion.health and self:CastingChecks() and not _G.SDK.Attack:IsActive()then
					Control.CastSpell(HK_Q, minion)
				end
			end
		end
	end
end

function Caitlyn:Healing()
	if myHero.alive == false then return end 
	
	local ItemPot = GetInventorySlotItem(2003)
	local ItemRefill = GetInventorySlotItem(2031)
	local ItemCookie = GetInventorySlotItem(2010)
	--PrintChat(ItemRefill)
	if myHero.health / myHero.maxHealth <= 0.7 and not BuffActive(myHero, "Item2003") and self.Menu.Misc.Pots:Value() and ItemPot ~= nil then
		Control.CastSpell(ItemHotKey[ItemPot])
	end
	if myHero.health / myHero.maxHealth <= 0.7 and not BuffActive(myHero, "ItemCrystalFlask") and self.Menu.Misc.Pots:Value() and myHero:GetItemData(ItemRefill).ammo > 0 and ItemRefill ~= nil then
		Control.CastSpell(ItemHotKey[ItemRefill])
	end
	if (myHero.health / myHero.maxHealth <= 0.3 or myHero.mana / myHero.maxMana <= 0.2) and not BuffActive(myHero, "Item2010") and self.Menu.Misc.Pots:Value() and ItemCookie ~= nil then
		Control.CastSpell(ItemHotKey[ItemCookie])
	end
	
end
function Caitlyn:OnPostAttack(args)
end

function Caitlyn:OnPostAttackTick(args)
end

function Caitlyn:OnPreAttack(args)
end



function OnLoad()
    Manager()
end
