function IS_COUPON_ITEM(item, type)
	if item.StringArg == type..'_Discount' then
		return true;
	end
	return false;
end

function GET_BEAUTYSHOP_STAMP_EXCHANGE_LIST()
	local list = {
		{
			stampCount = 5,
			rewardItemName = 'Beauty_Hair_Dye_30_CouponBox',
		},
		{
			stampCount = 10,
			rewardItemName = 'Beauty_Hair_Dye_50_CouponBox',
		},
		{
			stampCount = 15,
			rewardItemName = 'Beauty_Hair_Dye_100_CouponBox',
		},
	};

	return list;
end

function GET_STAMP_EXHCANGE_INFO(stampCnt)
	local list = GET_BEAUTYSHOP_STAMP_EXCHANGE_LIST();
	for i = 1, #list do
		local info = list[i];
		if info.stampCount == stampCnt then
			return info;
		end
	end
	return nil;
end

-- dateString Format "YYYY-MM-DD HH:mm:ss"
function CONVERT_DATESTR_TO_TIME_STAMP(dateString)
	local pattern = "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)"
	local runyear, runmonth, runday, runhour, runminute, runseconds = dateString:match(pattern)
	local convertedTimestamp = os.time({year = runyear, month = runmonth, day = runday, hour = runhour, min = runminute, sec = runseconds})

	return convertedTimestamp, runyear, runmonth, runday, runhour, runminute, runseconds;
end

function GET_CURRENT_SYSTEMTIME(isClient)
	if isClient == true then
		return geTime.GetServerSystemTime();
	end
	return GetDBTime();
end

function GET_CURRENT_DB_TIME_STAMP(isClient)
	local curTime = GET_CURRENT_SYSTEMTIME(isClient);
	local curSysTimeStr = string.format("%04d-%02d-%02d %02d:%02d:%02d", curTime.wYear, curTime.wMonth, curTime.wDay, curTime.wHour, curTime.wMinute, curTime.wSecond)
	return CONVERT_DATESTR_TO_TIME_STAMP(curSysTimeStr)
end

function IS_BEAUTYSHOP_MAP(mapCls)
	if mapCls == nil then
		return false;
	end
	local mapName = mapCls.ClassName;	
	if mapName == 'c_fedimian' or mapName == 'c_Klaipe' or mapName == 'c_orsha' or mapName == 'c_barber_dress' then
		return true;
	end
	return false;
end

function IS_TOWN_MAP(mapCls)
	if mapCls == nil then
		return false;
	end

	local mapName = mapCls.ClassName;	
	if mapName == 'c_fedimian' or mapName == 'c_Klaipe' or mapName == 'c_orsha' then
		return true;
	end

	return false;
end

function GET_TOTAL_TP(accountObj)
	if accountObj == nil then
		return 0;
	end
	return accountObj.Medal + accountObj.GiftMedal + accountObj.PremiumMedal;
end

