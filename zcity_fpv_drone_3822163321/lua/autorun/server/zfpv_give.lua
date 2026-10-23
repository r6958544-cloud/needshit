--[[ Z-City FPV Drone — выдача пульта (zfpv_give) ]]

if not SERVER then return end

util.AddNetworkString("ZFPV_GiveController")

local function hasAddon()
	return weapons ~= nil and weapons.Get ~= nil and weapons.Get("weapon_zcity_fpv_controller") ~= nil
end

local function canUse(ply)
	if not IsValid(ply) then return true end
	local adminOnly = GetConVar("zfpv_admin_only")
	if adminOnly and adminOnly:GetBool() then
		return ply:IsAdmin() or ply:IsSuperAdmin() or ply:IsListenServerHost()
	end
	return true
end

local function giveController(ply)
	if not IsValid(ply) then return end

	if not hasAddon() then
		ply:ChatPrint("[FPV-ZC] Пульт не зарегистрирован (ошибка загрузки аддона).")
		return
	end

	if not canUse(ply) then
		ply:ChatPrint("[FPV-ZC] Пульт только для админов (zfpv_admin_only 1).")
		return
	end

	if ply:HasWeapon("weapon_zcity_fpv_controller") then
		ply:SelectWeapon("weapon_zcity_fpv_controller")
		ply:ChatPrint("[FPV-ZC] Пульт уже есть — взял в руки.")
		return
	end

	ply:Give("weapon_zcity_fpv_controller")
	ply:SelectWeapon("weapon_zcity_fpv_controller")
	ply:ChatPrint("[FPV-ZC] Пульт выдан. ЛКМ — запуск дрона, ЛКМ в полёте — взрыв.")
end

concommand.Add("zfpv_give", function(ply)
	giveController(ply)
end)

net.Receive("ZFPV_GiveController", function(_, ply)
	giveController(ply)
end)
