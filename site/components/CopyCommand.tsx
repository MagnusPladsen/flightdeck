"use client";

import { useState } from "react";

const COPIED_RESET_MS = 1600;

/** A shell command with a copy button. */
export function CopyCommand({ command }: { command: string }) {
  const [isCopied, setIsCopied] = useState(false);

  async function handleCopy() {
    await navigator.clipboard.writeText(command);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), COPIED_RESET_MS);
  }

  return (
    <div className="command">
      <code>
        <span className="command-prompt">$</span> {command}
      </code>
      <button type="button" onClick={handleCopy} aria-label={`Copy ${command}`}>
        {isCopied ? "Copied" : "Copy"}
      </button>
    </div>
  );
}