function IS_PURCHASE_DUPLICATE_DISCOUNT(pc, productList, hairCouponItem, dyeCouponItem, skinCouponItem)
	
	for i = 1, #productList do
		local info = productList[i];
		-- ?????? IDSpace??? ????????? ??????????????????.
		local isExist = IS_EXIST_ITEM_IN_BEAUTYSHOP_IDSpace(info);
		if isExist == false then
			return true
		end	

		-- ????????? ?????? ??????
		if info.IDSpace == "Beauty_Shop_Hair" or info.IDSpace == "Beauty_Shop_Hair_Season" then
			-- hair 
			local cacheHairList = BEAUTYSHOP_MAKE_ITEM_CACHELIST(info.IDSpace);
			if cacheHairList[info.ClassName] ~= nil then
				local cls = GetClass(info.IDSpace, cacheHairList[info.ClassName])
				local priceRatio = TryGetProp(cls, "PriceRatio")
				local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, hairCouponItem);
				-- ?????? ???????????? 1%~99% ??? ?????? ??????????????? ????????????.
				if priceRatio ~= nil and priceRatio > 0 and couponDiscountPer ~= nil and couponDiscountPer > 0 and  couponDiscountPer < 1  then
					return true;
				end
			end

			-- dye 
			local cacheColorList = BEAUTYSHOP_MAKE_HAIR_COLOR_CACHELIST(info.ClassName);
			if cacheColorList ~= nil then		
				local cls = GetClass("Hair_Dye_List", cacheColorList[info.ColorEngName])
				local priceRatio = TryGetProp(cls, "PriceRatio")
				local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, dyeCouponItem);
				-- ?????? ???????????? 1%~99% ??? ?????? ??????????????? ????????????.
				if priceRatio ~= nil and priceRatio > 0 and couponDiscountPer ~= nil and couponDiscountPer > 0 and  couponDiscountPer < 1  then
					return true;
				end
			end
		elseif info.IDSpace == "Beauty_Shop_Skin" or info.IDSpace == "Beauty_Shop_Skin_Season" then
			local cacheList = BEAUTYSHOP_MAKE_ITEM_CACHELIST(info.IDSpace);
			if cacheList[info.ClassName] ~= nil then
				local cls = GetClass(info.IDSpace, cacheList[info.ClassName])
				local priceRatio = TryGetProp(cls, "PriceRatio")
				local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, skinCouponItem);
				-- ?????? ???????????? 1%~99% ??? ?????? ??????????????? ????????????.
				if priceRatio ~= nil and priceRatio > 0 and couponDiscountPer ~= nil and couponDiscountPer > 0 and  couponDiscountPer < 1  then
					return true;
				end
			end
		end
	end

	return false -- false ??? ??????
end

-- ???????????? ?????? ??????(????????? ???????????? ?????????.)
function GET_BEAUTYSHOP_ITEM_PRICE(pc, info, hairCouponItem, dyeCouponItem, skinCouponItem)   

	local result ={
		totalPrice = nil,
		hairPrice = nil,
		colorDyePrice = nil,
		hairDiscountValue = nil,
		dyeDiscountValue = nil,
		skinDiscountValue = nil,
	}

	if info.IDSpace == "Beauty_Shop_Hair" or info.IDSpace == "Beauty_Shop_Hair_Season" then
		local totalPrice, hairPrice, colorDyePrice, hairDiscountValue, dyeDiscountValue = GET_BEAUTYSHOP_HAIR_PRICE(pc, info, hairCouponItem, dyeCouponItem);
		result.totalPrice = totalPrice;
		result.hairPrice = hairPrice;
		result.colorDyePrice = colorDyePrice;
		result.hairDiscountValue = hairDiscountValue;
		result.dyeDiscountValue = dyeDiscountValue;
	elseif info.IDSpace == "Beauty_Shop_Skin" or info.IDSpace == "Beauty_Shop_Skin_Season" then
		local totalPrice, skinDiscountValue =  GET_BEAUTYSHOP_SKIN_PRICE(pc, info, skinCouponItem);
		result.totalPrice = totalPrice;
		result.skinDiscountValue = skinDiscountValue;
	else
		local price = GET_BEAUTYSHOP_NORMAL_ITEM_PRICE(info);
		result.totalPrice = price;
	end
	
	return result;
end

