--[[ Z-City FPV Drone — пробный взрыв (zfpv_test) ]]

if not SERVER then return end

-- Проверка, что взрыв вообще работает: делает взрыв в точку прицела, без дрона.
concommand.Add("zfpv_test", function(ply)
	if not IsValid(ply) then
		print("[FPV-ZC] zfpv_test можно только из игры")
		return
	end

	if not isfunction(ZFPVBlast) then
		ply:ChatPrint("[FPV-ZC] ZFPVBlast не найден — сущность дрона не загрузилась.")
		return
	end

	local tr = ply:GetEyeTrace()
	local pos = tr.Hit and tr.HitPos or (ply:EyePos() + ply:GetAimVector() * 200)

	ZFPVBlast(ply, pos)
	ply:ChatPrint("[FPV-ZC] тестовый взрыв. Если есть звук/дым/урон — система взрыва работает.")
end)

concommand.Add("zfpv_status", function(ply)
	local ent = scripted_ents.Get("zcity_fpv_drone")
	local wep = weapons and weapons.Get and weapons.Get("weapon_zcity_fpv_controller")
	local msg = string.format(
		"[FPV-ZC] сущность: %s | пульт: %s | Z-City: %s | радиус: %.1f м | осколков: %d",
		ent and "ок" or "НЕТ",
		wep and "ок" or "НЕТ",
		tostring(hg ~= nil and zb ~= nil),
		(GetConVar("zfpv_blast_radius") and GetConVar("zfpv_blast_radius"):GetFloat()) or 8,
		(math.floor((GetConVar("zfpv_blast_frag") and GetConVar("zfpv_blast_frag"):GetFloat()) or 600))
	)
	print(msg)
	if IsValid(ply) then ply:ChatPrint(msg) end
end)
