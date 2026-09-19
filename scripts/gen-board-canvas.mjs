// gen-board-canvas.mjs — 从 board.json 生成 board.canvas.tsx（inline 数据）
// 用法：node scripts/gen-board-canvas.mjs
// agent 更新 board.json 后跑此脚本，Canvas 自动反映最新状态

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const scriptDir = new URL(".", import.meta.url).pathname.replace(/^\//, "");
const boardJson = join(scriptDir, "..", "specs", "board.json");
const canvasDir = join(homedir(), ".cursor", "projects", "d", "canvases");
const canvasFile = join(canvasDir, "board.canvas.tsx");

const board = JSON.parse(readFileSync(boardJson, "utf8"));
const tasksJson = JSON.stringify(board.tasks);
const changelogJson = JSON.stringify(board.changelog);
const stagesJson = JSON.stringify(board.stages);

const canvasCode = `import { Card, CardHeader, CardBody, Grid, Row, Stack, H1, H2, H3, Text, Pill, Stat, UsageBar, Table, CollapsibleSection, useHostTheme, canvasTokens } from "cursor/canvas";

const tasks = ${tasksJson};
const changelog = ${changelogJson};
const STAGES = ${stagesJson};

function stageLabel(s: string) { return STAGES.find((x: any) => x.key === s)?.label ?? s; }
function stageTone(s: string) { return STAGES.find((x: any) => x.key === s)?.tone ?? "neutral"; }

function TaskCard({ task }: { task: any }) {
  return (
    <Card>
      <CardHeader title={task.name} subtitle={\`#\${task.id} · \${stageLabel(task.stage)} · \${task.role}\`} />
      <CardBody>
        <Stack spacing="sm">
          <UsageBar value={task.progress} tone={stageTone(task.stage)} />
          <Text size="sm" tone="muted">最近变更：{task.keyChanges[0] ?? "—"}</Text>
        </Stack>
      </CardBody>
    </Card>
  );
}

function StageColumn({ stage }: { stage: any }) {
  const items = tasks.filter((t: any) => t.stage === stage.key);
  return (
    <Stack spacing="sm">
      <H3>{stage.label}（{items.length}）</H3>
      {items.length === 0 ? <Text tone="muted">—</Text> : items.map((t: any) => <TaskCard task={t} />)}
    </Stack>
  );
}

export default function BoardCanvas() {
  const theme = useHostTheme();
  const recent = changelog.slice(0, 10);
  return (
    <Stack spacing="lg">
      <H1>开发看板</H1>
      <Grid columns={4} gap="md">
        {STAGES.map((s: any) => <StageColumn stage={s} />)}
      </Grid>
      <Card>
        <CardHeader title="最近变更" subtitle={\`最近 \${recent.length} 条\`} />
        <CardBody>
          <Table
            columns={[
              { key: "time", label: "时间", align: "left" },
              { key: "taskId", label: "编号", align: "left" },
              { key: "description", label: "变更", align: "left" },
              { key: "actor", label: "触发者", align: "left" },
            ]}
            rows={recent.map((c: any) => ({
              time: c.time.slice(0, 16).replace("T", " "),
              taskId: \`#\${c.taskId}\`,
              description: c.description,
              actor: c.actor,
            }))}
          />
        </CardBody>
      </Card>
    </Stack>
  );
}
`;

mkdirSync(canvasDir, { recursive: true });
writeFileSync(canvasFile, canvasCode, "utf8");
console.log(`Canvas generated: ${canvasFile}`);