-- ?????? ???????????? ??????
function GET_BEAUTYSHOP_HAIR_PRICE(pc, info, hairCouponItem, dyeCouponItem)	
	local isSameCurrentHair = IS_SAME_CURRENT_HAIR(pc, info); -- ?????? ???????????? ?????????.	
	local isSameCurrentHairColor = IS_SAME_CURRENT_HAIR_COLOR(pc, info);
	if isSameCurrentHair == true and isSameCurrentHairColor == true then
		-- ?????? ????????? ??????/????????? ????????? ?????? ???????????????.
		return -1
	end

	-- ?????? ?????? ??????
	local hairPrice = 0
    local hairDiscountValue = 0;
    local dyeDiscountValue = 0;
	if isSameCurrentHair == false then	-- ??????????????? ?????? ????????? ?????? ????????? ?????? ?????? ??? ?????? ??????
		local cacheHairList = BEAUTYSHOP_MAKE_ITEM_CACHELIST(info.IDSpace);
			
		if cacheHairList[info.ClassName] ~= nil then
			local cls = GetClass(info.IDSpace, cacheHairList[info.ClassName])
			local price = TryGetProp(cls, "Price")
			local priceRatio = TryGetProp(cls, "PriceRatio")
			if price == nil then
				-- ????????? ??????.
				return -1
			end

			-- ?????? ?????? ??????
			hairPrice = price	
			
			-- ?????? ?????? : nil ?????? ????????????.
			local priceRatioPer = 0
			if priceRatio ~= nil then
				priceRatioPer = priceRatio / 100
			end

			-- ?????? ?????? : ????????? ????????? ???????????? ????????????????????? ???????????? ??????.
			local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, hairCouponItem);
			-- 1??? ?????? ????????? ??????
            local priceRatioAppliedValue = (price * priceRatioPer);
			hairPrice = hairPrice - priceRatioAppliedValue;
			
			-- 2??? ?????? ????????? ??????
            local beforeSecondDiscountValue = hairPrice;
            hairDiscountValue = (hairPrice * couponDiscountPer);
			hairPrice = hairPrice - hairDiscountValue;
			-- ?????? ?????????????????? floor
			hairPrice = math.floor(hairPrice)
			
			-- 0?????? ???????????? 0??????.
			if hairPrice < 0 then
				hairPrice = 0
			end
			
            hairDiscountValue = math.floor(beforeSecondDiscountValue - hairPrice);
		end
	end

	-- ?????? ?????? ??????
	local colorDyePrice = 0
	local cacheColorList = BEAUTYSHOP_MAKE_HAIR_COLOR_CACHELIST(info.ClassName)
	if cacheColorList ~= nil then		
		local cls = GetClass("Hair_Dye_List", cacheColorList[info.ColorEngName])		
		if cls ~= nil then
			local price = TryGetProp(cls, "Price")
			local priceRatio = TryGetProp(cls, "PriceRatio")
			local defaultDye = TryGetProp(cls, "DefaultDye")
			if price == nil then
				-- ????????? ??????.
				return -1
			end

			if IS_SEASON_SERVER() == "YES" then
				price = 1;
			end

			colorDyePrice = price
			local isFreeDefault = false
			if defaultDye ~= nil then
				if defaultDye == "YES" and isSameCurrentHair == false then	 -- ?????????????????? ?????? ??????????????? ???????????? ????????? ??????.
					colorDyePrice = 0	
					isFreeDefault = true
				end
			end

			-- ????????? ?????? ???.
			if isFreeDefault == false then
				-- ?????? ?????? : nil ?????? ????????????.
				local priceRatioPer =0
				if priceRatio ~= nil then
					priceRatioPer = priceRatio / 100
				end

				-- ?????? ?????? : ????????? ????????? ???????????? ????????????????????? ???????????? ??????.
				local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, dyeCouponItem) 
						
				-- 1??? ?????? ????????? ??????
                local priceRatioAppliedValue = (price * priceRatioPer);
				colorDyePrice = colorDyePrice - priceRatioAppliedValue;

				-- 2??? ?????? ????????? ??????
                local beforeSecondDiscountValue = colorDyePrice;
                dyeDiscountValue = (colorDyePrice * couponDiscountPer);
				colorDyePrice = colorDyePrice - dyeDiscountValue;
				-- ?????? ?????????????????? floor
				colorDyePrice = math.floor(colorDyePrice);

				-- 0?????? ???????????? 0??????.
				if colorDyePrice < 0 then
					colorDyePrice = 0
				end

                -- for log: ????????? ??? ????????? ??????????????? ??????????????? floor ????????? ?????????.. ????????? ????????? ????????????.. ????????????..
                dyeDiscountValue = math.floor(beforeSecondDiscountValue - colorDyePrice);
			end
		end
	end
	return hairPrice + colorDyePrice, hairPrice, colorDyePrice, hairDiscountValue, dyeDiscountValue;
