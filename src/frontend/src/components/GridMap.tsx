import { useEffect, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { MapContainer, Marker, Popup, TileLayer, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import type { Asset } from "../api/types";
import { RISK_TIER_HEX } from "../lib/riskColors";
import { RiskBadge } from "./RiskBadge";

interface GridMapProps {
  assets: Asset[];
  height?: number;
}

const markerIconCache = new Map<string, L.DivIcon>();

function markerIcon(tier: Asset["risk_tier"]): L.DivIcon {
  const cached = markerIconCache.get(tier);
  if (cached) return cached;

  const hex = RISK_TIER_HEX[tier];
  const icon = L.divIcon({
    className: "", // avoid leaflet's default marker box/shadow classes
    html: `<span class="grid-map-marker" style="background-color:${hex}; color:${hex}"></span>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
    popupAnchor: [0, -10],
  });
  markerIconCache.set(tier, icon);
  return icon;
}

/** Fits the map viewport to every asset's coordinates whenever the list changes. */
function FitToAssets({ assets }: { assets: Asset[] }) {
  const map = useMap();

  useEffect(() => {
    if (assets.length === 0) return;
    if (assets.length === 1) {
      map.setView([assets[0].lat, assets[0].lon], 9);
      return;
    }
    const bounds = L.latLngBounds(assets.map((a) => [a.lat, a.lon]));
    map.fitBounds(bounds, { padding: [32, 32] });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [assets, map]);

  return null;
}

export function GridMap({ assets, height = 380 }: GridMapProps) {
  const navigate = useNavigate();

  const center: [number, number] = useMemo(() => {
    if (assets.length === 0) return [39.8, -98.6]; // continental-US fallback
    const lat = assets.reduce((sum, a) => sum + a.lat, 0) / assets.length;
    const lon = assets.reduce((sum, a) => sum + a.lon, 0) / assets.length;
    return [lat, lon];
  }, [assets]);

  return (
    <div
      className="relative border border-carbon-gray-20 bg-carbon-white shadow-sm"
      style={{ height }}
    >
      <MapContainer
        center={center}
        zoom={6}
        scrollWheelZoom={false}
        style={{ height: "100%", width: "100%" }}
        attributionControl={true}
      >
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
        <FitToAssets assets={assets} />
        {assets.map((asset) => (
          <Marker
            key={asset.asset_id}
            position={[asset.lat, asset.lon]}
            icon={markerIcon(asset.risk_tier)}
          >
            <Popup>
              <div className="min-w-[180px] font-sans">
                <p className="text-sm font-semibold text-carbon-gray-100">{asset.name}</p>
                <div className="mt-1 flex items-center gap-2">
                  <RiskBadge tier={asset.risk_tier} size="sm" />
                  <span className="font-mono text-xs font-tabular text-carbon-gray-70">
                    {asset.risk_score}/100
                  </span>
                </div>
                <button
                  type="button"
                  onClick={() => navigate(`/assets/${asset.asset_id}`)}
                  className="mt-3 w-full border border-carbon-blue-60 px-2 py-1 text-xs font-semibold text-carbon-blue-60 transition-colors hover:bg-carbon-blue-60 hover:text-carbon-white"
                >
                  View asset detail
                </button>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}
