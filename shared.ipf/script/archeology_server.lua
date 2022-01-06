-- archeology_server.lua

-- 고고학 임무 받기
function SCR_ACCEPT_ARCHEOLOGY_MISSION(pc, mat_guid, arg_list)    
    if IsRunningScript(pc, 'TX_ACCEPT_ARCHEOLOGY_MISSION') == 1 then
        return
    end
    
    if pc == nil or mat_guid == nil or arg_list == nil or #arg_list < 1 then
		return
    end

    local lv = tonumber(arg_list[1])    
    local map_list = shared_archeology.get_archeology_map_list()
    if map_list == nil then
        return
    end

    local acc = GetAccountObj(pc)
    if acc == nil then
        return
    end

    local next_time = TryGetProp(acc, 'archeology_next_reset_time', 'None')
    if next_time ~= 'None' then
        local now = date_time.get_lua_now_datetime_str()
        if date_time.is_later_than(next_time, now) == true then
            SendSysMsg(pc, 'CantAcceptArcheologyMission{time}', 0, 'time', next_time)
            return
        end
    end

    local mat_item = GetInvItemByGuid(pc, mat_guid)
    if mat_item == nil then
        return
    end

    local cost_item, cost_count = shared_archeology.get_cost(lv)

    if cost_item == nil then
        return
    end

    if cost_item ~= TryGetProp(mat_item, 'ClassName', 'None') then
        return
    end

    local now_count = GetInvItemCount(pc, cost_item)
    if now_count < cost_count then
        local cls = GetClass('Item', cost_item)
        SendSysMsg(pc, 'Require{item}{count}', 0, 'item', cls.Name, 'count', cost_count)
        return
    end

    if IsFixedItem(mat_item) == 1 then
        SendSysMsg(pc, 'CannotBecauseLockedItem')
        return
    end

    RunScript('TX_ACCEPT_ARCHEOLOGY_MISSION', pc, mat_guid, lv)
end
function TX_ACCEPT_ARCHEOLOGY_MISSION(pc, mat_guid, lv)
    local acc = GetAccountObj(pc)
    local now = date_time.get_lua_now_datetime_str()
    local next_time = date_time.add_time(now, 600)  -- 10분의 재사용 대기 시간

    local map_list = shared_archeology.get_archeology_map_list()
    map_list = shuffle(map_list)
    
    local cost_item, cost_count = shared_archeology.get_cost(lv)
    local mat_item = GetInvItemByGuid(pc, mat_guid)    
    if cost_item ~= TryGetProp(mat_item, 'ClassName', 'None') then        
        return
    end
    
    if IsFixedItem(mat_item) == 1 then
        return
    end

    local tx = TxBegin(pc)
    TxSetIESProp(tx, acc, 'archeology_next_reset_time', next_time)
    TxSetIESProp(tx, acc, 'archeology_try_count', 0)
    TxSetIESProp(tx, acc, 'archeology_lv', lv)

    -- mongo log
    local log_list = {}
    table.insert(log_list, 'Type')
    table.insert(log_list, 'AcceptMission')
    table.insert(log_list, 'MissionLevel')
    table.insert(log_list, tostring(lv))
    table.insert(log_list, 'TakeItemName')
    table.insert(log_list, cost_item)
    table.insert(log_list, 'TakeItemCount')
    table.insert(log_list, tostring(cost_count))    

    TxTakeItemByObject(tx, mat_item, cost_count, 'TX_ACCEPT_ARCHEOLOGY_MISSION')
    for i = 1, max_archeology_point do
        TxSetIESProp(tx, acc, 'archeology_map_' .. i, map_list[i]) -- 맵 정보 세팅
        TxSetIESProp(tx, acc, 'archeology_map_' .. i .. '_complete', 0) -- 완료 정보 리셋

        table.insert(log_list, 'MissionMap_' .. i)
        table.insert(log_list, map_list[i])
    end

    -- 위치정보 리셋
    for i = 1, max_archeology_map_count do
        for j = 1, max_archeology_point do
            TxSetIESProp(tx, acc, 'archeology_map_' .. i .. '_pos_' .. j , 'None')
        end
    end
    
    local ret = TxCommit(tx)    
    if ret == 'SUCCESS' then
        SendSysMsg(pc, 'AcceptArcheologyMission')
        CustomMongoLog_WithList(pc, 'ArcheologyMission', log_list)
    end
