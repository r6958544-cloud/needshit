--[[
	Z-City FPV Drone — самостоятельная версия (без патчей).

	Основа — FPV Drone из Workshop 3815959470 (камера, HUD «нет сигнала», пульт),
	но взрыв полностью переписан под систему Z-City (как граната ent_hg_grenade):
	  * util.BlastDamage
	  * осколки Lua-пулями Z-City (Metal Debris + hg.bulletHit)
	  * отброс физики/рагдоллов, дезориентация, лёгкий стан
	  * звуки/партиклы гранаты
	Без Z-City работает как обычный blast + осколки.
]]

AddCSLuaFile()

ENT.Type      = "anim"
ENT.PrintName = "FPV Drone (Z-City)"
ENT.Author    = "FPV Drone / Z-City compat"
ENT.Spawnable = false -- появляется только через пульт

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "Controller")
end

local function cv(name, def)
	local c = GetConVar(name)
	if c then return c:GetFloat() end
	return def or 0
end

local function cvBool(name, def)
	local c = GetConVar(name)
	if c then return c:GetBool() end
	return def or false
end

local vector_up = Vector(0, 0, 1)
local vecCone = Vector(0, 0, 0)

-- модель: по умолчанию квадрокоптер из комплекта; zfpv_model переопределяет
local function pickModel()
	local c = GetConVar("zfpv_model")
	local want = c and c:GetString() or ""
	if want ~= "" and file.Exists(want, "GAME") then return want, 1 end
	return "models/kamik/ardrone.mdl", 1
end

