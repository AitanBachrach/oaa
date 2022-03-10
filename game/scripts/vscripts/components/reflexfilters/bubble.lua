-- Component for handling the ModifierGained Filter used for spell effect blocking
-- from the Postactive 3c Reflex Item (Bubble Orb)

if not BubbleOrbFilter then
  DebugPrint("Creating filter for Preemptive 3c (Bubble Orb)")
  BubbleOrbFilter = class({})

  Debug.EnabledModules["reflexfilters:bubble"] = false
end

function BubbleOrbFilter:Init()
  self.moduleName = "Bubble Orb Filter"
  FilterManager:AddFilter(FilterManager.ModifierGained, self, Dynamic_Wrap(self, "ModifierGainedFilter"))
end

function BubbleOrbFilter:ModifierGainedFilter(keys)
  if not keys.entindex_parent_const or not keys.entindex_caster_const then
    return true
  end

  local caster = EntIndexToHScript(keys.entindex_caster_const)
  local parent = EntIndexToHScript(keys.entindex_parent_const)
  local bubbleModifierNameAlly = "modifier_item_preemptive_bubble_block"
  local casterIsAlly = caster:GetTeamNumber() == parent:GetTeamNumber()
  local parentHasBubbleModifier = parent:HasModifier(bubbleModifierNameAlly)
  local bubbleModifiers = parent:FindAllModifiersByName(bubbleModifierNameAlly)
  local casterIsInTheSameBubble = false

  local function IsUnitInSpecificBubble(unit, modifier)
    if not modifier or modifier:IsNull() or not unit or unit:IsNull() then
      return
    end
    local ability = modifier:GetAbility()
    if not ability or ability:IsNull() then
      return
    end
    local radius = ability:GetSpecialValueFor("radius")
    local center = modifier.bubbleCenter
    if not center then
      return
    end
    local enemiesInBubble = FindUnitsInRadius(
      unit:GetTeamNumber(),
      center,
      nil,
      radius,
      DOTA_UNIT_TARGET_TEAM_FRIENDLY,
      DOTA_UNIT_TARGET_ALL,
      bit.bor(DOTA_UNIT_TARGET_FLAG_INVULNERABLE, DOTA_UNIT_TARGET_FLAG_OUT_OF_WORLD),
      FIND_ANY_ORDER,
      false
    )

    return index(unit, enemiesInBubble)
  end

  --if parentHasBubbleModifier then
    --casterIsInBubbles = reduce(operator.land, true, map(partial(UnitIsInSpecificBubble, caster), iter(bubbleModifiers)))
  --end
  if parentHasBubbleModifier and not casterIsAlly then
    for _, bubbleModifier in pairs(bubbleModifiers) do
      if bubbleModifier and not bubbleModifier:IsNull() then
        if IsUnitInSpecificBubble(caster, bubbleModifier) then
          casterIsInTheSameBubble = true
          break
        end
      end
    end
  end

  if not parentHasBubbleModifier or casterIsAlly or casterIsInTheSameBubble then
    return true
  else
    if not parent or parent:IsNull() or not parent:IsRealHero() then
      return false
    end
    if parent.last_bubble_blocked_modifier ~= keys.name_const and parent.last_bubble_blocked_ability ~= keys.entindex_ability_const then
      -- Particle effect
      local blockEffectName = "particles/items_fx/immunity_sphere.vpcf"
      local blockEffect = ParticleManager:CreateParticle(blockEffectName, PATTACH_POINT_FOLLOW, parent)
      ParticleManager:ReleaseParticleIndex(blockEffect)
      -- Sound effect
      parent:EmitSound("DOTA_Item.LinkensSphere.Activate")
      -- Prevent looping particle and sound effects
      parent.last_bubble_blocked_modifier = keys.name_const -- important for constantly reapplying spells like Chronosphere
      parent.last_bubble_blocked_ability = keys.entindex_ability_const -- important for spells that apply multiple modifiers like Blinding Light
    end
    return false
  end
end
