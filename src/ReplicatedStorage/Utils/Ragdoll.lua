local module = {}

function module.RagdollCharacter(Character, Exclusions)
	Character.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    Character.Humanoid.RequiresNeck = false
    Character.Humanoid:UnequipTools()

    for _, Joint in Character:GetDescendants() do
        if not Joint:IsA("Motor6D") then continue end

        if Exclusions ~= nil then
            local Continue = false
            for _, Exclude in Exclusions do
                if Joint:IsDescendantOf(Exclude) then
                    Continue = true
                end
            end

            if Continue == true then continue end
        end

        local socket = Instance.new("BallSocketConstraint")
        local a1 = Instance.new("Attachment")
        local a2 = Instance.new("Attachment")
        socket.UpperAngle = 20
        socket.Name = "RAGDOLL"
        a1.Name = "RAGDOLL"
        a2.Name = "RAGDOLL"

        a1.Parent = Joint.Part0
        a2.Parent = Joint.Part1
        socket.Parent = Joint.Parent
        socket.Attachment0 = a1
        socket.Attachment1 = a2
        a1.CFrame = Joint.C0
        a2.CFrame = Joint.C1
        socket.LimitsEnabled = true
        socket.TwistLimitsEnabled = true

        Joint.Enabled = false
    end
end

function module.UnragdollCharacter(Character)
    Character.Humanoid:UnequipTools()

    for _, Joint in Character:GetDescendants() do
        if Joint:IsA("Motor6D") then
            Joint.Enabled = true
        elseif Joint.Name == "RAGDOLL" then
            Joint:Destroy()
        end
    end

    Character.Humanoid.RequiresNeck = true
end

return module