end

-- 조사 수행
function SCR_SURVEY_ARCHEOLOGY(pc)    
    if IsRunningScript(pc, 'TX_SURVEY_ARCHEOLOGY') == 1 then
        return
    end

    RunScript('TX_SURVEY_ARCHEOLOGY', pc)
end

function TX_SURVEY_ARCHEOLOGY(pc)
    sleep(1500)
    local acc = GetAccountObj(pc)
    if acc == nil then
        return
    end

    local now_count = TryGetProp(acc, 'archeology_try_count', 0)
    if now_count >= 50 then
        SendSysMsg(pc, 'CantSurveyArcheologyCuzManyFail')
        return
    end

    local zone = GetZoneName(pc)    
    local archeology_map_property = 'None'
    for i = 1, max_archeology_map_count do
        local map_name = TryGetProp(acc, 'archeology_map_' .. i, 'None')
        if map_name == zone then
            archeology_map_property = 'archeology_map_' .. i
            break
        end
    end

    if archeology_map_property == 'None' then
        SendSysMsg(pc, 'CantFindArcheologyRelic')
        return
    end

    local all_clear = 0
    for i = 1, max_archeology_map_count do 
        if TryGetProp(acc, 'archeology_map_' .. i .. '_complete', 0) == 1 then
            all_clear = all_clear + 1
        end
    end

    if all_clear == max_archeology_map_count then
        SendSysMsg(pc, 'AllAreaRelicFindedInThisArea')
        return
    end

    if TryGetProp(acc, archeology_map_property .. '_complete', 0) == 1 then
        SendSysMsg(pc, 'AllRelicFindedInThisArea')
        return 
    end
    local pos_property = 'None'
    for i = 1, max_archeology_point do
        pos_property = archeology_map_property .. '_pos_' .. i
        local pos = TryGetProp(acc, pos_property, 'None')
        if pos == 'None' then
            setting_pos = 1
            break
        else
            local token = StringSplit(pos, ';')
            if tostring(token[2]) == '0' then  -- 아직 보상 안받음
                setting_pos = 0
                break
            end
        end
    end

    if pos_property == 'None' then
        return
    end

    local exist = IS_EXIST_MY_ARCHEOLOGY_OBJECT(pc)  -- 주변에 이미 흙더미가 있다면
    
    if exist == true then
        return
    end

    local str_pos = 'None'
    local x, y, z
    if setting_pos == 1 then
        local x1, y1, z1 = Get3DPos(pc)    
        x1 = math.floor(x1)
        y1 = math.floor(y1)
        z1 = math.floor(z1)        
        x = x1
        y = y1
        z = z1
        for i = 1, 5 do
            x, y, z = GetRandomPosInRange(pc, x1, y1, z1, 1000, 10000);
            x = math.floor(x)
            y = math.floor(y)
            z = math.floor(z)
            if x1 ~= x or y1 ~= y or z1 ~= z then
                break
            end
        end

        str_pos = x .. ',' ..y .. ',' .. z .. ';0'    
    end

    local tx = TxBegin(pc)

    if setting_pos == 1 then
        TxSetIESProp(tx, acc, pos_property, str_pos)
    end

    TxAddIESProp(tx, acc, 'archeology_try_count', 1, 'TX_SURVEY_ARCHEOLOGY')

    local ret = TxCommit(tx)    
    if ret == 'SUCCESS' then
        local diff = 10000
        if setting_pos == 1 then
            diff = GET_DISTANCE_ARCHEOLOGY_POINT(pc, x .. ',' ..y .. ',' .. z)
        else
            local pos = TryGetProp(acc, pos_property, 'None')
            local token = StringSplit(pos, ';')
            diff = GET_DISTANCE_ARCHEOLOGY_POINT(pc, token[1])
        end
        
        local min_detector_length = 100
        local grade = GET_USER_DETECTOR_GRADE(pc)
        if grade == 2 then
            min_detector_length = 150
        elseif grade == 1 then
            min_detector_length = 100
        else
            min_detector_length = 10
        end

        -- mongo log
        local log_list = {}
        table.insert(log_list, 'Type')
        table.insert(log_list, 'Survey')        
        table.insert(log_list, 'TryCount')
        table.insert(log_list, tostring(now_count + 1))
        table.insert(log_list, 'ResultDistance')
        table.insert(log_list, tostring(diff))
        CustomMongoLog_WithList(pc, 'ArcheologyMission', log_list)

        if diff <= min_detector_length then
            SCR_CREATE_ARCHEOLOGY_MON(pc, pos_property, archeology_map_property)
        else
            if diff >= 1000 then
                SendSysMsg(pc, 'ArcheologyRelicTooFarAway')
                PlaySoundLocal(pc, 'skl_eff_archeology_very_far')
            elseif diff >= 500 then
                SendSysMsg(pc, 'ArcheologyRelicFarAway')
                PlaySoundLocal(pc, 'skl_eff_archeology_far')
            else
                SendSysMsg(pc, 'ArcheologyRelicNear')
                PlaySoundLocal(pc, 'skl_eff_archeology_very_close')
            end
        end
    end
