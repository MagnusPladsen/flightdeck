import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ImageResponse } from "next/og";
import { FormationMark } from "@/components/FormationMark";

export const alt = "Flightdeck: storefront needs you. The macOS menu bar monitor for AI agents and dev servers.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

/** The site's colour tokens from globals.css; the image renderer can't read CSS variables. */
const COLORS = {
  bg: "#030303",
  fg: "#f2f2f2",
  muted: "#8a8a8a",
  accent: "#ff6b14",
  line: "#1f1f1f",
};

/** Fetches a TrueType cut of Archivo, since the image renderer can't read woff2. */
async function loadArchivo(weight: number): Promise<ArrayBuffer> {
  const css = await (await fetch(`https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@118,${weight}`)).text();
  const fontUrl = css.match(/src: url\((.+?\.ttf)\)/)?.[1];
  if (!fontUrl) throw new Error("Archivo TrueType URL not found in the Google Fonts CSS");
  return (await fetch(fontUrl)).arrayBuffer();
}

function readScreenshot(name: string): string {
  const png = readFileSync(join(process.cwd(), "public", "screenshots", name));
  return `data:image/png;base64,${png.toString("base64")}`;
}

export default async function OpenGraphImage(): Promise<ImageResponse> {
  const [heavy, medium] = await Promise.all([loadArchivo(900), loadArchivo(500)]);

  return new ImageResponse(
    (
      <div style={{ display: "flex", width: "100%", height: "100%", background: COLORS.bg, fontFamily: "Archivo" }}>
        <div style={{ display: "flex", flexDirection: "column", justifyContent: "space-between", padding: "64px 48px 64px 72px", width: 640 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 16, color: COLORS.fg, fontSize: 34, fontWeight: 900 }}>
            <FormationMark size={44} lead={COLORS.accent} wingmen={COLORS.fg} />
            Flightdeck
          </div>
          <div style={{ display: "flex", flexDirection: "column", fontSize: 92, fontWeight: 900, lineHeight: 0.95, letterSpacing: -4 }}>
            <span style={{ color: COLORS.fg }}>storefront</span>
            <span style={{ color: COLORS.accent }}>needs you.</span>
          </div>
          <div style={{ color: COLORS.muted, fontSize: 28, fontWeight: 500, lineHeight: 1.3 }}>
            Your AI agents, dev servers and system resources, in the macOS menu bar.
          </div>
        </div>
        <img
          src={readScreenshot("overview.png")}
          width={573}
          height={543}
          style={{ marginTop: 72, borderRadius: 18, border: `2px solid ${COLORS.line}` }}
          alt=""
        />
      </div>
    ),
    {
      ...size,
      fonts: [
        { name: "Archivo", data: heavy, weight: 900, style: "normal" },
        { name: "Archivo", data: medium, weight: 500, style: "normal" },
      ],
    },
  );
}
