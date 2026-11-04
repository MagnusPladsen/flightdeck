"use client";

import { useEffect, useState } from "react";

const AGENT_NAMES = ["checkout-api", "web-shop", "docs-site", "infra", "mobile-app"];
const ROTATE_INTERVAL_MS = 2800;

/** "<agent> needs you." with the agent name cycling, as the overview headline does. */
export function NeedsYouHeadline() {
  const [index, setIndex] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setIndex((current) => (current + 1) % AGENT_NAMES.length), ROTATE_INTERVAL_MS);
    return () => clearInterval(timer);
  }, []);

  return (
    <h1 className="headline">
      <span key={AGENT_NAMES[index]} className="headline-name">
        {AGENT_NAMES[index]}
      </span>
      <br />
      <span className="accent">needs you.</span>
    </h1>
  );
}