end

-- 발견후 흙더미 젠
function SCR_CREATE_ARCHEOLOGY_MON(self, pos_property, archeology_map_property)
    local exist = IS_EXIST_MY_ARCHEOLOGY_OBJECT(self)
    
    if exist == true then
        return
    end

    local zoneID = GetZoneInstID(self)
    local x, y, z = Get3DPos(self)

    for i = 1 , 4 do
        if IsValidPos(zoneID, x, y, z) == 'YES' then
            PlayEffectToGroundLocal(self, "I_force018_trail_smoke_800", x, y + 10, z, 2)
            PlaySoundLocal(self, 'skl_eff_archeology_dicover_effect')
            sleep(1000)
            local mon = CREATE_NPC(self, 'dirt_heal_2', x, y, z, 0, 'Neutral', 0, ScpArgMsg("EVENT_2108_ARCHEOLOGY_NPC_NAME"), 'ARCHEOLOGY_RESULT','None',10)
            if mon ~= nil then
                AddVisiblePC(mon, self, 1)
                PlayEffectLocal(mon,self, 'I_explosion007_light', 2, 1,'TOP')
                SendAddOnMsg(self, 'NOTICE_Dm_fanfare', ScpArgMsg('EVENT_2108_ARCHEOLOGY_SEARCH_2'), 5);
                SetLifeTime(mon, 30)
                SetExProp_Str(mon, 'pos_property_name', pos_property)
                SetExProp_Str(mon, 'archeology_map_property', archeology_map_property)
                SetExProp_Str(mon, 'aidx', GetPcAIDStr(self))
                PlaySoundLocal(self, 'skl_eff_archeology_dicover')
                break
            end
        else
            SendAddOnMsg(self, "NOTICE_Dm_information", ScpArgMsg("EVENT_2108_ARCHEOLOGY_SEARCH_6"), 3)  -- 유효한 좌표 아니므로 생성실패
        end
    end
