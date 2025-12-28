-- Generated from PokeAPI + PokeLua; Emerald US/EU adapter
GAME_ID = "emerald_us_eu"

local enemyAddr = 0x2024744
local wildTypeAddr = 0x20240FD  -- Battle type flag: 0 = not in battle, 1 = wild, 2+ = trainer

local natureNamesList = {
  "Hardy",
  "Lonely",
  "Brave",
  "Adamant",
  "Naughty",
  "Bold",
  "Docile",
  "Relaxed",
  "Impish",
  "Lax",
  "Timid",
  "Hasty",
  "Serious",
  "Jolly",
  "Naive",
  "Modest",
  "Mild",
  "Quiet",
  "Bashful",
  "Rash",
  "Calm",
  "Gentle",
  "Sassy",
  "Careful",
  "Quirky"
}

local HPTypeNamesList = {
  "Fighting",
  "Flying",
  "Poison",
  "Ground",
  "Rock",
  "Bug",
  "Ghost",
  "Steel",
  "Fire",
  "Water",
  "Grass",
  "Electric",
  "Psychic",
  "Ice",
  "Dragon",
  "Dark"
}

local nationalDexList = {
  1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 
  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 
  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 
  64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 
  80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 
  96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 
  112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 
  128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 
  144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 
  160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 
  176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 
  192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 
  208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 
  224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 
  240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 387, 388, 389, 390, 
  391, 392, 393, 394, 395, 396, 397, 398, 399, 400, 401, 402, 403, 404, 405, 406, 
  407, 408, 409, 410, 411, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 
  263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 290, 291, 292, 
  276, 277, 285, 286, 327, 278, 279, 283, 284, 320, 321, 300, 301, 352, 343, 344, 
  299, 324, 302, 339, 340, 370, 341, 342, 349, 350, 318, 319, 328, 329, 330, 296, 
  297, 309, 310, 322, 323, 363, 364, 365, 331, 332, 361, 362, 337, 338, 298, 325, 
  326, 311, 312, 303, 307, 308, 333, 334, 360, 355, 356, 315, 287, 288, 289, 316, 
  317, 357, 293, 294, 295, 366, 367, 368, 359, 353, 354, 336, 335, 369, 304, 305, 
  306, 351, 313, 314, 345, 346, 347, 348, 280, 281, 282, 371, 372, 373, 374, 375, 
  376, 377, 378, 379, 382, 383, 384, 380, 381, 385, 386, 358
}

local genderRatioList = {
  31, 31, 31, 31, 31, 31, 31, 31, 31, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 254, 254, 254, 255, 
  255, 255, 191, 191, 191, 191, 191, 191, 127, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 63, 63, 127, 127, 127, 63, 63, 
  63, 63, 63, 63, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  0, 0, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 0, 0, 127, 127, 127, 127, 255, 255, 127, 127, 127, 127, 127, 
  254, 127, 254, 127, 127, 127, 127, 0, 0, 127, 127, 254, 63, 63, 127, 255, 
  127, 127, 127, 0, 31, 31, 31, 31, 0, 31, 31, 31, 31, 31, 31, 0, 
  0, 0, 127, 127, 127, 0, 0, 31, 31, 31, 31, 31, 31, 31, 31, 31, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 191, 191, 31, 31, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 31, 31, 127, 127, 127, 0, 127, 127, 127, 127, 127, 127, 127, 
  191, 191, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 191, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 0, 127, 127, 255, 255, 254, 63, 63, 
  254, 254, 0, 0, 0, 127, 127, 127, 0, 0, 0, 31, 31, 31, 31, 31, 
  31, 31, 31, 31, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 0, 127, 127, 127, 63, 63, 191, 127, 191, 191, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 255, 254, 127, 127, 127, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  0, 0, 127, 127, 127, 127, 0, 0, 31, 31, 31, 31, 127, 127, 127, 127, 
  127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 127, 
  31, 191, 127, 127, 127, 0, 0, 0, 0, 0, 0, 254, 255, 0, 0, 0, 
  0, 0
}

local function getOffset(offsetType, orderIndex)
  local offsets = {
    ["growth"] = {0,0,0,0,0,0, 1,1,2,3,2,3, 1,1,2,3,2,3, 1,1,2,3,2,3},
    ["attack"] = {1,1,2,3,2,3, 0,0,0,0,0,0, 2,3,1,1,3,2, 2,3,1,1,3,2},
    ["misc"]   = {3,2,3,2,1,1, 3,2,3,2,1,1, 3,2,3,2,1,1, 0,0,0,0,0,0}
  }
  return offsets[offsetType][orderIndex] * 12
