local addonName, ns = ...

if addonName ~= "NomTools" then
	if _G then
		ns = _G.NomTools
	end
end

if not ns then
	return
end

local IsPlayerSpell = IsPlayerSpell
local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown
local UnitClass = UnitClass

local EMPTY_CONSUMABLE_LIST = {}

local function CopyConfiguredIDList(values)
	local copied = {}

	for _, value in ipairs(values or EMPTY_CONSUMABLE_LIST) do
		if type(value) == "number" then
			copied[#copied + 1] = value
		end
	end

	return copied
end

local function GetConsumableCatalogEntries(kind)
	local catalog = ns.CONSUMABLE_CATALOG
	if type(catalog) ~= "table" then
		return EMPTY_CONSUMABLE_LIST
	end

	local entries = catalog[kind]
	if type(entries) ~= "table" then
		return EMPTY_CONSUMABLE_LIST
	end

	return entries
end

local function BuildConfiguredConsumableEntries(kind)
	local entries = {}

	for _, definition in ipairs(GetConsumableCatalogEntries(kind)) do
		local entry = {
			key = definition.key,
			name = definition.label,
		}

		if type(definition.spellID) == "number" then
			entry.spellID = definition.spellID
		end

		if type(definition.weaponType) == "string" and definition.weaponType ~= "" then
			entry.weaponType = definition.weaponType
		end

		if type(definition.poisonCategory) == "string" and definition.poisonCategory ~= "" then
			entry.poisonCategory = definition.poisonCategory
		end

		entry.items = CopyConfiguredIDList(definition.itemIDs)
		entry.buffIDs = CopyConfiguredIDList(definition.buffIDs)
		entry.buffID = entry.buffIDs[1]

		entries[#entries + 1] = entry
	end

	return entries
end

local function BuildAuraIDList(entries, fallbackIDs)
	local spellIDs = {}
	local seen = {}

	local function AddSpellID(spellID)
		if type(spellID) == "number" and not seen[spellID] then
			seen[spellID] = true
			spellIDs[#spellIDs + 1] = spellID
		end
	end

	for _, entry in ipairs(entries or EMPTY_CONSUMABLE_LIST) do
		if type(entry.buffIDs) == "table" then
			for _, spellID in ipairs(entry.buffIDs) do
				AddSpellID(spellID)
			end
		elseif type(entry.buffID) == "number" then
			AddSpellID(entry.buffID)
		end
	end

	for _, spellID in ipairs(fallbackIDs or EMPTY_CONSUMABLE_LIST) do
		AddSpellID(spellID)
	end

	return spellIDs
end

local function BuildPoisonBuffIDMap(entries)
	local spellIDsByCategory = {
		lethal = {},
		non_lethal = {},
	}
	local seen = {
		lethal = {},
		non_lethal = {},
	}

	for _, entry in ipairs(entries or EMPTY_CONSUMABLE_LIST) do
		local category = entry.poisonCategory
		if category == "lethal" or category == "non_lethal" then
			local ids = entry.buffIDs
			if type(ids) ~= "table" or #ids == 0 then
				ids = { entry.spellID }
			end

			for _, spellID in ipairs(ids) do
				if type(spellID) == "number" and not seen[category][spellID] then
					seen[category][spellID] = true
					spellIDsByCategory[category][#spellIDsByCategory[category] + 1] = spellID
				end
			end
		end
	end

	return spellIDsByCategory
end

local function BuildChoices(entries, autoLabel)
	local choices = {
		{
			key = "auto",
			name = autoLabel,
		},
		{
			key = "none",
			name = "None",
		},
	}

	for _, entry in ipairs(entries) do
		choices[#choices + 1] = {
			key = entry.key,
			name = entry.name,
		}
	end

	return choices
end

local function RebuildConsumableCatalog()
	local sharedBuffIDs = ns.CONSUMABLE_CATALOG and ns.CONSUMABLE_CATALOG.sharedBuffIDs or nil

	ns.FLASKS = BuildConfiguredConsumableEntries("flask")
	ns.FOODS = BuildConfiguredConsumableEntries("food")
	ns.WEAPON_BUFFS = BuildConfiguredConsumableEntries("weapon")
	ns.ROGUE_POISONS = BuildConfiguredConsumableEntries("poisons")
	ns.RUNES = BuildConfiguredConsumableEntries("rune")

	ns.FLASK_BUFF_IDS = BuildAuraIDList(ns.FLASKS, sharedBuffIDs and sharedBuffIDs.flask)
	ns.FOOD_BUFF_IDS = BuildAuraIDList(ns.FOODS, sharedBuffIDs and sharedBuffIDs.food)
	ns.RUNE_BUFF_IDS = BuildAuraIDList(ns.RUNES, sharedBuffIDs and sharedBuffIDs.rune)
	ns.ROGUE_POISON_BUFF_IDS = BuildPoisonBuffIDMap(ns.ROGUE_POISONS)

	ns.ENTRY_SETS = {
		flask = ns.FLASKS,
		food = ns.FOODS,
		weapon = ns.WEAPON_BUFFS,
		poisons = ns.ROGUE_POISONS,
		rune = ns.RUNES,
	}

	ns.CHOICES = {
		flask = BuildChoices(ns.FLASKS, "First Available"),
		food = BuildChoices(ns.FOODS, "First Available"),
		weapon = BuildChoices(ns.WEAPON_BUFFS, "First Compatible"),
		poisons = BuildChoices(ns.ROGUE_POISONS, "First Known"),
		rune = BuildChoices(ns.RUNES, "First Available"),
	}
end

ns.RebuildConsumableCatalog = RebuildConsumableCatalog
RebuildConsumableCatalog()

local function IsRoguePoisonMode()
	local _, classFile = UnitClass and UnitClass("player")
	return classFile == "ROGUE"
end

local function IsSpellChoiceAvailable(spellID)
	if type(spellID) ~= "number" then
		return false
	end

	if IsSpellKnownOrOverridesKnown then
		return IsSpellKnownOrOverridesKnown(spellID)
	end

	if IsPlayerSpell then
		return IsPlayerSpell(spellID)
	end

	return false
end

function ns.GetChoices(kind)
	if kind == "weapon" then
		return ns.CHOICES.weapon or {}
	end

	if kind == "poisons" then
		return ns.CHOICES.poisons or {}
	end

	return ns.CHOICES[kind] or {}
end

function ns.GetChoiceEntries(kind)
	if kind == "weapon" then
		return ns.WEAPON_BUFFS
	end

	if kind == "poisons" then
		return ns.ROGUE_POISONS
	end

	return ns.ENTRY_SETS[kind] or {}
end

function ns.IsRoguePoisonMode()
	return IsRoguePoisonMode()
end

function ns.IsChoiceEntryAvailable(entry)
	if type(entry) ~= "table" then
		return false
	end

	if type(entry.spellID) == "number" then
		return IsSpellChoiceAvailable(entry.spellID)
	end

	return (ns.GetEntryItemCount and ns.GetEntryItemCount(entry) or 0) > 0
end

function ns.GetChoiceMenuBucketLabels(kind)
	if kind == "poisons" then
		return "Known", "Not Known"
	end

	return "In Bags", "Not in Bags"
end

function ns.GetChoiceEntry(kind, key)
	local entries = ns.GetChoiceEntries(kind)

	if key == "none" then
		return nil
	end

	if key and key ~= "auto" then
		for _, entry in ipairs(entries) do
			if entry.key == key then
				return entry
			end
		end
	end

	return entries[1]
end

function ns.GetChoiceLabel(kind, key)
	for _, choice in ipairs(ns.GetChoices(kind)) do
		if choice.key == key then
			return choice.name
		end
	end

	return "Unknown"
end