if SERVER then
	-- конварки взрыва (создаются, если ещё нет)
	local defaults = {
		{ name = "zfpv_zc_explosion",     default = 1,   min = 0,   max = 1,    text = "1 = взрыв через систему Z-City, 0 = обычный env_explosion" },
		{ name = "zfpv_blast_radius",     default = 8,   min = 1,   max = 40,   text = "Радиус взрыва в МЕТРАХ (граната Z-City = 8)" },
		{ name = "zfpv_blast_damage",     default = 35,  min = 0,   max = 500,  text = "Blast-урон (граната Z-City = 35)" },
		{ name = "zfpv_blast_frag",       default = 600, min = 0,   max = 2000, text = "Осколков (граната Z-City = 900)" },
		{ name = "zfpv_blast_frag_damage",default = 40,  min = 1,   max = 200,  text = "Урон осколка (граната = 40)" },
		{ name = "zfpv_blast_frag_pen",   default = 8,   min = 0,   max = 50,   text = "Пробитие осколка (граната = 8)" },
	}
	for _, d in ipairs(defaults) do
		if not ConVarExists(d.name) then
			CreateConVar(d.name, tostring(d.default), bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), d.text, d.min, d.max)
		end
	end

	if not ConVarExists("zfpv_model") then
		CreateConVar("zfpv_model", "", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), "Модель дрона (пусто = авто)")
	end

	--------------------------------------------------------------- осколки
	local function shootShrapnel(attacker, pos, count, dmg, pen)
		if count <= 0 then return end
		if not IsValid(attacker) then attacker = Entity(0) end

		local world = game.GetWorld()
		local useLua = isfunction(world.FireLuaBullets)
			and hg ~= nil
			and isfunction(hg.bulletHit)
			and istable(hg.ammotypeshuy)
			and hg.ammotypeshuy["Metal Debris"] ~= nil

		local ammotype = {}
		if useLua then
			local t = hg.ammotypeshuy["Metal Debris"]
			ammotype = (t and t.BulletSettings) or {}
		else
			count = math.min(count, 150)
		end

		local left = count
		local name = "ZFPV_shrap_" .. tostring(math.floor(CurTime() * 1000)) .. "_" .. tostring(math.random(1, 99999))

		local function shootOne()
			local dir = VectorRand()
			dir[3] = dir[3] > 0 and math.abs(dir[3] - 0.5) or -math.abs(dir[3] + 0.5)
			dir:Normalize()

			if useLua then
				world:FireLuaBullets({
					Speed = ammotype.Speed,
					Distance = 56756,
					penetrated = 0,
					MaxPenLen = 100,
					Penetration = pen,
					Diameter = ammotype.Diameter or 1,
					Src = pos,
					Spread = vecCone,
					Force = 20,
					Damage = dmg,
					AmmoType = "Metal Debris",
					Attacker = attacker,
					Inflictor = world,
					DisableLagComp = true,
					Filter = {},
					Dir = dir,
					Callback = hg.bulletHit,
				})
				return
			end

			local tr = util.TraceLine({ start = pos, endpos = pos + dir * 20000, mask = MASK_SHOT })
			if tr.Hit and IsValid(tr.Entity) then
				local di = DamageInfo()
				di:SetDamage(dmg)
				di:SetAttacker(attacker)
				di:SetInflictor(world)
				di:SetDamagePosition(tr.HitPos)
				di:SetDamageType(DMG_BULLET)
				tr.Entity:TakeDamageInfo(di)
			end
		end

		local function shootBatch()
			if left <= 0 then timer.Remove(name) return end
			local ok, err = pcall(function()
				for _ = 1, math.min(60, left) do
					left = left - 1
					shootOne()
				end
			end)
			if not ok then
				ErrorNoHalt("[ZFPV] осколки: " .. tostring(err) .. "\n")
				left = 0
			end
			if left <= 0 then timer.Remove(name) end
		end

		shootBatch()
		if left > 0 then timer.Create(name, 0.03, 0, shootBatch) end
	end

	--------------------------------------------------------------- взрыв Z-City
	local function zcBlast(attacker, pos)		if not IsValid(attacker) then attacker = Entity(0) end

		local radiusM = cv("zfpv_blast_radius", 8)
		local damage  = cv("zfpv_blast_damage", 35)
		local frag    = math.floor(cv("zfpv_blast_frag", 600))
		local fragDmg = cv("zfpv_blast_frag_damage", 40)
		local fragPen = cv("zfpv_blast_frag_pen", 8)
		local dis     = radiusM / 0.01905

		-- 1) урон по площади
		pcall(function()
			util.BlastDamage(attacker, attacker, pos, dis, damage)
		end)

		-- 2) видимый эффект и звук (работают в любом гейммоде)
		pcall(function()
			local ed = EffectData()
			ed:SetOrigin(pos)
			ed:SetScale(radiusM / 2.5)
			util.Effect("Explosion", ed)
			util.Effect("eff_jack_genericboom", ed)
			sound.Play("weapons/explode3.wav", pos, 140, math.random(90, 110))
		end)

		-- 3) Z-City звук/партиклы
		pcall(function()
			if ParticleEffect then
				ParticleEffect("pcf_jack_airsplode_small3", pos, Angle(90, 0, 0))
			end
			local det = { "m67/m67_detonate_01.wav", "m67/m67_detonate_02.wav", "m67/m67_detonate_03.wav" }
			EmitSound(det[math.random(#det)], pos, 0, CHAN_STATIC, 1, 145, nil, math.random(80, 90))
			if hg and isfunction(hg.EmitAISound) then
				hg.EmitAISound(pos, 512, 16, 1)
			end
		end)

		-- 4) физика, рагдоллы, дезориентация
		pcall(function()
			if not (hg and isfunction(hg.ExplosionTrace)) then return end

			local disorientationDis = 6 / 0.01905

			for _, enta in ipairs(ents.FindInSphere(pos, disorientationDis)) do
				if IsValid(enta) then
					local tracePos = enta:IsPlayer() and (enta:GetPos() + enta:OBBCenter()) or enta:GetPos()
					local tr = hg.ExplosionTrace(pos, tracePos, {})

					local force = enta:GetPos() - pos
					local len = math.max(force:Length(), 1)
					force:Div(len)

					local frac = math.Clamp((disorientationDis - len) / disorientationDis, 0.1, 1)
					local physicsFrac = math.Clamp((dis - len) / dis, 0.5, 1)
					local forceAdd = force * physicsFrac * 50000

					if enta.organism then
						local behindWall = tr.Entity ~= enta and tr.MatType ~= MAT_GLASS
						if IsValid(enta.organism.owner) and enta.organism.owner:IsPlayer() and not behindWall then
							if isfunction(hg.ExplosionDisorientation) then
								hg.ExplosionDisorientation(enta, 5 * frac, 6 * frac)
							end
							if isfunction(hg.RunZManipAnim) then
								hg.RunZManipAnim(enta.organism.owner, "shieldexplosion")
							end
						end
					end

					if len <= dis and tr.Entity == enta then
						if enta:IsPlayer() then
							if isfunction(hg.AddForceRag) then
								hg.AddForceRag(enta, 0, forceAdd * 0.5, 0.5)
								hg.AddForceRag(enta, 1, forceAdd * 0.5, 0.5)
							end
							if isfunction(hg.LightStunPlayer) then
								hg.LightStunPlayer(enta)
							end
						end

						local phys = enta:GetPhysicsObject()
						if IsValid(phys) then
							phys:ApplyForceCenter(forceAdd)
						end
					end
				end
			end

			util.ScreenShake(pos, 35, 200, 1, 1000)
		end)

		-- 5) осколки
		pcall(shootShrapnel, attacker, pos, frag, fragDmg, fragPen)
	end

	ZFPVBlast = zcBlast

	--------------------------------------------------------------- сущность
	function ENT:Initialize()
		local mdl, scale = pickModel()
		self:SetModel(mdl)
		if scale and scale ~= 1 then self:SetModelScale(scale, 0) end

		self:SetColor(Color(45, 45, 50))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:SetMass(15)
			phys:EnableGravity(false)
			phys:SetDamping(0, 0)
		end

		self.ArmTime      = CurTime() + 0.4
		self.DroneHealth  = math.max(1, cv("zfpv_health", 30))
		self.Exploded     = false
		self.WantExplode  = false
		self.WantRecall   = false
		self.Released     = false

		self.EngineSound = CreateSound(self, "npc/manhack/mh_engine_loop1.wav")
		if self.EngineSound then
			self.EngineSound:PlayEx(0.6, 100)
		end
	end

	function ENT:OnTakeDamage(dmg)
		if self.Exploded then return end
		self.DroneHealth = self.DroneHealth - dmg:GetDamage()
		if self.DroneHealth <= 0 then
			if cvBool("zfpv_blast_on_damage", false) then
				self.WantExplode = true
			else
				self:Remove()
			end
		end
	end

	function ENT:PhysicsCollide(data, phys)
		if self.Exploded or CurTime() < self.ArmTime then return end
		-- по умолчанию удары безвредны: взрыв только по ЛКМ
		if not cvBool("zfpv_blast_on_impact", false) then return end
		if data.Speed >= cv("zfpv_min_impact_speed", 120) then
			self.WantExplode = true
		end
	end

	function ENT:Think()
		if self.Exploded then return end

		if self.WantExplode then self:Explode() return end
		if self.WantRecall then self:Remove() return end

		local phys = self:GetPhysicsObject()
		local ply  = self:GetController()
		local controlled = IsValid(ply) and ply:Alive()
			and ply:GetNWEntity("ZFPVDrone") == self and ply.ZFPVInput

		if controlled and IsValid(phys) then
			local input = ply.ZFPVInput
			local ang   = input.ang
			local dt    = FrameTime()

			local dir = ang:Forward() * input.f + ang:Right() * input.s + vector_up * input.u
			if dir:LengthSqr() > 1 then dir:Normalize() end

			local speed  = cv("zfpv_speed", 450) * (input.boost and cv("zfpv_boost", 1.5) or 1)
			local target = dir * speed

			local vel = LerpVector(1 - math.exp(-5 * dt), phys:GetVelocity(), target)
			phys:Wake()
			phys:SetVelocity(vel)

			local roll = math.Clamp(vel:Dot(ang:Right()) * 0.04, -35, 35)
			phys:SetAngles(Angle(ang.p, ang.y, roll))
			phys:AddAngleVelocity(-phys:GetAngleVelocity())

			if self.EngineSound then
				self.EngineSound:ChangePitch(math.Clamp(90 + vel:Length() * 0.06, 90, 200), 0.1)
			end
		else
			if not self.Released then
				self.Released = true
				self.DieAt = CurTime() + cv("zfpv_fuse", 20)
				if IsValid(phys) then
					phys:EnableGravity(true)
					phys:SetDamping(0.2, 0.2)
				end
			end
			if self.DieAt and CurTime() >= self.DieAt then
				if cvBool("zfpv_blast_on_lost", false) then
					self:Explode()
				else
					self:Remove()
				end
				return
			end
		end

		self:NextThink(CurTime())
		return true
	end

	function ENT:Explode()
		if self.Exploded then return end
		self.Exploded = true

		local pos = self:GetPos()
		local ply = self:GetController()

		-- пилоту: «нет сигнала»
		if IsValid(ply) and ply:GetNWEntity("ZFPVDrone") == self then
			pcall(function()
				local dur = cv("zfpv_freeze_time", 2.5)
				if dur > 0 then
					net.Start("ZFPV_SignalLost")
					net.WriteFloat(dur)
					net.Send(ply)
				end

				ply:SetNWEntity("ZFPVDrone", NULL)
				if ply.SetViewEntity then ply:SetViewEntity(ply) end
				ply.ZFPVInput = nil
			end)
		end

		if self.EngineSound then
			pcall(function() self.EngineSound:Stop() end)
		end

		if cvBool("zfpv_zc_explosion", true) then
			zcBlast(IsValid(ply) and ply or self, pos)
		else
			-- классический движковый взрыв (как в оригинале)
			local exp = ents.Create("env_explosion")
			if IsValid(exp) then
				exp:SetPos(pos)
				if IsValid(ply) then exp:SetOwner(ply) end
				exp:SetKeyValue("iMagnitude", tostring(math.floor(cv("zfpv_damage", 250))))
				exp:SetKeyValue("iRadiusOverride", tostring(math.floor(cv("zfpv_radius", 300))))
				exp:Spawn()
				exp:Fire("Explode", "", 0)
				SafeRemoveEntityDelayed(exp, 2)
			end
		end

		self:Remove()
	end

	function ENT:OnRemove()
		if self.EngineSound then self.EngineSound:Stop() end

		local ply = self:GetController()
		if IsValid(ply) then
			ply.ZFPVNextLaunch = CurTime() + cv("zfpv_cooldown", 1)
		end
		if IsValid(ply) and ply:GetNWEntity("ZFPVDrone") == self then
			ply:SetNWEntity("ZFPVDrone", NULL)
			if ply.SetViewEntity then ply:SetViewEntity(ply) end
			ply.ZFPVInput = nil
		end
	end
end

if CLIENT then
	local glow = Material("sprites/light_glow02_add")

	-- винты: 4 размытых «лопасти», крутятся в Draw
	local plateModel = "models/hunter/plates/plate1x1.mdl"
	local blurMat = "models/airboat/airboat_blur02"
	local rotorOffsets = {
		Vector(11, -8, 2),
		Vector(11, 9, 2),
		Vector(-9, -8, 2),
		Vector(-9, 9, 2),
	}

	local rotorCache = {}
	local spin = 0

	local function getRotors(ent)
		local cached = rotorCache[ent]
		if cached and IsValid(cached[1]) then return cached end

		local list = {}
		for i = 1, #rotorOffsets do
			local m = ClientsideModel(plateModel, RENDER_GROUP_VIEW_MODEL_OPAQUE)
			if IsValid(m) then
				m:SetNoDraw(true)
				m:SetMaterial(blurMat)
			end
			list[i] = m
		end

		rotorCache[ent] = list
		return list
	end

	function ENT:OnRemove()
		if not CLIENT then return end
		for _, m in pairs(rotorCache[self] or {}) do
			if IsValid(m) then m:Remove() end
		end
		rotorCache[self] = nil
	end

	function ENT:Draw()
		if LocalPlayer():GetNWEntity("ZFPVDrone") == self then return end

		self:DrawModel()

		-- винты
		if file.Exists(plateModel, "GAME") then
			spin = spin + FrameTime() * 2200
			local mat = Matrix()
			mat:Scale(Vector(0.33, 0.33, 0.33))

			for i, off in ipairs(rotorOffsets) do
				local m = getRotors(self)[i]
				if IsValid(m) then
					local ang = self:GetAngles()
					ang:RotateAroundAxis(ang:Up(), spin)

					m:SetPos(self:LocalToWorld(off))
					m:SetAngles(ang)
					m:EnableMatrix("RenderMultiply", mat)
					m:DrawModel()
					m:DisableMatrix("RenderMultiply")
				end
			end
		end

		-- красный маячок
		local blink = (math.floor(CurTime() * 3) % 2 == 0) and 255 or 60
		render.SetMaterial(glow)
		render.DrawSprite(self:GetPos() + Vector(0, 0, 12), 14, 14, Color(255, 30, 30, blink))
	end
end