end

local function getIVs(ivsValue)
  -- Use // for integer division (Lua 5.3+) or bit shift
  local hpIV = ivsValue & 0x1F
  local atkIV = (ivsValue >> 5) & 0x1F
  local defIV = (ivsValue >> 10) & 0x1F
  local spdIV = (ivsValue >> 15) & 0x1F
  local spAtkIV = (ivsValue >> 20) & 0x1F
  local spDefIV = (ivsValue >> 25) & 0x1F
  return hpIV, atkIV, defIV, spAtkIV, spDefIV, spdIV
end

local function getHPTypeAndPower(hpIV, atkIV, defIV, spAtkIV, spDefIV, spdIV)
  local hpType = (((hpIV & 1) + (2 * (atkIV & 1)) + (4 * (defIV & 1)) + (8 * (spdIV & 1)) + (16 * (spAtkIV & 1)) + (32 * (spDefIV & 1))) * 15) // 63
  local hpPower = (((((hpIV >> 1) & 1) + (2 * ((atkIV >> 1) & 1)) + (4 * ((defIV >> 1) & 1)) + (8 * ((spdIV >> 1) & 1)) + (16 * ((spAtkIV >> 1) & 1)) + (32 * ((spDefIV >> 1) & 1))) * 40) // 63) + 30
  return hpType, hpPower
end

local function shinyCheck(PID, addr)
  local pokemonIDs = emu:read32(addr + 0x4)
  local TID = pokemonIDs & 0xFFFF
  local SID = pokemonIDs >> 16
  local lowPID = PID & 0xFFFF
  local highPID = PID >> 16
  local shinyTypeValue = (SID ~ TID) ~ (lowPID ~ highPID)
  if shinyTypeValue < 8 then
    return shinyTypeValue == 0 and "square" or "star"
  end
  return ""
end

local function getGender(pokemonPID, speciesDexNumber)
  local ratio = genderRatioList[speciesDexNumber] or 127
  if ratio == 255 then return "genderless"
  elseif ratio == 254 then return "female"
  elseif ratio == 0 then return "male"
  else
    return (pokemonPID & 0xFF) < ratio and "female" or "male"
  end
end

function readWildPokemon()
  -- First check if we're actually in a battle
  local battleType = emu:read8(wildTypeAddr)
  if battleType == 0 then return nil end  -- Not in battle, return nil

  local pokemonPID = emu:read32(enemyAddr)
  if pokemonPID == 0 then return nil end
  local pokemonIDs = emu:read32(enemyAddr + 0x4)
  local orderIndex = (pokemonPID % 24) + 1
  local decryptionKey = pokemonPID ~ pokemonIDs
  local growthOffset = getOffset("growth", orderIndex)
  local attacksOffset = getOffset("attack", orderIndex)
  local miscOffset = getOffset("misc", orderIndex)
  local ivsAndAbilityValue = emu:read32(enemyAddr + 0x20 + miscOffset + 0x4) ~ decryptionKey
  local speciesAndItemValue = emu:read32(enemyAddr + 0x20 + growthOffset) ~ decryptionKey
  local experienceValue = emu:read32(enemyAddr + 0x20 + growthOffset + 0x4) ~ decryptionKey
  local speciesDexIndex = speciesAndItemValue & 0xFFFF
  local speciesDexNumber = nationalDexList[speciesDexIndex + 1]
  if speciesDexNumber == nil then return nil end
  local natureIndex = pokemonPID % 25
  local abilitySlot = (ivsAndAbilityValue >> 31)
  local hpIV, atkIV, defIV, spAtkIV, spDefIV, spdIV = getIVs(ivsAndAbilityValue)
  local hpType, hpPower = getHPTypeAndPower(hpIV, atkIV, defIV, spAtkIV, spDefIV, spdIV)
  local shinyType = shinyCheck(pokemonPID, enemyAddr)
  return {
    type = "wild",
    game = GAME_ID,
    pid = pokemonPID,
    species_id = speciesDexNumber,
    species_index = speciesDexIndex,
    exp = experienceValue,
    nature = natureNamesList[natureIndex + 1],
    ability_slot = abilitySlot,
    gender = getGender(pokemonPID, speciesDexNumber),
    ivs = { hp = hpIV, atk = atkIV, def = defIV, spa = spAtkIV, spd = spDefIV, spe = spdIV },
    hp_type = HPTypeNamesList[hpType + 1],
    hp_power = hpPower,
    shiny = shinyType ~= "",
    shiny_type = shinyType,
  }
end