end
-- 보상
function SCR_ARCHEOLOGY_RESULT_DIALOG(self, pc)
    if pc == nil then
        return
    end

    local aObj = GetAccountObj(pc)
    local pos_property = GetExProp_Str(self, 'pos_property_name')  -- archeology_map_1_pos_1
    local archeology_map_property = GetExProp_Str(self, 'archeology_map_property') -- archeology_map_1
    local pos_value = TryGetProp(aObj, pos_property, 'None')  -- x,y,z;0
    if pos_value == 'None' then
        return
    end

    local x, y, z = GetPos(pc)
    local zoneName = GetZoneName(pc);
    PlayEffect(pc, 'I_archer_pistol_atk_smoke3_dark', 1, 1,'MID')
    DOTIMEACTION_R(pc,ScpArgMsg('EVENT_2108_ARCHEOLOGY_SEARCH_1'), "skl_assistattack_shovel", 1)
    
    local token = StringSplit(pos_value, ';')    
    local token2 = StringSplit(pos_property, '_')
    local index = tonumber(token2[#token2])

    local try_count = TryGetProp(aObj, 'archeology_try_count', 0)     
    local legacy_grade = IMCRandom(1, 9)  -- 1~3:하급 4~6:중급 7~9:상급    
    local legacy_count = IMCRandom(1, 9)

    local legacy_grade_trade_count = GET_LECACY_GRADE_TRY_COUNT(try_count)
    for i = 1, legacy_grade_trade_count do      
        legacy_grade = IMCRandom(legacy_grade, 9)  
        legacy_count = IMCRandom(legacy_count, 9)
    end

    legacy_grade = math.ceil(legacy_grade / 3)
    legacy_count = math.ceil(legacy_count / 3)
    
    local lv = TryGetProp(aObj, 'archeology_lv', 470)
    local reward_list = shared_archeology.get_reward_list(lv)
    if reward_list == nil then
        return
    end

    local give_item_name = reward_list[legacy_grade]

    -- mongo log
    local log_list = {}
    table.insert(log_list, 'Type')
    table.insert(log_list, 'Reward')
    table.insert(log_list, 'MissionLevel')
    table.insert(log_list, tostring(lv))
    table.insert(log_list, 'GiveItemName_1')
    table.insert(log_list, give_item_name)
    table.insert(log_list, 'GiveItemCount_1')
    table.insert(log_list, tostring(legacy_count))

    local tx = TxBegin(pc)
    TxSetIESProp(tx, aObj, pos_property, token[1] .. ';1')
    TxGiveItem(tx, give_item_name, legacy_count, 'SCR_ARCHEOLOGY_RESULT_DIALOG')

    if IMCRandom(1, 30000) <= 100 then
        TxGiveItem(tx, 'piece_GabijaEarring', 1, 'SCR_ARCHEOLOGY_RESULT_DIALOG')

        table.insert(log_list, 'GiveItemName_2')
        table.insert(log_list, 'piece_GabijaEarring')
        table.insert(log_list, 'GiveItemCount_2')
        table.insert(log_list, '1')
    end

    TxSetIESProp(tx, aObj, 'archeology_try_count', 0) -- 시도 횟수 리셋    
    if index == max_archeology_point then
        TxSetIESProp(tx, aObj, archeology_map_property .. '_complete'  , 1)
    end
    local ret = TxCommit(tx)    
    if ret == "SUCCESS" then        
        table.insert(log_list, 'MissionMap')
        table.insert(log_list, TryGetProp(aObj, archeology_map_property, 'None'))
        CustomMongoLog_WithList(pc, 'ArcheologyMission', log_list)
        -- nexon_cpq
        if IsRunningScript(pc, 'SCR_NEXON_CPQ_ARCHEOLOGY_CLEAR_CHECK') ~= 1 then
            RunScript('SCR_NEXON_CPQ_ARCHEOLOGY_CLEAR_CHECK', pc)
        end
        Dead(self)        
    end
    sleep(2000)
    StopAnim(pc)
end

-- 주변에 이미 나의 흙더미가 있는지 확인
function IS_EXIST_MY_ARCHEOLOGY_OBJECT(pc)
    local list, cnt = SelectObjectByClassName(pc, 300, 'dirt_heal_2')
    for i = 1 , cnt do
        local mon = list[i]
        local aidx = GetExProp_Str(mon, 'aidx')
        if aidx == GetPcAIDStr(pc) then
            return true
        end
    end

    return false
end 

-- PC와 유물과의 거리
function GET_DISTANCE_ARCHEOLOGY_POINT(pc, pos_str)
    local x, y, z = Get3DPos(pc)
    local token = StringSplit(pos_str, ',')
    local ret = GetDistanceByFromToPos(x,y,z, tonumber(token[1]), tonumber(token[2]), tonumber(token[3]))
    return ret
end

function GET_LECACY_GRADE_TRY_COUNT(try_count)
    if try_count <= 9 then
        return 2
    elseif try_count <= 18 then
        return 1
    else
        return 0
    end
end

function GET_USER_DETECTOR_GRADE(pc)
    local item = GetEquipItem(pc, 'LH')
    if item ~= nil then
        if TryGetProp(item, 'StringArg', 'None') == 'Archeology_Detector' then
            return TryGetProp(item, 'NumberArg1', 0)
        end
    end

    item = GetEquipItem(pc, 'RH')
    if item ~= nil then
        if TryGetProp(item, 'StringArg', 'None') == 'Archeology_Detector' then
            return TryGetProp(item, 'NumberArg1', 0)
        end
    end

    return 0
end

function SCR_ARCHEOLOGY_NORMAL_3(self, pc)    
    SendAddOnMsg(pc, 'ARCHEOLOGY_MISSION_OPEN', 'None', 470)    
end

function SCR_ARCHEOLOGY_NORMAL_4(self, pc)    
    ExecClientScp(pc, "OPEN_ARCHEOLOGY_SHOP()")
end


-- 유물 조각으로 지급
function SCR_USE_GIVE_Archeology_Relic(pc, target, argstring, arg1, arg2, itemID)
    arg1 = tonumber(arg1)	
    local item = GetInvItemByType(pc, itemID)
    local itemClsName = TryGetProp(item, "ClassName", "None")
    if item == nil then
        return
    end
    local countCheck = GetInvItemCount(pc, item.ClassName)
    local itemCls = GetClass("Item", argstring)  -- 지급할 아이템
    if itemCls == nil then
        return
    end
    if itemCls.MaxStack > 1 then
        local tx = TxBegin(pc)
        if tx == nil then 
            return 
        end

        local convert_count = tonumber(arg1) * countCheck
        TxGiveItem(tx, argstring, tonumber(arg1) * countCheck, 'TX_' .. item.ClassName)        
        TxTakeItem(tx, itemClsName, countCheck, "Log_" .. item.ClassName .. "_Take")

        local ret = TxCommit(tx)
        if ret == 'SUCCESS' then
            -- 업적 여기서 카운트, convert_count
            AddAchievePoint(pc, 'Archeology_Lv470', convert_count)
            
            -- mongo log
            local log_list = {}
            table.insert(log_list, 'Type')
            table.insert(log_list, 'ExchangeRelic')
            table.insert(log_list, 'GiveItemName')
            table.insert(log_list, argstring)
            table.insert(log_list, 'GiveItemCount')
            table.insert(log_list, tostring(tonumber(arg1) * countCheck))
            table.insert(log_list, 'TakeItemName')
            table.insert(log_list, itemClsName)
            table.insert(log_list, 'TakeItemCount')
            table.insert(log_list, tostring(countCheck))
            CustomMongoLog_WithList(pc, 'ArcheologyMission', log_list)
        end
    else
        SendAddOnMsg(pc, "NOTICE_Dm_!", ScpArgMsg("Auto_SuLyangi_BuJogHapNiDa."), 3)
    end
end

function print111(pc)
    local acc = GetAccountObj(pc)    
    print('try_count', TryGetProp(acc, 'archeology_try_count', 0))
    print('lv', TryGetProp(acc, 'archeology_lv', 0))
    for i = 1, 3 do
        print('archeology_map_' .. i, TryGetProp(acc, 'archeology_map_' .. i, 'None'))
        print('archeology_map_' .. i .. '_complete', TryGetProp(acc, 'archeology_map_' .. i .. '_complete'))
        for j = 1, 3 do
            local name = 'archeology_map_' .. i .. '_pos_' .. j
            print(TryGetProp(acc, name))
        end
    end
end

