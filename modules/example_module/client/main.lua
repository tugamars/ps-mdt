RegisterModuleNUICallback('example_module', 'getRandomNumbers', function()
    local numbers = {}
    for index = 1, 6 do
        numbers[#numbers + 1] = {
            index = index,
            value = math.random(1, 1000),
        }
    end

    return {
        generatedAt = GetGameTimer(),
        numbers = numbers,
    }
end)
