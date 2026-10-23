AddCSLuaFile()

SWEP.PrintName    = "FPV пульт"
SWEP.Author       = "You"
SWEP.Category     = "Z-City FPV"
SWEP.Instructions = "ЛКМ — запустить дрон.\nВ полёте: мышь — курс, WASD — движение, Пробел/Ctrl — вверх/вниз, Shift — ускорение, ЛКМ — взорвать, R — вернуть."
SWEP.Spawnable    = true
SWEP.AdminOnly    = false

SWEP.ViewModel    = "models/weapons/c_slam.mdl"
SWEP.WorldModel   = "models/weapons/w_slam.mdl"
SWEP.UseHands     = true
SWEP.ViewModelFOV = 60

SWEP.IconOverride = "materials/entities/weapon_zcity_fpv_controller.png" -- иконка в Q-меню

SWEP.Slot         = 4
SWEP.SlotPos      = 1
SWEP.DrawAmmo     = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = false
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

function SWEP:Initialize()
    self:SetHoldType("slam")
end

function SWEP:Deploy()
    return true
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end

-- Запуск дрона. Взрыв и возврат обрабатываются в autorun/zfpv_drone.lua
function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1)
    if CLIENT then return end

    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    if IsValid(ply:GetNWEntity("ZFPVDrone")) then return end -- уже летит

    local adminOnly = GetConVar("zfpv_admin_only")
    if adminOnly and adminOnly:GetBool() and not ply:IsAdmin() then
        ply:ChatPrint("[FPV-ZC] Пульт доступен только администраторам.")
        return
    end

    local wait = (ply.ZFPVNextLaunch or 0) - CurTime()
    if wait > 0 then
        ply:ChatPrint(string.format("[FPV-ZC] Дрон перезаряжается: ещё %.1f сек.", wait))
        return
    end

    local eye = ply:EyePos()
    local aim = ply:GetAimVector()

    -- Не спавним дрон внутри стены
    local tr = util.TraceLine({ start = eye, endpos = eye + aim * 70, filter = ply })
    local pos = tr.Hit and (tr.HitPos - aim * 20) or tr.HitPos

    local drone = ents.Create("zcity_fpv_drone")
    if not IsValid(drone) then return end

    drone:SetPos(pos)
    drone:SetAngles(ply:EyeAngles())
    drone:Spawn()
    drone:SetController(ply)

    ply.ZFPVCanDet = false -- чтобы тот же клик не взорвал дрон сразу
    ply.ZFPVInput  = { f = 0, s = 0, u = 0, boost = false, ang = ply:EyeAngles() }

    ply:SetNWEntity("ZFPVDrone", drone)
    ply:SetViewEntity(drone) -- сервер подгружает окружение вокруг дрона

    ply:EmitSound("buttons/button9.wav", 60)
end
