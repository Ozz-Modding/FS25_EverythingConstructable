ECSiteSound = {}
ECSiteSound.modDir = g_currentModDirectory
ECSiteSound.sources = nil
ECSiteSound.lastPlayTime = 0
ECSiteSound.lastPlayedIndex = 0
ECSiteSound.lastPlayedSample = nil

function ECSiteSound.load()
    if ECSiteSound.sources ~= nil then
        return
    end

    ECSiteSound.sources = {}
    local dir = ECSiteSound.modDir .. ECConfig.EASTER_EGG_SOUND_DIR
    local files = Files.new(dir)

    for _, file in ipairs(files.files) do
        if file.filename:find("%.ogg$") then
            local audioSource = createAudioSource("ec_ee_" .. file.filename, dir .. file.filename, 30, 5, 1.0, 1)
            link(getRootNode(), audioSource)
            table.insert(ECSiteSound.sources, {
                node = audioSource,
                sample = getAudioSourceSample(audioSource),
            })
        end
    end
end

function ECSiteSound.stopAll()
    if ECSiteSound.sources == nil then
        return
    end
    for _, source in ipairs(ECSiteSound.sources) do
        stopSample(source.sample, 0, 0)
    end
end

function ECSiteSound.deleteAll()
    if ECSiteSound.sources == nil then
        return
    end
    for _, source in ipairs(ECSiteSound.sources) do
        stopSample(source.sample, 0, 0)
        if entityExists(source.node) then
            delete(source.node)
        end
    end
    ECSiteSound.sources = nil
    ECSiteSound.lastPlayedSample = nil
    ECSiteSound.lastPlayedIndex = 0
end

function ECSiteSound.tryPlay()
    local now = g_time
    if now - ECSiteSound.lastPlayTime < ECConfig.EASTER_EGG_COOLDOWN then
        return
    end

    if math.random() > ECConfig.EASTER_EGG_CHANCE then
        return
    end

    ECSiteSound.load()

    local sources = ECSiteSound.sources
    if sources == nil or #sources == 0 then
        return
    end

    local index
    if #sources > 1 then
        repeat
            index = math.random(1, #sources)
        until index ~= ECSiteSound.lastPlayedIndex
    else
        index = 1
    end
    ECSiteSound.lastPlayedIndex = index

    local source = sources[index]
    local px, py, pz = getWorldTranslation(g_localPlayer.rootNode)

    setWorldTranslation(source.node, px, py + 1, pz)
    playSample(source.sample, 1, 1.0, 0, 0, 0)

    ECSiteSound.lastPlayedSample = source.sample
    ECSiteSound.lastPlayTime = now
end
