function ShowToolTipForMegaMacro(macroId)
	GameTooltip:Hide()
	GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)

	local abilityName = MegaMacroIconEvaluator.GetSpellFromCache(macroId)

	if abilityName then
		local spellId = select(7, GetSpellInfo(abilityName))
		if spellId then
			GameTooltip:SetSpellByID(spellId)
			GameTooltip:Show()
			return
		end

		local itemId = GetItemInfoInstant(abilityName)

		if itemId then
			if C_ToyBox.GetToyInfo(itemId) then
				GameTooltip:SetToyByItemID(itemId)
				GameTooltip:Show()
			else
				GameTooltip:SetItemByID(itemId)
				GameTooltip:Show()
			end
		end
	end
end