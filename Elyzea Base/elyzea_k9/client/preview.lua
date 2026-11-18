-- =====================================================================
--  ELYZEA K9 - CLIENT : aperçu réel de la race (choix du chien)
--  Le modèle est créé localement (visible par toi seul) devant une caméra.
-- =====================================================================
local P = { ped = nil, cam = nil, model = nil, token = 0 }

function C.StopPreview()
    P.token = P.token + 1
    if P.ped and DoesEntityExist(P.ped) then DeleteEntity(P.ped) end
    P.ped, P.model = nil, nil
    if P.cam then
        RenderScriptCams(false, true, 400, true, false)
        DestroyCam(P.cam, false)
        P.cam = nil
    end
end

function C.Preview(model)
    if type(model) ~= 'string' or model == P.model then return end
    P.token = P.token + 1
    local token = P.token
    if P.ped and DoesEntityExist(P.ped) then DeleteEntity(P.ped) P.ped = nil end
    P.model = model
    CreateThread(function()
        local hash = C.LoadModel(model, 5000)
        if token ~= P.token then return end
        if not hash then C.Send('previewMissing', { model = model }) return end
        local me = PlayerPedId()
        local base = GetOffsetFromEntityInWorldCoords(me, 0.0, 2.6, 0.0)
        local z = C.Ground(base.x, base.y, base.z) or (GetEntityCoords(me).z - 1.0)
        local ped = CreatePed(28, hash, base.x, base.y, z, GetEntityHeading(me) + 150.0, false, false)
        SetModelAsNoLongerNeeded(hash)
        if token ~= P.token then DeleteEntity(ped) return end
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityCollision(ped, false, false)
        P.ped = ped
        C.Pose(ped, 'sit', -1, true)
        if not P.cam then
            P.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            local cp = GetOffsetFromEntityInWorldCoords(me, 0.9, 0.3, 0.55)
            SetCamCoord(P.cam, cp.x, cp.y, cp.z)
            PointCamAtCoord(P.cam, base.x, base.y, z + 0.35)
            SetCamFov(P.cam, 42.0)
            RenderScriptCams(true, true, 500, true, false)
        end
    end)
end

function C.PreviewRotate(deg)
    if P.ped and DoesEntityExist(P.ped) then SetEntityHeading(P.ped, (GetEntityHeading(P.ped) + deg) % 360.0) end
end