end

function IS_SAME_CURRENT_HAIR(pc, info)	
	local itemobj = GetClass("Item", info.ClassName)
	if itemobj == nil then
		IMC_LOG("INFO_NORMAL", "IS_SAME_CURRENT_HAIR: itemobj is nil- ClassName["..info.ClassName..']');
		return false;
	end
	
	return IS_SAME_PC_ETC_PROPERTY(pc, "StartHairName", itemobj.StringArg)
end

function IS_SAME_PC_ETC_PROPERTY(pc, etcPropName, compareName)
	local pcetc = nil;
	if IsServerObj(pc) == 1 then
		pcetc = GetETCObject(pc);
	else
		pcetc = GetMyEtcObject();
	end
	if pcetc == nil then
		IMC_LOG("INFO_NORMAL", "IS_SAME_PC_ETC_PROPERTY: etcObject is nil");
		return false
	end

	local propValue = TryGetProp(pcetc, etcPropName);
	if propValue == nil then
		IMC_LOG("INFO_NORMAL", "IS_SAME_PC_ETC_PROPERTY: etcobject propValue is nil- propName["..etcPropName..']');
		return false
	end

	if compareName == propValue then
		return true
	end

	return false
end

function BEAUTYSHOP_MAKE_ITEM_CACHELIST(IDSpace)	
	local cacheList ={}
	local clsList, cnt = GetClassList(IDSpace);
	for i = 0, cnt - 1 do
		local cls = GetClassByIndexFromList(clsList, i);
		if cls ~= nil then
			if cacheList[cls.ItemClassName] == nil then
				cacheList[cls.ItemClassName] = cls.ClassName
			end
		end
	end

	return cacheList
end


-- SKIN ???????????? ??????
function GET_BEAUTYSHOP_SKIN_PRICE(pc, info, skinCouponItem)	
	local totalPrice = 0;
    local skinDiscountValue = 0;
	local cacheList = BEAUTYSHOP_MAKE_ITEM_CACHELIST(info.IDSpace);
	if cacheList[info.ClassName] ~= nil then
		local cls = GetClass(info.IDSpace, cacheList[info.ClassName])
		local price = TryGetProp(cls, "Price")
		local priceRatio = TryGetProp(cls, "PriceRatio")
		if price == nil then
			-- ????????? ??????.
			return -1
		end

		-- ?????? ?????? ??????
		totalPrice = price			

		-- ?????? ?????? : nil ?????? ????????????.
		local priceRatioPer = 0
		if priceRatio ~= nil then
			priceRatioPer = priceRatio / 100
		end

		-- ?????? ?????? : ????????? ????????????????????? ????????? ???????????????.
		local couponDiscountPer = GET_COUPON_DISCOUNT_PERCENT(info, skinCouponItem);
		-- 1??? ?????? ????????? ??????
		local priceRatioAppliedValue = (price * priceRatioPer);
		totalPrice = totalPrice - priceRatioAppliedValue;

		-- 2??? ?????? ????????? ??????
		local beforeSecondDiscountValue = totalPrice;
		hairDiscountValue = (totalPrice * couponDiscountPer);
		totalPrice = totalPrice - hairDiscountValue;
		-- ?????? ?????????????????? floor
		totalPrice = math.floor(totalPrice)

		-- 0?????? ???????????? 0??????.
		if totalPrice < 0 then
			totalPrice = 0
		end

		skinDiscountValue = math.floor(beforeSecondDiscountValue - totalPrice);
	end
	return totalPrice, skinDiscountValue;
end

