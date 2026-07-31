local WINDOW_SECONDS = 60
local windowsById = {}

local function nowSeconds()
    if type(os.epoch) == "function" then
        return os.epoch("utc") / 1000
    end
    return os.clock()
end

local function trimWindow(samples, now)
    local cutoff = now - WINDOW_SECONDS
    while #samples > 1 and samples[1].t < cutoff do
        table.remove(samples, 1)
    end
end

local function computeAverage(samples)
    local sum = 0
    for i = 1, #samples do
        sum = sum + samples[i].count
    end
    return sum / #samples
end

local averager = {}

function averager.average(count, id)
    if type(count) ~= "number" then
        return nil, "count must be a number"
    end

    if id == nil then
        return nil, "id is required"
    end

    local key = tostring(id)
    local window = windowsById[key]
    if not window then
        window = { samples = {} }
        windowsById[key] = window
    end

    local t = nowSeconds()
    local samples = window.samples

    samples[#samples + 1] = {
        t = t,
        count = count,
    }

    trimWindow(samples, t)
    return computeAverage(samples)
end

return averager
