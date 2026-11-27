-- Hollow center water with a broken double-thick ring of land around it in short arcs.

include("X_IslandHelpers");

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[y * iW + x + 1];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function footprintClear(plotTypes, tiles, iW, iH)
	for _, t in ipairs(tiles) do
		if isLand(plotTypes, t[1], t[2], iW, iH) then return false; end
	end
	return true;
end

local function outerNeighbor(gx, gy, outerRingList)
	for _, ot in ipairs(outerRingList) do
		if IsHexAdjacent(gx, gy, ot[1], ot[2]) then return ot; end
	end
	return nil;
end

function TryPlaceShatteredRingIsland(plotTypes, centerX, centerY, islLandInRing, params)
	local pullBack = params.pullBack or 2;
	local effMin = params.effMin or 2;
	local effMax = params.effMax or 6;
	local effRadius = islLandInRing - pullBack;
	if effRadius < effMin or effRadius > effMax then return false; end

	local cx = WrapCoord(centerX, params.iW, params.wrapX);
	local cy = WrapCoord(centerY, params.iH, params.wrapY);
	if cx < 0 or cx >= params.iW or cy < 0 or cy >= params.iH then return false; end

	local waterRadius = (Map.Rand(100, "") < 72) and 2 or 1;
	local ringInner = waterRadius + 1;
	local innerRing = GetHexRingAtRadius(cx, cy, ringInner, params.iW, params.iH, params.wrapX, params.wrapY);
	local ringLen = #innerRing;
	if ringLen < 6 then return false; end

	local rot = Map.Rand(6, "");
	local innerRingRot = {};
	for _, rt in ipairs(innerRing) do
		local dx = rt[1] - cx;
		local dy = rt[2] - cy;
		local dx2, dy2 = RotateOffset60(dx, dy, rot);
		local gx = WrapCoord(cx + dx2, params.iW, params.wrapX);
		local gy = WrapCoord(cy + dy2, params.iH, params.wrapY);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			innerRingRot[#innerRingRot + 1] = { gx, gy };
		end
	end
	ringLen = #innerRingRot;
	if ringLen < 6 then return false; end

	local outerRing = GetHexRingAtRadius(cx, cy, ringInner + 1, params.iW, params.iH, params.wrapX, params.wrapY);
	local outerRingRot = {};
	for _, rt in ipairs(outerRing) do
		local dx = rt[1] - cx;
		local dy = rt[2] - cy;
		local dx2, dy2 = RotateOffset60(dx, dy, rot);
		local gx = WrapCoord(cx + dx2, params.iW, params.wrapX);
		local gy = WrapCoord(cy + dy2, params.iH, params.wrapY);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			outerRingRot[#outerRingRot + 1] = { gx, gy };
		end
	end
	local outerRing3 = (ringInner + 2 <= 8) and GetHexRingAtRadius(cx, cy, ringInner + 2, params.iW, params.iH, params.wrapX, params.wrapY) or {};
	local outerRing3Rot = {};
	for _, rt in ipairs(outerRing3) do
		local dx = rt[1] - cx;
		local dy = rt[2] - cy;
		local dx2, dy2 = RotateOffset60(dx, dy, rot);
		local gx = WrapCoord(cx + dx2, params.iW, params.wrapX);
		local gy = WrapCoord(cy + dy2, params.iH, params.wrapY);
		if gx >= 0 and gx < params.iW and gy >= 0 and gy < params.iH then
			outerRing3Rot[#outerRing3Rot + 1] = { gx, gy };
		end
	end

	local step = 2 + Map.Rand(2, "");
	local numArcs = math.floor(ringLen / step);
	local landSet = {};
	for i = 1, numArcs do
		local start = (i - 1) * step + 1;
		local arcLen = (Map.Rand(100, "") < 55) and 1 or 2;
		if arcLen > step then arcLen = step; end
		local thick = Map.Rand(10, "");
		local thickness = (thick < 1) and 2 or ((thick < 3) and 1 or 2);
		for j = 0, arcLen - 1 do
			local idx = ((start - 1 + j) % ringLen) + 1;
			local rt = innerRingRot[idx];
			local key = rt[1] .. "," .. rt[2];
			landSet[key] = { rt[1], rt[2] };
			if thickness >= 2 then
				local outer = outerNeighbor(rt[1], rt[2], outerRingRot);
				if outer then
					local ok = outer[1] .. "," .. outer[2];
					if not landSet[ok] then landSet[ok] = { outer[1], outer[2] }; end
					if thickness >= 3 and #outerRing3Rot > 0 then
						for _, o3 in ipairs(outerRing3Rot) do
							if IsHexAdjacent(outer[1], outer[2], o3[1], o3[2]) then
								local k3 = o3[1] .. "," .. o3[2];
								if not landSet[k3] then landSet[k3] = { o3[1], o3[2] }; end
								break;
							end
						end
					end
				end
			end
		end
	end

	local landTiles = {};
	for _, t in pairs(landSet) do landTiles[#landTiles + 1] = t; end
	for _ = 1, 5 do
		if #landTiles <= 10 then break; end
		local ri = 1 + Map.Rand(#landTiles, "");
		landTiles[ri] = landTiles[#landTiles];
		landTiles[#landTiles] = nil;
	end
	if #landTiles < 10 then return false; end
	if not footprintClear(plotTypes, landTiles, params.iW, params.iH) then return false; end

	DrawShatteredRingIsland(plotTypes, landTiles, params.iW);
	return true;
end

function DrawShatteredRingIsland(plotTypes, landTiles, iW)
	local numMountains = 1 + Map.Rand(3, "");
	local mountainIndices = {};
	for _ = 1, numMountains do
		mountainIndices[Map.Rand(#landTiles, "") + 1] = true;
	end
	for i, t in ipairs(landTiles) do
		local x, y = t[1], t[2];
		local idx = y * iW + x + 1;
		if mountainIndices[i] then
			plotTypes[idx] = PlotTypes.PLOT_MOUNTAIN;
		else
			plotTypes[idx] = (Map.Rand(100, "") < 60) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_LAND;
		end
	end
end