function GET_BEAUTYSHOP_NORMAL_ITEM_PRICE(info)
	local cacheList =  BEAUTYSHOP_MAKE_ITEM_CACHELIST(info.IDSpace);
	local totalPrice = 0;
	if cacheList[info.ClassName] ~= nil then
		local cls = GetClass(info.IDSpace, cacheList[info.ClassName]);
		if cls ~= nil then
			local price = TryGetProp(cls, "Price")
			local priceRatio = TryGetProp(cls, "PriceRatio")
			if price == nil then
				-- ????????? ??????.
				return -1
			end

			-- ?????? ?????? ??????
			totalPrice = price

			-- ?????? ?????? : nil ?????? ????????????.
			if priceRatio ~= nil then
				local per = priceRatio / 100
				totalPrice = totalPrice - math.floor((price * per) + 0.5) 
			end
		end
	end
	return totalPrice;
end

function IS_SAME_CURRENT_HAIR_COLOR(pc, info)
	return IS_SAME_PC_ETC_PROPERTY(pc, "StartHairColorName", info.ColorEngName);
end

function GET_COUPON_DISCOUNT_PERCENT(info, couponItem) 
	if couponItem == nil then
		return 0;
	end

	local NumberArg1 =  TryGetProp(couponItem, "NumberArg1")
	if NumberArg1 == nil then
		return 0;
	end

	return tonumber(NumberArg1) / 100;
end

function BEAUTYSHOP_MAKE_HAIR_COLOR_CACHELIST(ItemClassName)
	local cacheList ={}

	local clsList, cnt = GetClassList("Hair_Dye_List");
	for i = 0, cnt - 1 do
		local cls = GetClassByIndexFromList(clsList, i);
		if cls ~= nil then
			local group = TryGetProp(cls, "Group")
			local dyeName = TryGetProp(cls, "DyeName")
			if group ~= nil and dyeName ~= nil then
				if group == ItemClassName then
					cacheList[dyeName] = cls.ClassName
				end
			end
		end
	end

	return cacheList
end

function IS_CURREUNT_IN_PERIOD(startDateString, endDateString, isClient)
	local startTimeStamp = CONVERT_DATESTR_TO_TIME_STAMP(startDateString);
	local endTimeStamp = CONVERT_DATESTR_TO_TIME_STAMP(endDateString);
	local currentTimeStamp = GET_CURRENT_DB_TIME_STAMP(isClient);
	if startTimeStamp > currentTimeStamp or currentTimeStamp > endTimeStamp then
		return false;
	end
	return true;
end


function BEAUTYSHOP_TRANS_HEAD_INDEX_TO_NAME(gender, headIndex)
	local PartClass = imcIES.GetClass("CreatePcInfo", "Hair");
	local GenderList = PartClass:GetSubClassList();
	local Selectclass   = GenderList:GetClass(gender);
	local Selectclasslist = Selectclass:GetSubClassList();

	local cls = Selectclasslist:GetClass(headIndex);
    if cls ~= nil then
        local engName = imcIES.GetString(cls, 'EngName');
        local colorName = imcIES.GetString(cls, 'EngColor');
		
		return engName, colorName;
	end
	return 'None', 'None';
end


NameToItemClassListCache = nil
function BEAUTYSHOP_TRANS_HAIR_NAME_TO_ITEMCLASSNAME(gender, hairEngName)
	if NameToItemClassListCache == nil then
		NameToItemClassListCache ={}
		NameToItemClassListCache[1] = {}
		NameToItemClassListCache[2] = {}

		local clsList, cnt = GetClassList('Beauty_Shop_Wig');
		for i = 0, cnt - 1 do
			local cls = GetClassByIndexFromList(clsList, i);
			local className = TryGetProp(cls, "ClassName")
			local engName =TryGetProp(cls, "HairEngName");
			local genderStr = TryGetProp(cls, "Gender");
			if className ~= nil and engName ~= nil and genderStr ~= nil then
				if engName ~= 'None' and genderStr ~= 'None' then
					if genderStr == 'M' then
						NameToItemClassListCache[1][engName] = className;
					elseif genderStr == 'F' then
						NameToItemClassListCache[2][engName] = className;
					end
				end
			end
		end
	end
	return NameToItemClassListCache[gender][hairEngName]
end