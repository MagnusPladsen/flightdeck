/** The app icon's three-jet formation: an accent lead and two wingmen, in the 824pt icon's units. */
const FIGHTER_HALF: [number, number][] = [
  [0, -340], [34, -230], [46, -90], [320, 90], [320, 140],
  [60, 110], [58, 200], [170, 290], [170, 325], [40, 300], [0, 300],
];

function jetPoints(centerX: number, centerY: number, scale: number): string {
  const right = FIGHTER_HALF.map(([x, y]) => [centerX + x * scale, centerY + y * scale]);
  const left = [...FIGHTER_HALF].reverse().map(([x, y]) => [centerX - x * scale, centerY + y * scale]);
  return [...right, ...left].map(([x, y]) => `${x.toFixed(1)},${y.toFixed(1)}`).join(" ");
}

type FormationMarkProps = {
  size?: number;
  lead?: string;
  wingmen?: string;
  className?: string;
};

export function FormationMark({ size = 28, lead = "var(--accent)", wingmen = "var(--fg)", className }: FormationMarkProps) {
  return (
    <svg width={size} height={size} viewBox="0 0 824 824" className={className} aria-hidden="true">
      <polygon points={jetPoints(412, 287, 0.5)} fill={lead} />
      <polygon points={jetPoints(227, 537, 0.45)} fill={wingmen} />
      <polygon points={jetPoints(597, 537, 0.45)} fill={wingmen} />
    </svg>
  );
}
