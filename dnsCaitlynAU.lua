require "PremiumPrediction"
require "DamageLib"
require "2DGeometry"
require "MapPositionGOS"

local EnemyHeroes = {}
local AllyHeroes = {}
local EnemySpawnPos = nil
local AllySpawnPos = nil

do
    
    local Version = 1.1
    
    local Files = {
        Lua = {
            Path = SCRIPT_PATH,
            Name = "dnsCaitlynAU.lua",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlynAU/main/dnsCaitlynAU.lua"
        },
        Version = {
            Path = SCRIPT_PATH,
            Name = "dnsCaitlynAU.version",
            Url = "https://raw.githubusercontent.com/fkndns/dnsCaitlynAU/main/dnsCaitlynAU.version"    -- check if Raw Adress correct pls.. after you have create the version file on Github
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
local AARange = 625 + myHero.boundingRadius
local DodgeableRange = 400
local GaleTargetRange = AARange + DodgeableRange + 50
local QMouseSpot = nil

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
--misc
	self.Menu:MenuElement({id = "Misc", name = "Activator", type = MENU})
	self.Menu.Misc:MenuElement({id = "Pots", name = "Auto Use Potions/Refill/Cookies", value = true})
	self.Menu.Misc:MenuElement({id = "HeaBar", name = "Auto Use Heal / Barrier", value = true})
	self.Menu.Misc:MenuElement({id = "Cleanse", name = "Auto Use Cleans", value = true})
	self.Menu.Misc:MenuElement({id = "QSS", name = "Auto Use QSS", value = true})
--GaleForce / Flash Evade
	self.Menu:MenuElement({id = "Evade", name = "Evade", type = MENU})
	self.Menu.Evade:MenuElement({id = "EvadeGaFo", name = "Use Galeforce to Dodge", value = true})
	self.Menu.Evade:MenuElement({id = "EvadeFla", name = "Use Flash to Dodge", value = true})
	self.Menu.Evade:MenuElement({id = "EvadeCalc", name = "Sometimes Dodge Away from Mouse", value = true})
	self.Menu.Evade:MenuElement({id = "EvadeSpells", name = "Enemy Spells to Dodge", type = MENU})
-- RangedHelper
	self.Menu:MenuElement({id = "RangedHelperWalk", name = "Enable KiteAssistance", value = true})

end

function Caitlyn:MenuEvade()
	for i, enemy in pairs(EnemyHeroes) do
		self.Menu.Evade.EvadeSpells:MenuElement({id = enemy.charName, name = enemy.charName, type = MENU})
        self.Menu.Evade.EvadeSpells[enemy.charName]:MenuElement({id = enemy:GetSpellData(_Q).name, name = enemy:GetSpellData(_Q).name, value = false})
        self.Menu.Evade.EvadeSpells[enemy.charName]:MenuElement({id = enemy:GetSpellData(_W).name, name = enemy:GetSpellData(_W).name, value = false})
        self.Menu.Evade.EvadeSpells[enemy.charName]:MenuElement({id = enemy:GetSpellData(_E).name, name = enemy:GetSpellData(_E).name, value = false})
        self.Menu.Evade.EvadeSpells[enemy.charName]:MenuElement({id = enemy:GetSpellData(_R).name, name = enemy:GetSpellData(_R).name, value = false})
	end
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
	if target and ValidTarget(target) then
        --PrintChat(target.pos:To2D())
        --PrintChat(mousePos:To2D())
        GaleMouseSpot = self:RangedHelper(target)
    else
        _G.SDK.Orbwalker.ForceMovement = nil
    end
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
			self:MenuEvade()
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
			local RDamage = getdmg("R", enemy, myHero, myHero:GetSpellData(_R).level) * 0.9
			if GetDistance(enemy.pos) < RRange and GetDistance(enemy.pos) > 1000 and enemy.health < RDamage and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
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
			local QDamage = getdmg("Q", enemy, myHero, myHero:GetSpellData(_Q).level) * 0.9
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
		if enemy and not enemy.dead and ValidTarget(enemy, EPeelRange) and self:CanUse(_E, "NetGap") and self:CastingChecks() and not _G.SDK.Attack:IsActive() then
			if GetDistance(enemy.pos) <= EPeelRange and IsFacing(enemy) and (enemy.ms * 0.8 > myHero.ms or enemy.pathing.isDashing) then
				Control.CastSpell(HK_E, enemy)
			end
		end
		if self.Menu.Misc.HeaBar:Value() and myHero.health / myHero.maxHealth <= 0.3 and enemy.activeSpell.target == myHero.handle then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerHeal" then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerHeal" then
				Control.CastSpell(HK_SUMMONER_2)
			end
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBarrier" then
				Control.CastSpell(HK_SUMMONER_1)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBarrier" then
				Control.CastSpell(HK_SUMMONER_2)
			end
		end
		if self.Menu.Misc.Cleanse:Value() and IsImmobile(myHero) > 0.5 and enemy.activeSpell.target == myHero.handle then
			if myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and IsReady(SUMMONER_1) then
				DelayAction(function() Control.CastSpell(HK_SUMMONER_1) end, 0.04)
			elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and IsReady(SUMMONER_2) then
				DelayAction(function() Control.CastSpell(HK_SUMMONER_2) end, 0.04)
			end
		end
		if (myHero:GetSpellData(SUMMONER_1).name == "SummonerBoost" and IsReady(SUMMONER_1)) or (myHero:GetSpellData(SUMMONER_2).name == "SummonerBoost" and IsReady(SUMMONER_2)) then
		
		else
			if self.Menu.Misc.QSS:Value() and GetItemSlot(myHero, 3140) > 0 and myHero:GetSpellData(GetItemSlot(myHero, 3140)).currentCd == 0 and IsImmobile(myHero) > 0.5 and enemy.activeSpell.target == myHero.handle then
				DelayAction(function() Control.CastSpell(ItemHotKey[GetItemSlot(myHero, 3140)]) end, 0.04)
			elseif self.Menu.Misc.QSS:Value() and GetItemSlot(myHero, 3139) > 0 and myHero:GetSpellData(GetItemSlot(myHero, 3139)).currentCd == 0 and IsImmobile(myHero) > 0.5 and enemy.activeSpell.target == myHero.handle then
				DelayAction(function() Control.CastSpell(ItemHotKey[GetItemSlot(myHero, 3139)]) end, 0.04)
			elseif self.Menu.Misc.QSS:Value() and GetItemSlot(myHero, 6035) > 0 and myHero:GetSpellData(GetItemSlot(myHero, 6035)).currentCd == 0 and IsImmobile(myHero) > 0.5 and enemy.activeSpell.target == myHero.handle then
				DelayAction(function() Control.CastSpell(ItemHotKey[GetItemSlot(myHero, 6035)]) end, 0.04)
			end
		end
        local EEAARange = _G.SDK.Data:GetAutoAttackRange(enemy)
		local AARange = _G.SDK.Data:GetAutoAttackRange(myHero)
            if self:CastingChecks() and not (myHero.pathing and myHero.pathing.isDashing) then  
                local BestGaleDodgeSpot = nil
				--PrintChat("Got Dodge Spot")
                if enemy and ValidTarget(enemy, GaleTargetRange) and (GetDistance(GaleMouseSpot, enemy.pos) < AARange or GetDistance(enemy.pos, myHero.pos) < AARange+150) then
                        BestGaleDodgeSpot = self:GaleDodge(enemy, GaleMouseSpot)	
                else
                        BestGaleDodgeSpot = self:GaleDodge(enemy)
                end
                if  BestGaleDodgeSpot ~= nil then
					if GetItemSlot(myHero, 6671) > 0 and self.Menu.Evade.EvadeGaFo:Value() and myHero:GetSpellData(GetItemSlot(myHero, 6671)).currentCd == 0 then
							Control.CastSpell(ItemHotKey[GetItemSlot(myHero, 6671)], BestGaleDodgeSpot)
                    elseif myHero:GetSpellData(SUMMONER_1).name == "SummonerFlash" and IsReady(SUMMONER_1) and self.Menu.Evade.EvadeFla:Value() and myHero.health/myHero.maxHealth <= 0.4  then
						Control.CastSpell(HK_SUMMONER_1, BestGaleDodgeSpot)
					elseif myHero:GetSpellData(SUMMONER_2).name == "SummonerFlash" and IsReady(SUMMONER_2) and self.Menu.Evade.EvadeFla:Value() and myHero.health/myHero.maxHealth <= 0.4 then
						Control.CastSpell(HK_SUMMONER_2, BestGaleDodgeSpot)
					end	
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
					local pred = _G.PremiumPrediction:GetPrediction(myHero, minion, QSpellData)
					if pred.CastPos and _G.PremiumPrediction.HitChance.Low then
						Control.CastSpell(HK_Q, pred.CastPos)
					end
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

function Caitlyn:GaleDodge(enemy, HelperSpot) 
if enemy.activeSpell and enemy.activeSpell.valid then
        if enemy.activeSpell.target == myHero.handle then 

        elseif enemy.activeSpell.isStopped then
		
		else
            local SpellName = enemy.activeSpell.name
            if (self.Menu.Evade.EvadeSpells[enemy.charName] and self.Menu.Evade.EvadeSpells[enemy.charName][SpellName] and self.Menu.Evade.EvadeSpells[enemy.charName][SpellName]:Value()) or myHero.health/myHero.maxHealth <= 0.15 then




                local CastPos = enemy.activeSpell.startPos
                local PlacementPos = enemy.activeSpell.placementPos
                local width = 100
				local CastTime = enemy.activeSpell.startTime
				local TimeDif = Game.Timer() - CastTime
                if enemy.activeSpell.width > 0 then
                    width = enemy.activeSpell.width
                end
                local SpellType = "Linear"
                if SpellType == "Linear" and PlacementPos and CastPos and TimeDif >= 0.08 then

                    --PrintChat(CastPos)
                    local VCastPos = Vector(CastPos.x, CastPos.y, CastPos.z)
                    local VPlacementPos = Vector(PlacementPos.x, PlacementPos.y, PlacementPos.z)

                    local CastDirection = Vector((VCastPos-VPlacementPos):Normalized())
                    local PlacementPos2 = VCastPos - CastDirection * enemy.activeSpell.range

                    local TargetPos = Vector(enemy.pos)
                    local MouseDirection = Vector((myHero.pos-mousePos):Normalized())
                    local ScanDistance = width*2 + myHero.boundingRadius
                    local ScanSpot = myHero.pos - MouseDirection * ScanDistance
                    local ClosestSpot = Vector(self:ClosestPointOnLineSegment(myHero.pos, PlacementPos2, CastPos))
                    if HelperSpot then 
                        local ClosestSpotHelper = Vector(self:ClosestPointOnLineSegment(HelperSpot, PlacementPos2, CastPos))
                        if ClosestSpot and ClosestSpotHelper then
                            local PlacementDistance = GetDistance(myHero.pos, ClosestSpot)
                            local HelperDistance = GetDistance(HelperSpot, ClosestSpotHelper)
                            if PlacementDistance < width*2 + myHero.boundingRadius then
                                if HelperDistance > width*2 + myHero.boundingRadius then
                                    return HelperSpot
                                elseif self.Menu.Evade.EvadeCalc:Value() then
                                    local DodgeRange = width*2 + myHero.boundingRadius
                                    if DodgeRange < DodgeableRange then
                                        local DodgeSpot = self:GetDodgeSpot(CastPos, ClosestSpot, DodgeRange)
                                        if DodgeSpot ~= nil then
                                           --PrintChat("Dodging to Calced Spot")
                                            return DodgeSpot
                                        end
                                    end
                                end
                            end
                        end
                    else
                        if ClosestSpot then
                            local PlacementDistance = GetDistance(myHero.pos, ClosestSpot)
                            if PlacementDistance < width*2 + myHero.boundingRadius then
                                if self.Menu.Evade.EvadeCalc:Value() then
                                    local DodgeRange = width*2 + myHero.boundingRadius
                                    if DodgeRange < DodgeableRange then
                                        local DodgeSpot = self:GetDodgeSpot(CastPos, ClosestSpot, DodgeRange)
                                        if DodgeSpot ~= nil then
                                           --PrintChat("Dodging to Calced Spot")
                                            return DodgeSpot
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end    
    return nil
end

function Caitlyn:ClosestPointOnLineSegment(p, p1, p2)
    local px = p.x
    local pz = p.z
    local ax = p1.x
    local az = p1.z
    local bx = p2.x
    local bz = p2.z
    local bxax = bx - ax
    local bzaz = bz - az
    local t = ((px - ax) * bxax + (pz - az) * bzaz) / (bxax * bxax + bzaz * bzaz)
    if (t < 0) then
        return p1, false
    end
    if (t > 1) then
        return p2, false
    end
    return {x = ax + t * bxax, z = az + t * bzaz}, true
end

function Caitlyn:GetDodgeSpot(CastSpot, ClosestSpot, width)
    local DodgeSpot = nil
    local RadAngle1 = 90 * math.pi / 180
    local CheckPos1 = ClosestSpot + (CastSpot - ClosestSpot):Rotated(0, RadAngle1, 0):Normalized() * width
    local RadAngle2 = 270 * math.pi / 180
    local CheckPos2 = ClosestSpot + (CastSpot - ClosestSpot):Rotated(0, RadAngle2, 0):Normalized() * width

    if GetDistance(CheckPos1, mousePos) < GetDistance(CheckPos2, mousePos) then
        if GetDistance(CheckPos1, myHero.pos) < DodgeableRange then
            DodgeSpot = CheckPos1
        elseif GetDistance(CheckPos2, myHero.pos) < DodgeableRange then
            DodgeSpot = CheckPos2
        end
    else
        if GetDistance(CheckPos2, myHero.pos) < DodgeableRange then
            DodgeSpot = CheckPos2
        elseif GetDistance(CheckPos1, myHero.pos) < DodgeableRange then
            DodgeSpot = CheckPos1
        end
    end
    return DodgeSpot
end

function Caitlyn:RangedHelper(unit)
    local EAARangel = _G.SDK.Data:GetAutoAttackRange(unit)
    local MoveSpot = nil
    local RangeDif = AARange - EAARangel
    local ExtraRangeDist = RangeDif + -50
    local ExtraRangeChaseDist = RangeDif + -150

    local ScanDirection = Vector((myHero.pos-mousePos):Normalized())
    local ScanDistance = GetDistance(myHero.pos, unit.pos) * 0.8
    local ScanSpot = myHero.pos - ScanDirection * ScanDistance
	

    local MouseDirection = Vector((unit.pos-ScanSpot):Normalized())
    local MouseSpotDistance = EAARangel + ExtraRangeDist
    if not IsFacing(unit) then
        MouseSpotDistance = EAARangel + ExtraRangeChaseDist
    end
    if MouseSpotDistance > AARange then
        MouseSpotDistance = AARange
    end

    local MouseSpot = unit.pos - MouseDirection * (MouseSpotDistance)
	local MouseDistance = GetDistance(unit.pos, mousePos)
    local GaleMouseSpotDirection = Vector((myHero.pos-MouseSpot):Normalized())
    local GalemouseSpotDistance = GetDistance(myHero.pos, MouseSpot)
    if GalemouseSpotDistance > 300 then
        GalemouseSpotDistance = 300
    end
    local GaleMouseSpoty = myHero.pos - GaleMouseSpotDirection * GalemouseSpotDistance
    MoveSpot = MouseSpot

    if MoveSpot then
        if GetDistance(myHero.pos, MoveSpot) < 50 or IsUnderEnemyTurret(MoveSpot) then
            _G.SDK.Orbwalker.ForceMovement = nil
        elseif self.Menu.RangedHelperWalk:Value() and GetDistance(myHero.pos, unit.pos) <= AARange-50 and (Mode() == "Combo" or Mode() == "Harass") and self:CastingChecks() and MouseDistance < 750 then
            _G.SDK.Orbwalker.ForceMovement = MoveSpot
        else
            _G.SDK.Orbwalker.ForceMovement = nil
        end
    end
    return GaleMouseSpoty
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
