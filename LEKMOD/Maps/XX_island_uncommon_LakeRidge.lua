-- On existing land: short opposing mountain ridges with a clumpy lake between them.

include("X_IslandHelpers");

local function pidx(x, y, iW)
	return y * iW + x + 1;
end

local function isLand(plotTypes, x, y, iW, iH)
	if x < 0 or x >= iW or y < 0 or y >= iH then return false; end
	local t = plotTypes[pidx(x, y, iW)];
	return t == PlotTypes.PLOT_LAND or t == PlotTypes.PLOT_HILLS or t == PlotTypes.PLOT_MOUNTAIN;
end

local function rotDir(d, delta)
	return ((d - 1 + delta) % 6 + 6) % 6 + 1;
end

local function key(x, y) return x .. "," .. y; end

local function hexStepsBetween(ax, ay, bx, by, iW, iH, wrapX, wrapY, cap)
	cap = cap or 32;
	if ax == bx and ay == by then
		return 0;
	end
	local q = { { ax, ay, 0 } };
	local qi = 1;
	local vis = {};
	vis[key(ax, ay)] = true;
	while qi <= #q do
		local x, y, d = q[qi][1], q[qi][2], q[qi][3];
		qi = qi + 1;
		if d >= cap then
		else
			for dir = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
					local kk = key(nx, ny);
					if not vis[kk] then
						vis[kk] = true;
						if nx == bx and ny == by then
							return d + 1;
						end
						q[#q + 1] = { nx, ny, d + 1 };
					end
				end
			end
		end
	end
	return cap + 1;
end

local function dirBetween(x1, y1, x2, y2, iW, iH, wrapX, wrapY)
	for d = 1, 6 do
		local nx, ny = GetHexNeighbor(x1, y1, d, iW, iH, wrapX, wrapY);
		if nx == x2 and ny == y2 then return d; end
	end
	return nil;
end

local function growLakeClump(plotTypes, sx, sy, n, leftRidgeSet, iW, iH, wrapX, wrapY)
	local lakeSet = {}; lakeSet[key(sx, sy)] = { sx, sy };
	local lakeList = { { sx, sy } };
	while #lakeList < n do
		local candidates = {};
		for k, p in pairs(lakeSet) do
			local x, y = p[1], p[2];
			for d = 1, 6 do
				local nx, ny = GetHexNeighbor(x, y, d, iW, iH, wrapX, wrapY);
				if nx >= 0 and nx < iW and ny >= 0 and ny < iH then
					local kk = key(nx, ny);
					if not lakeSet[kk] and not leftRidgeSet[kk] and isLand(plotTypes, nx, ny, iW, iH) then
						local count = 0;
						for d2 = 1, 6 do
							local nnx, nny = GetHexNeighbor(nx, ny, d2, iW, iH, wrapX, wrapY);
							if lakeSet[key(nnx, nny)] then count = count + 1; end
						end
						candidates[#candidates + 1] = { nx, ny, count };
					end
				end
			end
		end
		if #candidates == 0 then break; end
		table.sort(candidates, function(a, b) return a[3] > b[3]; end);
		local best = candidates[1][3];
		local ties = {};
		for _, c in ipairs(candidates) do if c[3] == best then ties[#ties + 1] = c; end end
		local pick = ties[1 + Map.Rand(#ties, "")];
		local nx, ny = pick[1], pick[2];
		lakeSet[key(nx, ny)] = { nx, ny }; lakeList[#lakeList + 1] = { nx, ny };
	end
	return lakeSet, lakeList;
end

function TryPlaceLakeRidge(plotTypes, opts)
	local iW = opts.iW;
	local iH = opts.iH;
	if not iW or not iH then iW, iH = Map.GetGridSize(); end
	local wrapX = opts.wrapX and true or false;
	local wrapY = opts.wrapY and true or false;

	local margin = 8;
	local leftLen = 3 + Map.Rand(3, "");
	local lakeLen = 4 + Map.Rand(2, "");
	local rightLen = 3 + Map.Rand(3, "");
	local turnChance = 38;

	local ccx = (type(opts.lakeRidgeCenterX) == "number") and opts.lakeRidgeCenterX or math.floor(iW / 2);
	local ccy = (type(opts.lakeRidgeCenterY) == "number") and opts.lakeRidgeCenterY or math.floor(iH / 2);
	local maxHexC = opts.lakeRidgeMaxHexFromCenter;

	for attempt = 1, 25 do
		local cx = margin + Map.Rand(iW - 2 * margin, "");
		local cy = margin + Map.Rand(iH - 2 * margin, "");
		if type(maxHexC) == "number" and maxHexC >= 0 then
			if hexStepsBetween(cx, cy, ccx, ccy, iW, iH, wrapX, wrapY, maxHexC + 1) > maxHexC then
				cx = -1;
			end
		end
		if cx >= 0 and cx < iW and cy >= 0 and cy < iH and isLand(plotTypes, cx, cy, iW, iH) then
			local dir = 1 + Map.Rand(6, "");
			local leftRidge = {};
			local x, y = cx, cy;
			leftRidge[#leftRidge + 1] = { x, y };
			for step = 1, leftLen - 1 do
				if Map.Rand(100, "") < turnChance then
					dir = rotDir(dir, (Map.Rand(2, "") == 0) and 1 or -1);
				end
				x, y = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
				if x < 0 or x >= iW or y < 0 or y >= iH then break; end
				if not isLand(plotTypes, x, y, iW, iH) then break; end
				leftRidge[#leftRidge + 1] = { x, y };
			end
			if #leftRidge < leftLen then else
				local leftRidgeSet = {}; for _, p in ipairs(leftRidge) do leftRidgeSet[key(p[1], p[2])] = true; end
				local lakeSeedX, lakeSeedY = leftRidge[#leftRidge][1], leftRidge[#leftRidge][2];
				local lakeSet, lakeList = growLakeClump(plotTypes, lakeSeedX, lakeSeedY, lakeLen, leftRidgeSet, iW, iH, wrapX, wrapY);
				if #lakeList < lakeLen then else
					local rightStart = nil;
					for _, p in ipairs(lakeList) do
						local nx, ny = GetHexNeighbor(p[1], p[2], dir, iW, iH, wrapX, wrapY);
						if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW, iH) and not lakeSet[key(nx, ny)] and not leftRidgeSet[key(nx, ny)] then
							rightStart = { nx, ny }; break;
						end
					end
					if not rightStart then
						for _, p in ipairs(lakeList) do
							for d = 1, 6 do
								local nx, ny = GetHexNeighbor(p[1], p[2], d, iW, iH, wrapX, wrapY);
								if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW, iH) and not lakeSet[key(nx, ny)] and not leftRidgeSet[key(nx, ny)] then
									rightStart = { nx, ny }; break;
								end
							end
							if rightStart then break; end
						end
					end
					if rightStart then
						local rightRidge = {}; rightRidge[#rightRidge + 1] = { rightStart[1], rightStart[2] };
						x, y = rightStart[1], rightStart[2];
						for step = 1, rightLen - 1 do
							if Map.Rand(100, "") < turnChance then
								dir = rotDir(dir, (Map.Rand(2, "") == 0) and 1 or -1);
							end
							x, y = GetHexNeighbor(x, y, dir, iW, iH, wrapX, wrapY);
							if x < 0 or x >= iW or y < 0 or y >= iH then break; end
							if not isLand(plotTypes, x, y, iW, iH) then break; end
							rightRidge[#rightRidge + 1] = { x, y };
						end
						if #rightRidge >= rightLen then
							for _, t in ipairs(leftRidge) do
								local idx = pidx(t[1], t[2], iW);
								plotTypes[idx] = (Map.Rand(100, "") < 22) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
							end
							for _, t in ipairs(lakeList) do
								plotTypes[pidx(t[1], t[2], iW)] = PlotTypes.PLOT_OCEAN;
							end
							for _, t in ipairs(rightRidge) do
								local idx = pidx(t[1], t[2], iW);
								plotTypes[idx] = (Map.Rand(100, "") < 22) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
							end
							for i = 1, leftLen do
								if Map.Rand(100, "") < 50 then
									local d = (i < leftLen) and dirBetween(leftRidge[i][1], leftRidge[i][2], leftRidge[i+1][1], leftRidge[i+1][2], iW, iH, wrapX, wrapY) or (i > 1 and dirBetween(leftRidge[i-1][1], leftRidge[i-1][2], leftRidge[i][1], leftRidge[i][2], iW, iH, wrapX, wrapY));
									if d then
										local perp = rotDir(d, (Map.Rand(2, "") == 0) and 2 or -2);
										local nx, ny = GetHexNeighbor(leftRidge[i][1], leftRidge[i][2], perp, iW, iH, wrapX, wrapY);
										if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW, iH) then
											local nidx = pidx(nx, ny, iW);
											plotTypes[nidx] = (Map.Rand(100, "") < 22) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
										end
									end
								end
							end
							for i = 1, #rightRidge do
								if Map.Rand(100, "") < 50 then
									local d = (i < #rightRidge) and dirBetween(rightRidge[i][1], rightRidge[i][2], rightRidge[i+1][1], rightRidge[i+1][2], iW, iH, wrapX, wrapY) or (i > 1 and dirBetween(rightRidge[i-1][1], rightRidge[i-1][2], rightRidge[i][1], rightRidge[i][2], iW, iH, wrapX, wrapY));
									if d then
										local perp = rotDir(d, (Map.Rand(2, "") == 0) and 2 or -2);
										local nx, ny = GetHexNeighbor(rightRidge[i][1], rightRidge[i][2], perp, iW, iH, wrapX, wrapY);
										if nx >= 0 and nx < iW and ny >= 0 and ny < iH and isLand(plotTypes, nx, ny, iW, iH) then
											local nidx = pidx(nx, ny, iW);
											plotTypes[nidx] = (Map.Rand(100, "") < 22) and PlotTypes.PLOT_HILLS or PlotTypes.PLOT_MOUNTAIN;
										end
									end
								end
							end
							return true, cx, cy;
						end
					end
				end
			end
		end
	end
	return false;
end
