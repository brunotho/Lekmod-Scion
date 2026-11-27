-- Fractal Pangaea mainland helpers (shape=fractal_pangaea).
-- Full fractal/choke/margin/shift still runs in Lekmap_PangaeaPipeline for this shape.
-- Alias: shape "compact" still accepted for older leaves/logs.

function LekLandmass_IsFractalPangaea()
	local s = _lek_pangaea_land_shape or "fractal_pangaea";
	return s == "fractal_pangaea" or s == "compact";
end

-- Back-compat name used in older comments/docs.
function LekLandmass_IsCompact()
	return LekLandmass_IsFractalPangaea();
end

function LekLandmass_IsEquatorRing()
	return (_lek_pangaea_land_shape or "fractal_pangaea") == "equator_ring";
end
