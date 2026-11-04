"use client";

import { useEffect, useState } from "react";

type AgentState = "working" | "approval" | "needsYou";

const AGENTS = [
  { name: "checkout-api", tool: "Claude Code", detail: "Running the migration tests", port: ":4000" },
  { name: "web-shop", tool: "Claude Code", detail: "Editing PaymentForm.tsx", port: ":3000" },
  { name: "docs-site", tool: "Codex", detail: "Rewriting the install guide", port: ":5173" },
  { name: "infra", tool: "Claude Code", detail: "Planning the Terraform change", port: "—" },
  { name: "mobile-app", tool: "Codex", detail: "Fixing the login snapshot", port: ":8081" },
];

const STATE_LABELS: Record<AgentState, string> = {
  working: "Working",
  approval: "Waiting for approval",
  needsYou: "Needs you",
};

const TICK_MS = 2800;

function stateFor(row: number, tick: number): AgentState {
  if (row === tick % AGENTS.length) return "needsYou";
  if (row === (tick + 2) % AGENTS.length) return "approval";
  return "working";
}

/** A live-looking agent board: one agent needs you, one waits for approval, the rest work. */
export function AgentBoard() {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => setTick((current) => current + 1), TICK_MS);
    return () => clearInterval(timer);
  }, []);

  return (
    <div className="board" role="img" aria-label="Example agent board with agent states">
      <div className="board-head">
        <span>Agent</span>
        <span>Doing</span>
        <span>Port</span>
        <span>Status</span>
      </div>
      {AGENTS.map((agent, row) => {
        const state = stateFor(row, tick);
        return (
          <div key={agent.name} className={`board-row is-${state}`}>
            <span className="board-name">
              <i className="dot" />
              {agent.name}
              <small>{agent.tool}</small>
            </span>
            <span className="board-detail">{state === "needsYou" ? "Finished — your reply" : agent.detail}</span>
            <span className="board-port">{agent.port}</span>
            <span className="board-state">{STATE_LABELS[state]}</span>
          </div>
        );
      })}
    </div>
  );
}
