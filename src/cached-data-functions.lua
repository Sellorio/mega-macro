local Cache = {
    EqippableItem = {},
    EqippedItem = {},
    SpellInfo = {},
    ItemInfoInstant = {},
    ToyInfo = {},
    ItemSpell = {},
    SpellCharges = {}
}

-- load func may return a second value to state whether or not the value should be cached
local function GetOrLoadValue(cacheList, key, loadFunc)
    local data = cacheList[key]
    if data == nil then
        data = loadFunc(key)
        cacheList[key] = data
    end
    return unpack(data)
end

local function GetOrLoadTemporaryValue(cacheList, key, loadFunc)
    local cacheItem = cacheList[key]
    if cacheItem == nil or cacheItem.CachedAt + cacheItem.CacheDuration < MegaMacroSystemTime then
        local data, cacheDuration = loadFunc(key)
        cacheItem = { Data = data, CacheDuration = cacheDuration, CachedAt = MegaMacroSystemTime }
        cacheList[key] = cacheItem
    end
    return unpack(cacheItem.Data)
end

MM = {}

function MM.IsEquippableItem(itemId)
    return GetOrLoadValue(Cache.EqippableItem, itemId, function(key)
        return { not not IsEquippedItem(key) }
    end)
end

function MM.GetSpellInfo(spellNameOrId)
    return GetOrLoadValue(Cache.SpellInfo, spellNameOrId, function(key)
        return { GetSpellInfo(key) }
    end)
end

function MM.GetItemInfoInstant(itemNameOrId)
    return GetOrLoadTemporaryValue(Cache.ItemInfoInstant, itemNameOrId, function(key)
        local id, type, subType, equipLoc, icon, classId, subClassId = GetItemInfoInstant(key)
        return
            { id, type, subType, equipLoc, icon, classId, subClassId },
            id and 999999 or 0.1
    end)
end

function MM.IsEquippedItem(itemId)
    return GetOrLoadTemporaryValue(Cache.EqippedItem, itemId, function(key)
        return { not not IsEquippedItem(key) }, 0.1
    end)
end

function MM.GetToyInfo(itemId)
    return GetOrLoadValue(Cache.ToyInfo, itemId, function(key)
        return { C_ToyBox.GetToyInfo(key) }
    end)
end

function MM.GetItemSpell(itemId)
    return GetOrLoadValue(Cache.ItemSpell, itemId, function(key)
        return { GetItemSpell(key) }
    end)
end

function MM.GetSpellCharges(spellId)
    -- will only cache charge info when the spell doesn't use charges
    return GetOrLoadTemporaryValue(Cache.SpellCharges, spellId, function(key)
        local charges, maxCharges, chargeStart, chargeDuration, chargeModRate = GetSpellCharges(key)
        return
            { charges, maxCharges, chargeStart, chargeDuration, chargeModRate },
            maxCharges and 0 or 999999
    end)
end

function MM.ResetCacheForSpells()
    Cache.SpellInfo = {}
    Cache.SpellCharges = {}
end