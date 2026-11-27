------------------------------------------------------------------------------
-- Lekmap_PipelineFlowLog.lua
-- Pipeline breadcrumb log (file only, no Lua.log). Gated by _lek_pipeline_flow_log = leaf master switch.
-- File: <Civ5 Logs dir>/LekmapPipelineFlow.log (see LekCiv5LogPath).
------------------------------------------------------------------------------

_lek_pipeline_flow_seq = 0;
if _lek_pipeline_flow_log == nil then
	_lek_pipeline_flow_log = false;
end

-- Full path to a file in the Civ5 Logs folder (same folder as Lua.log), or nil.
--   Windows: %USERPROFILE%/Documents/My Games/Sid Meier's Civilization 5/Logs/
--   macOS:   ~/Library/Application Support/Sid Meier's Civilization 5/Logs/
-- Documents redirected elsewhere (e.g. OneDrive) is not detected; the file is then simply not written.
function LekCiv5LogPath(fileName)
	if not (os and os.getenv) then
		return nil;
	end
	local profile = os.getenv("USERPROFILE") or "";
	if profile ~= "" then
		return profile .. "/Documents/My Games/Sid Meier's Civilization 5/Logs/" .. fileName;
	end
	local home = os.getenv("HOME") or "";
	if home ~= "" then
		return home .. "/Library/Application Support/Sid Meier's Civilization 5/Logs/" .. fileName;
	end
	local user = os.getenv("USER") or "";
	if user ~= "" then
		return "/Users/" .. user .. "/Library/Application Support/Sid Meier's Civilization 5/Logs/" .. fileName;
	end
	return nil;
end

-- Append lines (string or list) to a Civ5 Logs file. Silently no-op when io is unavailable.
-- overwrite = true truncates the file first (one-map-only logs).
function LekAppendCiv5Log(fileName, lineOrLines, overwrite)
	local path = LekCiv5LogPath(fileName);
	if not path or not (io and io.open) then
		return;
	end
	pcall(function()
		local f = io.open(path, overwrite and "w" or "a");
		if not f then
			return;
		end
		if type(lineOrLines) == "table" then
			for _, line in ipairs(lineOrLines) do
				f:write(tostring(line) .. "\n");
			end
		else
			f:write(tostring(lineOrLines) .. "\n");
		end
		f:close();
	end);
end

function LekPipelineFlowLogPath()
	return LekCiv5LogPath("LekmapPipelineFlow.log");
end

-- Truncate file so each map-script load / gen attempt starts clean.
function LekPipelineFlowReset(tag)
	if not _lek_pipeline_flow_log then
		_lek_pipeline_flow_seq = 0;
		return;
	end
	_lek_pipeline_flow_seq = 0;
	local path = LekPipelineFlowLogPath();
	local t = (os and os.clock) and os.clock() or 0;
	local line = "### LekPipelineFlow RESET tag=" .. tostring(tag)
		.. " shape=" .. tostring(_lek_pangaea_land_shape or "na")
		.. " t=" .. string.format("%.3f", t);
	if not path or not io then
		return;
	end
	local ok, err = pcall(function()
		local f = io.open(path, "w");
		if f then
			f:write(line .. "\n");
			f:flush();
			f:close();
		end
	end);
	if not ok then
		print("### LekPipelineFlow RESET write_fail " .. tostring(err));
	end
end

function LekPipelineFlow(stage, detail)
	if not _lek_pipeline_flow_log then
		return;
	end
	_lek_pipeline_flow_seq = (_lek_pipeline_flow_seq or 0) + 1;
	local t = (os and os.clock) and os.clock() or 0;
	local det = "";
	if detail ~= nil and detail ~= "" then
		det = " " .. tostring(detail);
	end
	local line = "### FLOW #" .. tostring(_lek_pipeline_flow_seq)
		.. " t=" .. string.format("%.3f", t)
		.. " shape=" .. tostring(_lek_pangaea_land_shape or "na")
		.. " stage=" .. tostring(stage)
		.. det;
	local path = LekPipelineFlowLogPath();
	if not path or not io then
		return;
	end
	pcall(function()
		local f = io.open(path, "a");
		if f then
			f:write(line .. "\n");
			f:flush();
			f:close();
		end
	end);
end
