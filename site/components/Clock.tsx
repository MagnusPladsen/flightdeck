"use client";

import { useEffect, useState } from "react";

function formatTime(date: Date): string {
  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false });
}

/** The overview's big light clock, showing the visitor's local time. */
export function Clock() {
  const [time, setTime] = useState<string | null>(null);

  useEffect(() => {
    const tick = () => setTime(formatTime(new Date()));
    tick();
    const timer = setInterval(tick, 1000);
    return () => clearInterval(timer);
  }, []);

  return (
    <time className="clock" suppressHydrationWarning>
      {time ?? "--:--"}
    </time>
  );
}
